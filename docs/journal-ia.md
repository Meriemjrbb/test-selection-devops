# Journal IA — Test de sélection DevOps

Ce fichier documente les principaux échanges avec l'IA (Claude) pendant le
test, conformément à la règle du test (fichier obligatoire, §2.1).

---

## Prompt 1 — Debug de l'erreur "Internal Server Error" après restauration

**Contexte** : après avoir restauré la base PostgreSQL et le filestore depuis
l'archive de sauvegarde, Odoo affichait une erreur serveur au lieu de la page
de login.

**Ce que j'ai demandé** : de l'aide pour diagnostiquer pourquoi Odoo ne
redémarrait pas correctement après une restauration manuelle du filestore via
`docker cp`.

**Ce que l'IA a proposé** : consulter les logs du conteneur (`docker logs
odoo_app`) pour identifier la cause exacte, puis a suggéré que le problème
venait probablement des permissions des fichiers copiés (`docker cp` copie
souvent les fichiers avec l'utilisateur `root`, alors qu'Odoo tourne avec un
utilisateur dédié dans le conteneur).

**Ce que j'ai gardé / modifié** : j'ai appliqué la commande de correction des
permissions proposée (`chown -R odoo:odoo /var/lib/odoo` exécutée avec
`-u root`), qui a effectivement résolu le problème. Je n'ai pas copié la
commande à l'aveugle : j'ai d'abord vérifié les logs moi-même pour comprendre
l'erreur avant d'appliquer le correctif.

**Ce que j'en ai retenu** : `docker cp` ne préserve pas l'utilisateur attendu
par l'application dans le conteneur cible — c'est un point de vigilance à
avoir systématiquement lors d'une restauration manuelle de fichiers.

---

## Prompt 2 — Aide à l'organisation des captures d'écran et des preuves

**Contexte** : au fil de la journée, j'accumulais beaucoup de captures
d'écran sans forcément les numéroter ou les nommer de façon cohérente avec
les livrables attendus par la grille de notation.

**Ce que j'ai demandé** : comment organiser mes captures pour qu'elles
correspondent clairement à chaque sous-critère de la grille (ex : preuve de
persistance, preuve de restauration, etc.).

**Ce que l'IA a proposé** : une convention de nommage numérotée
(`XX-description-courte.png`) alignée sur l'ordre chronologique des tâches du
PDF, et une checklist des captures encore manquantes à un moment donné du
test.

**Ce que j'ai gardé / modifié** : j'ai suivi la convention de nommage
proposée, mais j'ai adapté certains noms de fichiers à ma propre logique une
fois que j'ai vu l'ensemble de la série.

**Ce que j'en ai retenu** : documenter au fur et à mesure (et pas seulement à
la fin) évite d'oublier une preuve importante, surtout sur un test aussi long
avec plusieurs checkpoints.

---

## Prompt 3 — Rédaction du runbook de restauration

**Contexte** : une fois la restauration réussie, je devais rédiger
`docs/restauration.md`, un document que l'évaluateur doit pouvoir suivre sans
mon aide.

**Ce que j'ai demandé** : de l'aide pour transformer la séquence de commandes
que j'avais réellement exécutée (y compris l'incident de permissions et son
correctif) en un document structuré et lisible par un tiers.

**Ce que l'IA a proposé** : une structure en étapes numérotées, avec pour
chaque étape la commande exacte, le résultat attendu, et une section dédiée à
l'incident rencontré et à sa résolution.

**Ce que j'ai gardé / modifié** : j'ai vérifié que chaque commande du
document correspondait exactement à ce que j'avais tapé dans mon terminal
(et pas une version générique), pour que le document reflète fidèlement mon
propre déroulé et que je puisse l'expliquer en détail à l'oral.

**Ce que j'en ai retenu** : documenter un incident réel (et pas seulement le
chemin qui fonctionne du premier coup) rend le runbook beaucoup plus utile —
c'est souvent l'étape qui a posé problème qui sera la plus utile à quelqu'un
d'autre en cas de restauration future.

---

## Ce que j'ai appris de nouveau aujourd'hui

Au-delà de la stack Odoo elle-même, j'ai compris concrètement pourquoi la
gestion des permissions Unix à l'intérieur d'un conteneur est un point
critique lors de toute opération de copie de fichiers entre l'hôte et un
conteneur (`docker cp`), et pas seulement une question théorique de sécurité.
