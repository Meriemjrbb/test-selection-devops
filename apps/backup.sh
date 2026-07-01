#!/bin/bash
set -euo pipefail

# --- Configuration ---
BACKUP_DIR="$HOME/test-selection-devops/backup"
LOG_FILE="/var/log/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="backup_${TIMESTAMP}.tar.gz"
DB_CONTAINER="odoo_db"
ODOO_CONTAINER="odoo_app"
DB_NAME="${POSTGRES_DB:-odoo}"
DB_USER="${POSTGRES_USER:-odoo}"

mkdir -p "$BACKUP_DIR"
WORKDIR=$(mktemp -d)

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

log "=== Début du backup ==="

# 1. Dump PostgreSQL sans arrêter les conteneurs
log "Dump PostgreSQL en cours..."
docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" > "$WORKDIR/db_dump.sql"
log "Dump PostgreSQL terminé : $WORKDIR/db_dump.sql"

# 2. Copie du filestore Odoo depuis le volume
log "Copie du filestore Odoo en cours..."
docker cp "$ODOO_CONTAINER":/var/lib/odoo "$WORKDIR/odoo-filestore"
log "Filestore copié."

# 3. Archive tar.gz horodatée
log "Création de l'archive $ARCHIVE_NAME..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$WORKDIR" db_dump.sql odoo-filestore
log "Archive créée : $BACKUP_DIR/$ARCHIVE_NAME"

# Nettoyage
rm -rf "$WORKDIR"

log "=== Backup terminé avec succès ==="
echo "Backup terminé : $BACKUP_DIR/$ARCHIVE_NAME"
