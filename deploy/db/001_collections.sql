-- Collections de cartes des joueurs, indexées par SteamID (vérifié par le serveur).
-- Appliqué une seule fois par deploy/migrer_bdd.sh (table public.schema_migrations).
-- Ne jamais modifier une migration déjà déployée : en ajouter une nouvelle (002_...).

-- Seul ce schéma est exposé par PostgREST.
create schema api;

create table api.card_collection (
    steam_id    bigint      not null,
    -- Identifiant de CardDef (src/core/cards/data/), jamais renommé une fois distribué.
    card_id     text        not null,
    quantity    integer     not null check (quantity > 0),
    acquired_at timestamptz not null default now(),
    primary key (steam_id, card_id)
);

-- Rôles de PostgREST : il se connecte en « authenticator » et agit en « game_server ».
-- Le mot de passe d'authenticator est posé par migrer_bdd.sh (secret du VPS).
create role game_server nologin;
create role authenticator login noinherit;
grant game_server to authenticator;

-- Le serveur de jeu ne peut que lire les collections pour l'instant. Les boosters
-- passeront par une fonction SQL dédiée (ajout atomique), pas par un droit d'écriture libre.
grant usage on schema api to game_server;
grant select on api.card_collection to game_server;
