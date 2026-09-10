#!/usr/bin/env bash
#
# Installerar/uppdaterar Arcane på spectre-green.
#
# Körs PÅ NAS:en, från den utcheckade repon:
#   sudo bash scripts/install-arcane.sh
#
# Idempotent: kan köras om hur många gånger som helst. En befintlig .env
# skrivs aldrig över och ENCRYPTION_KEY genereras bara första gången.
#
# Flaggor:
#   --autodetect  Läs av var Dockhand/Portainer och stackarna ligger på den
#                 här värden och sätt ARCANE_ROOT/STACKS_DIR därefter.
#   --hardened    Kör utan direkt tillgång till docker.sock.
#   -y, --yes     Fråga inget.
#
# Miljövariabler för icke-interaktiv körning:
#   ARCANE_HOST=arcane.example.com PROXY_NETWORK=dokploy-network \
#     bash scripts/install-arcane.sh --yes

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$REPO_ROOT/stacks/arcane"
ENV_FILE="$STACK_DIR/.env"
COMPOSE_FILE="${COMPOSE_FILE_OVERRIDE:-$STACK_DIR/compose.yaml}"
ASSUME_YES=0
AUTODETECT=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --autodetect) AUTODETECT=1 ;;
    --hardened) COMPOSE_FILE="$STACK_DIR/compose.socket-proxy.yaml" ;;
    -h|--help)
      sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Okänt argument: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mFEL:\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Förutsättningar ------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "docker hittades inte i PATH."
docker compose version >/dev/null 2>&1 \
  || die "Docker Compose v2 saknas (\`docker compose\`). Uppdatera Docker/Container Manager."
docker info >/dev/null 2>&1 \
  || die "Kan inte prata med Docker-daemonen. Kör som root eller lägg dig i docker-gruppen."

# --- 2. .env ----------------------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  log "Skapar $ENV_FILE från .env.example"
  cp "$STACK_DIR/.env.example" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
else
  log "Använder befintlig $ENV_FILE (rörs inte)"
fi

# Sätter en nyckel i .env utan att duplicera raden.
set_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    # | som avgränsare: värdena innehåller sökvägar och URL:er, inte pipes.
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}
get_env() { grep "^$1=" "$ENV_FILE" | head -n1 | cut -d= -f2- || true; }

# ENCRYPTION_KEY: genereras en enda gång. Byts den ut blir sparade
# registry-/git-credentials i databasen oläsbara.
if [ -z "$(get_env ENCRYPTION_KEY)" ]; then
  if command -v openssl >/dev/null 2>&1; then
    KEY="$(openssl rand -hex 32)"
  else
    KEY="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  fi
  [ "${#KEY}" -eq 64 ] || die "Kunde inte generera en 32-bytes ENCRYPTION_KEY."
  set_env ENCRYPTION_KEY "$KEY"
  log "ENCRYPTION_KEY genererad (32 bytes). Ta en backup av $ENV_FILE."
else
  log "ENCRYPTION_KEY finns redan — behålls."
fi

# Sökvägar: läs av hur värden faktiskt ser ut. Explicita miljövariabler
# vinner över autodetekteringen, som i sin tur vinner över filens värden.
if [ "$AUTODETECT" -eq 1 ]; then
  log "Läser av hur Docker ligger på den här värden"
  detected="$(bash "$REPO_ROOT/scripts/inspect-docker-layout.sh" --suggest || true)"
  if [ -z "$detected" ]; then
    warn "Autodetekteringen gav inget — behåller värdena i $ENV_FILE"
  else
    while IFS='=' read -r k v; do
      [ -n "$k" ] || continue
      if [ -n "${!k:-}" ]; then
        log "$k: behåller ${!k} från miljön (autodetektering föreslog $v)"
      else
        set_env "$k" "$v"
        log "$k=$v (autodetekterad)"
      fi
    done <<< "$detected"
  fi
fi

# Domän: från miljövariabel, annars fråga, annars behåll det som står i filen.
CUR_HOST="$(get_env ARCANE_HOST)"
if [ -n "${ARCANE_HOST:-}" ]; then
  set_env ARCANE_HOST "$ARCANE_HOST"
  set_env APP_URL "https://$ARCANE_HOST"
elif [ "$CUR_HOST" = "arcane.example.com" ] && [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; then
  read -r -p "Domän för Arcane [arcane.example.com]: " ans
  if [ -n "$ans" ]; then
    set_env ARCANE_HOST "$ans"
    set_env APP_URL "https://$ans"
  fi
fi

# Övriga överskrivningsbara värden.
for var in PROXY_NETWORK TRAEFIK_ENTRYPOINT TRAEFIK_CERTRESOLVER \
           ARCANE_ROOT STACKS_DIR PUID PGID TZ ARCANE_PORT ARCANE_BIND_ADDR \
           ARCANE_IMAGE_TAG; do
  if [ -n "${!var:-}" ]; then
    set_env "$var" "${!var}"
    log "$var satt till ${!var}"
  fi
done

[ "$(get_env ARCANE_HOST)" = "arcane.example.com" ] \
  && warn "ARCANE_HOST är fortfarande arcane.example.com — Traefik kommer inte att kunna utfärda något certifikat."

# --- 3. Kataloger -----------------------------------------------------------
ARCANE_ROOT_V="$(get_env ARCANE_ROOT)"
STACKS_DIR_V="$(get_env STACKS_DIR)"
PUID_V="$(get_env PUID)"; PUID_V="${PUID_V:-1000}"
PGID_V="$(get_env PGID)"; PGID_V="${PGID_V:-1000}"

[ -n "$ARCANE_ROOT_V" ] || die "ARCANE_ROOT saknas i $ENV_FILE"
[ -n "$STACKS_DIR_V" ]  || die "STACKS_DIR saknas i $ENV_FILE"

case "$STACKS_DIR_V/" in
  "$ARCANE_ROOT_V"/*) die "STACKS_DIR ligger inuti ARCANE_ROOT. Håll dem åtskilda." ;;
esac
case "$ARCANE_ROOT_V/" in
  "$STACKS_DIR_V"/*)
    warn "ARCANE_ROOT ligger inuti STACKS_DIR. Arcane kommer då att se sig själv"
    warn "som ett projekt och kan inte deploya om sig. Flytta ARCANE_ROOT."
    ;;
esac

for d in "$ARCANE_ROOT_V/data" "$ARCANE_ROOT_V/builds" "$ARCANE_ROOT_V/backups" "$STACKS_DIR_V"; do
  if [ ! -d "$d" ]; then
    log "Skapar $d"
    mkdir -p "$d"
  fi
  # Bara på kataloger vi äger-sätter; -R hade kunnat trampa på befintliga stackar.
  chown "$PUID_V:$PGID_V" "$d" 2>/dev/null || warn "Kunde inte sätta ägare på $d"
done
chmod 700 "$ARCANE_ROOT_V/data" 2>/dev/null || true

# --- 4. Proxy-nätverk -------------------------------------------------------
NET="$(get_env PROXY_NETWORK)"; NET="${NET:-proxy}"
if ! docker network inspect "$NET" >/dev/null 2>&1; then
  warn "Docker-nätverket '$NET' finns inte."
  warn "Kör Traefik redan? Ta reda på dess nätverk med:"
  warn "  docker inspect -f '{{range \$k,\$v := .NetworkSettings.Networks}}{{\$k}} {{end}}' <traefik-container>"
  if [ "$ASSUME_YES" -eq 1 ] || { [ -t 0 ] && read -r -p "Skapa '$NET' nu? [j/N] " a && [ "$a" = "j" ]; }; then
    docker network create "$NET"
    log "Nätverket '$NET' skapat. Traefik måste också anslutas till det."
  else
    die "Avbryter. Sätt PROXY_NETWORK i $ENV_FILE till Traefiks befintliga nätverk."
  fi
fi

# --- 5. Deploy --------------------------------------------------------------
log "Validerar compose-filen"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config --quiet

log "Hämtar image"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull

log "Startar Arcane"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans

# --- 6. Vänta på health -----------------------------------------------------
log "Väntar på att containern ska bli frisk (upp till 90 s)"
i=0
while [ "$i" -lt 45 ]; do
  i=$((i+1))
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' arcane 2>/dev/null || echo missing)"
  case "$status" in
    healthy) log "Arcane är igång."; break ;;
    none)    log "Containern saknar healthcheck-status — antar att den är uppe."; break ;;
    missing) die "Containern 'arcane' startade inte. Se: docker compose -f $COMPOSE_FILE logs" ;;
  esac
  sleep 2
done
if [ "${status:-}" = "starting" ] || [ "${status:-}" = "unhealthy" ]; then
  warn "Status är '$status'. Kolla loggarna:"
  warn "  docker logs --tail 100 arcane"
fi

PORT_V="$(get_env ARCANE_PORT)"; PORT_V="${PORT_V:-3552}"
cat <<EOF

────────────────────────────────────────────────────────────
 Arcane är deployad.

   Via Traefik : $(get_env APP_URL)
   Direkt      : http://<nas-ip>:$PORT_V   (fallback om proxyn ligger nere)

 Första inloggningen: admin / admin
 (fungerar den inte, prova arcane / arcane-admin)
 Du tvingas byta lösenord direkt. Slå på MFA under Settings.

 Projektrot: $STACKS_DIR_V
 Nästa steg finns i stacks/arcane/README.md
────────────────────────────────────────────────────────────
EOF
