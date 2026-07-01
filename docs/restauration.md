# Runbook — Restauration après crash

Ce document décrit la procédure complète pour restaurer la stack Odoo (base de
données PostgreSQL + filestore) à partir d'une sauvegarde générée par
`apps/backup.sh`, suite à une perte totale des conteneurs et des volumes.

Il a été rédigé après un test réel de simulation de crash effectué le
01/07/2026, et reprend fidèlement les commandes exécutées, y compris le
problème rencontré et sa résolution.

---

## Prérequis

- Une archive de backup disponible dans `~/test-selection-devops/backup/`
  (format `backup_YYYYMMDD_HHMMSS.tar.gz`), contenant :
  - `db_dump.sql` — dump PostgreSQL généré par `pg_dump`
  - `odoo-filestore/` — copie du filestore Odoo
- Docker et Docker Compose installés et fonctionnels
- Le fichier `.env` présent à la racine de `apps/` (jamais commité sur Git)

---

## Étape 1 — Sauvegarde préalable

Avant toute simulation de crash, exécuter le script de sauvegarde pour
disposer d'une archive à jour :

```bash
cd ~/test-selection-devops/apps
./backup.sh
```

Résultat attendu : une archive horodatée créée dans `~/test-selection-devops/backup/`,
par exemple `backup_20260701_161046.tar.gz`.

---

## Étape 2 — Simulation du crash

Suppression complète des conteneurs **et** des volumes, pour simuler une perte
totale des données :

```bash
cd ~/test-selection-devops/apps
docker compose down -v
```

Vérification que les volumes ont bien été supprimés :

```bash
docker volume ls
```

Aucun volume `apps_postgres-data` ni `apps_odoo-filestore` ne doit apparaître.

---

## Étape 3 — Recréation de la stack (à vide)

```bash
docker compose up -d
docker compose ps
```

Les 3 services (`odoo`, `db`, `nginx`) doivent être à l'état `Up`, mais avec
des volumes vides — Odoo affichera une erreur ou un assistant de création de
base à ce stade.

---

## Étape 4 — Extraction de l'archive de sauvegarde

```bash
mkdir -p ~/restore-tmp
tar -xzf ~/test-selection-devops/backup/backup_20260701_161046.tar.gz -C ~/restore-tmp
ls -la ~/restore-tmp
```

On doit retrouver :
- `db_dump.sql`
- le dossier `odoo-filestore/`

---

## Étape 5 — Restauration de la base PostgreSQL

Restauration du dump directement dans le conteneur `odoo_db`, sans arrêter les
services :

```bash
docker exec -i odoo_db psql -U odoo -d odoo < ~/restore-tmp/db_dump.sql
```

Le terminal affiche une série de commandes SQL rejouées (`ALTER TABLE`,
`CREATE TABLE`, etc.), confirmant que le dump est en cours de restauration.

---

## Étape 6 — Restauration du filestore

Copie du filestore extrait vers le conteneur Odoo :

```bash
docker cp ~/restore-tmp/odoo-filestore/. odoo_app:/var/lib/odoo/
```

Résultat attendu :
```
Successfully copied 12.4MB (transferred 13.1MB) to odoo_app:/var/lib/odoo/
```

---

## Étape 7 — Redémarrage d'Odoo

```bash
docker compose restart odoo
```

---

## Étape 8 — Incident rencontré : Internal Server Error

Après redémarrage, `http://erp.local` affichait une erreur **Internal Server
Error**.

### Diagnostic

```bash
docker logs odoo_app --tail 50
```

Les logs indiquaient un problème de permissions sur les fichiers copiés dans
`/var/lib/odoo` : les fichiers du filestore avaient été copiés avec
l'utilisateur `root` (via `docker cp`), alors que le processus Odoo à
l'intérieur du conteneur tourne avec l'utilisateur `odoo`. Odoo n'avait donc
pas les droits de lecture/écriture sur son propre filestore.

### Correctif

```bash
docker exec -u root odoo_app chown -R odoo:odoo /var/lib/odoo
docker compose restart odoo
```

Ce correctif remet la propriété des fichiers copiés à l'utilisateur attendu
par le conteneur Odoo, résolvant l'erreur.

---

## Étape 9 — Vérification finale

1. Ouvrir `http://erp.local` → la page de connexion Odoo s'affiche
   correctement (plus d'erreur serveur).
2. Se connecter avec les identifiants administrateur.
3. Aller dans le module **Ventes** → vérifier que les devis créés avant le
   crash (ex. S00007, S00006, S00004, S00003, S00020, S00019, S00002) sont
   bien présents, avec leurs montants et statuts d'origine.

La présence de ces données confirme que la restauration de la base **et**
du filestore a réussi.

---

## Résumé de la procédure (version courte)

```bash
# 1. Backup avant crash
./backup.sh

# 2. Simulation du crash
docker compose down -v

# 3. Stack vide
docker compose up -d

# 4. Extraction de l'archive
mkdir -p ~/restore-tmp
tar -xzf backup/backup_YYYYMMDD_HHMMSS.tar.gz -C ~/restore-tmp

# 5. Restauration DB
docker exec -i odoo_db psql -U odoo -d odoo < ~/restore-tmp/db_dump.sql

# 6. Restauration filestore
docker cp ~/restore-tmp/odoo-filestore/. odoo_app:/var/lib/odoo/

# 7. Redémarrage
docker compose restart odoo

# 8. Si erreur de permissions :
docker exec -u root odoo_app chown -R odoo:odoo /var/lib/odoo
docker compose restart odoo

# 9. Vérification sur http://erp.local
```

---

## Points de vigilance pour une prochaine restauration

- Toujours restaurer le filestore avec `docker cp`, puis **vérifier les
  permissions** avant de considérer la restauration terminée — c'est la
  source d'erreur la plus fréquente avec cette méthode.
- Ne jamais restaurer directement dans un environnement de production sans
  avoir d'abord testé la procédure en local, comme fait ici.
- Conserver plusieurs générations de backups (le script actuel horodate
  chaque archive, ce qui permet de revenir à un point de restauration
  précis en cas de besoin).
