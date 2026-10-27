#!/usr/bin/env bash
# Déploie le commit courant (HEAD) sur le VPS et relance le serveur.
#   bash tools/deployer_serveur.sh            -> hôte SSH "chessbg" (voir ~/.ssh/config)
#   CHESSBG_HOST=autre bash tools/deployer_serveur.sh
# Seul ce qui est commité part : les modifications locales non commitées sont ignorées.
set -euo pipefail
HOST="${CHESSBG_HOST:-chessbg}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Attention : modifications non commitées, elles ne seront pas déployées." >&2
fi
REV="$(git rev-parse --short HEAD)"
echo "Déploiement de $REV sur $HOST..."

git archive --format=tar HEAD | ssh "$HOST" "set -e
  sudo mkdir -p /opt/chessbg && sudo chown ubuntu:ubuntu /opt/chessbg
  rm -rf /opt/chessbg/src.new && mkdir -p /opt/chessbg/src.new
  tar -x -C /opt/chessbg/src.new
  echo $REV > /opt/chessbg/src.new/REVISION
  rm -rf /opt/chessbg/src && mv /opt/chessbg/src.new /opt/chessbg/src"

ssh "$HOST" "bash /opt/chessbg/src/deploy/remote_setup.sh"
echo "Déployé : $REV. Logs : ssh $HOST 'cd /opt/chessbg/src/deploy && docker compose logs -f game'"
