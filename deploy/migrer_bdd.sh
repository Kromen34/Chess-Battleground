#!/usr/bin/env bash
# Exécuté SUR le VPS par remote_setup.sh, la BDD démarrée : applique dans l'ordre les
# deploy/db/*.sql pas encore passés (notés dans public.schema_migrations), chacun dans
# une transaction, puis pose le mot de passe du rôle PostgREST et recharge son cache.
set -euo pipefail
cd "$(dirname "$0")"
BASE=/opt/chessbg

psql() { docker compose exec -T db psql -U chessbg -d chessbg -v ON_ERROR_STOP=1 -q "$@"; }

psql -c "create table if not exists public.schema_migrations (
  name text primary key, applied_at timestamptz not null default now())"

for f in db/*.sql; do
  name="$(basename "$f")"
  if [[ -n "$(psql -tAc "select 1 from public.schema_migrations where name = '$name'")" ]]; then
    continue
  fi
  echo "Migration $name..."
  { echo "begin;"; cat "$f"; echo; echo "insert into public.schema_migrations (name) values ('$name');"; echo "commit;"; } | psql
done

# Mot de passe du rôle authenticator (PostgREST) : envoyé par l'entrée standard, jamais
# en argument de commande (visible dans la liste des processus).
printf "alter role authenticator password '%s';\n" "$(cat "$BASE/secrets/postgrest_password.txt")" | psql
# PostgREST relit le schéma (nouvelles tables) sans redémarrer.
psql -c "notify pgrst, 'reload schema'"
