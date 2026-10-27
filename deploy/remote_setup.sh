#!/usr/bin/env bash
# Exécuté SUR le VPS par tools/deployer_serveur.sh, après copie du code dans
# /opt/chessbg/src : prépare secrets et sauvegardes, puis (re)construit et relance la stack.
set -euo pipefail
BASE=/opt/chessbg
SRC="$BASE/src"

# Mot de passe PostgreSQL : généré une seule fois, jamais dans git.
mkdir -p "$BASE/secrets" "$BASE/backups"
chmod 700 "$BASE/secrets" "$BASE/backups"
if [[ ! -s "$BASE/secrets/db_password.txt" ]]; then
  openssl rand -base64 32 | tr -d '\n' > "$BASE/secrets/db_password.txt"
  echo "Mot de passe PostgreSQL généré dans $BASE/secrets/db_password.txt"
fi
# Lisible par l'utilisateur postgres (uid 70) du conteneur, pas par les autres.
sudo chown 70:ubuntu "$BASE/secrets/db_password.txt"
sudo chmod 440 "$BASE/secrets/db_password.txt"
sudo chown ubuntu:ubuntu "$BASE/secrets"
chmod 750 "$BASE/secrets"

# Sauvegarde quotidienne de la BDD (04:30), conservée 14 jours.
install -m 755 "$SRC/deploy/backup_db.sh" "$BASE/backup_db.sh"
echo "30 4 * * * ubuntu $BASE/backup_db.sh >> $BASE/backups/backup.log 2>&1" \
  | sudo tee /etc/cron.d/chessbg-backup >/dev/null

cd "$SRC/deploy"
docker compose up -d --build --remove-orphans
docker image prune -f >/dev/null
docker compose ps
