# Image du serveur dédié : Godot 4.3 headless qui exécute scenes/server.tscn.
# Construite sur le VPS par tools/deployer_serveur.sh (contexte = racine du dépôt).

FROM ubuntu:24.04 AS godot
ARG GODOT_VERSION=4.3-stable
# Empreinte officielle (SHA512-SUMS.txt de la release) : à mettre à jour avec la version.
ARG GODOT_SHA512=fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
 && echo "${GODOT_SHA512}  /tmp/godot.zip" | sha512sum -c - \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot

FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --create-home --uid 10001 godot
COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
COPY --chown=godot:godot . /app
USER godot
WORKDIR /app
# Import du projet à la construction (génère .godot/), pour démarrer vite et
# pouvoir lancer le conteneur en lecture seule.
RUN timeout 300 godot --headless --path /app --import >/dev/null 2>&1 || true \
 && test -f /app/.godot/global_script_class_cache.cfg
EXPOSE 7777/udp
ENTRYPOINT ["godot", "--headless", "--path", "/app", "res://scenes/server.tscn", "--"]
CMD ["--port=7777"]
