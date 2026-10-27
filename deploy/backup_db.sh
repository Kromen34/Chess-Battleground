#!/usr/bin/env bash
# Sauvegarde PostgreSQL du VPS (lancée chaque nuit par cron, voir remote_setup.sh).
# Garde 14 jours de dumps dans /opt/chessbg/backups. À compléter par une copie hors du VPS.
set -euo pipefail
BASE=/opt/chessbg
OUT="$BASE/backups/chessbg-$(date +%F).sql.gz"
cd "$BASE/src/deploy"
docker compose exec -T db pg_dump -U chessbg -d chessbg | gzip > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
find "$BASE/backups" -name 'chessbg-*.sql.gz' -mtime +14 -delete
echo "$(date -Is) sauvegarde OK : $OUT"
