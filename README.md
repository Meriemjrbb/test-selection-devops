# Test de sélection DevOps — Stack Odoo conteneurisée

Déploiement d'une stack Odoo (Odoo 17 + PostgreSQL 15 + Nginx) en Docker
Compose, avec gestion des secrets, persistance des données, script de
sauvegarde automatisé et procédure de restauration après crash.

Réalisé dans le cadre du test de sélection DevOps — RIF SAS.

---

## Prérequis

| Élément | Minimum |
|---|---|
| OS | Ubuntu 20.04+ ou WSL2 |
| Docker Engine | v24+ |
| Docker Compose | v2+ |
| Git | v2+ |
| RAM disponible | 4 Go minimum |
| Disque libre | 5 Go minimum |

Vérification rapide :
```bash
uname -a
docker --version
docker compose version
git --version
free -h
df -h
```

---

## Démarrage de la stack (5 commandes)

```bash
git clone https://github.com/Meriemjrbb/test-selection-devops.git
cd test-selection-devops/apps
cp .env.example .env        # puis renseigner les valeurs (mot de passe DB, nom de base)
docker compose up -d
docker compose ps            # vérifier que les 3 services sont "Up"
```

Ajouter ensuite l'entrée suivante dans `/etc/hosts` (ou l'équivalent Windows
`C:\Windows\System32\drivers\etc\hosts`) :
```
127.0.0.1 erp.local
```

Accéder à Odoo via : **http://erp.local**

---

## Architecture

```
apps/
├── docker-compose.yml   # Stack complète : odoo, db, nginx
├── .env.example          # Variables attendues (le .env réel n'est jamais commité)
├── backup.sh             # Script de sauvegarde automatisé
└── nginx/
    └── odoo.conf          # Config du reverse proxy
```

- **db** (`postgres:15`) — isolé dans un réseau Docker privé, aucun port
  publié sur l'hôte.
- **odoo** (`odoo:17`) — exposé en interne sur le port 8069.
- **nginx** — reverse proxy exposant Odoo sur le port 80, accessible via
  `http://erp.local`.

Les données sont persistées via deux volumes nommés :
- `postgres-data` — données PostgreSQL
- `odoo-filestore` — fichiers et pièces jointes Odoo

---

## Sauvegarde

Le script `apps/backup.sh` réalise automatiquement :
- un `pg_dump` de la base Odoo (sans arrêter les conteneurs)
- une archive `tar.gz` horodatée du filestore
- un log de chaque opération dans `/var/log/backup.log`

### Lancer une sauvegarde manuellement

```bash
cd apps
./backup.sh
```

L'archive est créée dans `~/test-selection-devops/backup/`, au format
`backup_YYYYMMDD_HHMMSS.tar.gz`.

### Sauvegarde automatique (cron)

Une tâche cron est configurée pour exécuter le backup chaque nuit à 02h00 :
```bash
crontab -l
# 0 2 * * * /chemin/vers/apps/backup.sh
```

---

## Restauration après crash

La procédure complète (simulation de crash, restauration de la base et du
filestore, résolution d'un incident de permissions rencontré en conditions
réelles) est décrite pas à pas dans **[docs/restauration.md](docs/restauration.md)**.

Résumé rapide :
```bash
docker compose down -v                                   # simulation du crash
docker compose up -d                                      # stack vide
tar -xzf backup/backup_*.tar.gz -C ~/restore-tmp           # extraction
docker exec -i odoo_db psql -U odoo -d odoo < ~/restore-tmp/db_dump.sql
docker cp ~/restore-tmp/odoo-filestore/. odoo_app:/var/lib/odoo/
docker compose restart odoo
```

---

## Documentation complémentaire

- [`docs/restauration.md`](docs/restauration.md) — runbook complet de
  restauration après crash
- [`docs/journal-ia.md`](docs/journal-ia.md) — journal d'utilisation de l'IA
  pendant le test
- [`docs/captures/`](docs/captures/) — captures d'écran justifiant chaque
  étape du test (22 captures, de la Partie 1 à la Partie 2)

---

## Sécurité

- Aucun secret n'est commité : `.env` est exclu via `.gitignore`.
- `.env.example` documente les variables attendues sans valeurs sensibles.
- PostgreSQL n'est jamais exposé directement sur l'hôte.
