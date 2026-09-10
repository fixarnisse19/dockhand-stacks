#!/usr/bin/env bash
#
# Kartlägger hur Docker faktiskt ligger på den här värden: var de andra
# hanterarna (Dockhand, Portainer, Dokploy ...) har sin data, var stackarna
# ligger, och vilken katalog som är "app-roten".
#
# Körs PÅ NAS:en:
#   bash scripts/inspect-docker-layout.sh
#
# Läser bara — ändrar ingenting.
#
#   --suggest   Skriv bara ut KEY=value för ARCANE_ROOT och STACKS_DIR.
#               Används av install-arcane.sh --autodetect.

set -euo pipefail

SUGGEST_ONLY=0
[ "${1:-}" = "--suggest" ] && SUGGEST_ONLY=1

command -v docker >/dev/null 2>&1 || { echo "docker saknas i PATH" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Kan inte prata med Docker-daemonen (kör som root?)" >&2; exit 1; }

say() { [ "$SUGGEST_ONLY" -eq 1 ] || printf '%s\n' "$*"; }
hdr() { [ "$SUGGEST_ONLY" -eq 1 ] || printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

# Systemsökvägar som inte säger något om var appdata ligger.
is_boring() {
  case "$1" in
    /var/run/*|/run/*|/proc/*|/sys/*|/dev/*|/etc/localtime|/etc/timezone|/etc/hosts*|/etc/resolv.conf|/usr/*|/lib/*|/) return 0 ;;
    *) return 1 ;;
  esac
}

containers="$(docker ps -a --format '{{.Names}}' | sort)"
[ -n "$containers" ] || { echo "Inga containrar på den här värden." >&2; exit 1; }

# --- Hjälpare ---------------------------------------------------------------

# Alla bind mounts för en container, som "källa|destination".
binds_of() {
  docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}|{{.Destination}}{{"\n"}}{{end}}{{end}}' "$1" 2>/dev/null
}

env_of() {
  docker inspect -f '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' "$1" 2>/dev/null
}

# Värdet på en miljövariabel i en container.
env_val() {
  env_of "$1" | grep "^$2=" | head -n1 | cut -d= -f2- || true
}

# Översätt en sökväg inuti containern till motsvarande sökväg på värden,
# genom att hitta den bind mount vars destination är längsta prefixet.
map_to_host() {
  local c="$1" cpath="$2" best_dst="" best_src="" src dst
  while IFS='|' read -r src dst; do
    [ -n "$dst" ] || continue
    case "$cpath/" in
      "$dst"/*|"$dst")
        if [ "${#dst}" -gt "${#best_dst}" ]; then best_dst="$dst"; best_src="$src"; fi
        ;;
    esac
  done <<EOF
$(binds_of "$c")
EOF
  if [ -n "$best_dst" ]; then
    printf '%s%s\n' "$best_src" "${cpath#"$best_dst"}"
  fi
}

# --- 1. Kända hanterare -----------------------------------------------------

hdr "Docker-hanterare på den här värden"

DOCKHAND_STACKS=""
MANAGER_PARENTS=""

for c in $containers; do
  image="$(docker inspect -f '{{.Config.Image}}' "$c" 2>/dev/null || echo '?')"
  kind=""
  case "$image$c" in
    *dockhand*)  kind="Dockhand" ;;
    *portainer*) kind="Portainer" ;;
    *dokploy*)   kind="Dokploy" ;;
    *yacht*)     kind="Yacht" ;;
    *dockge*)    kind="Dockge" ;;
    *komodo*)    kind="Komodo" ;;
    *arcane*|*getarcaneapp*) kind="Arcane" ;;
    *) continue ;;
  esac

  say ""
  say "  $kind  ($c — $image)"
  binds_of "$c" | while IFS='|' read -r src dst; do
    [ -n "$src" ] || continue
    is_boring "$src" && continue
    say "      $src  ->  $dst"
  done

  # Var den här hanteraren har sina egna filer: föräldern till första
  # intressanta bind-källan. Det är den katalog Arcane ska ligga bredvid.
  first_src="$(binds_of "$c" | cut -d'|' -f1 | while read -r s; do is_boring "$s" || { echo "$s"; break; }; done)"
  if [ -n "$first_src" ]; then
    # /volume1/docker/portainer -> /volume1/docker
    parent="$(dirname "$first_src")"
    case "$(basename "$first_src")" in
      # app-data, data, config o.dyl. ligger ett steg in i appens egen mapp
      app-data|data|config) parent="$(dirname "$parent")" ;;
    esac
    MANAGER_PARENTS="$MANAGER_PARENTS$parent
"
  fi

  # Dockhand: härled var stackarna ligger på värden.
  if [ "$kind" = "Dockhand" ]; then
    d_data="$(env_val "$c" DATA_DIR)"; d_data="${d_data:-/app/data}"
    d_stacks="$(env_val "$c" STACKS_DIR)"; d_stacks="${d_stacks:-$d_data/stacks}"
    say "      DATA_DIR=$d_data   STACKS_DIR=${d_stacks}  (i containern)"
    host_stacks="$(map_to_host "$c" "$d_stacks")"
    if [ -n "$host_stacks" ]; then
      say "      => stackarna på värden: $host_stacks"
      DOCKHAND_STACKS="$host_stacks"
    else
      say "      => stackarna ligger i en namngiven volym, inte i en värdkatalog"
    fi
  fi
done

[ -n "$MANAGER_PARENTS" ] || say "  (hittade inga kända hanterare)"

# --- 2. Var appdata ligger --------------------------------------------------

hdr "Vanligaste appkataloger (antal bind mounts per förälder)"

all_parents=""
for c in $containers; do
  while IFS='|' read -r src _; do
    [ -n "$src" ] || continue
    is_boring "$src" && continue
    all_parents="$all_parents$(dirname "$src")
"
  done <<EOF
$(binds_of "$c")
EOF
done

TOP_PARENT="$(printf '%s' "$all_parents" | grep -v '^$' | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')"
[ "$SUGGEST_ONLY" -eq 1 ] || printf '%s' "$all_parents" | grep -v '^$' | sort | uniq -c | sort -rn | head -n 15 | sed 's/^/  /'

# --- 3. Compose-projekt -----------------------------------------------------

hdr "Compose-projekt och deras arbetskataloger"

projects=""
for c in $containers; do
  line="$(docker inspect -f '{{with index .Config.Labels "com.docker.compose.project"}}{{.}}{{end}}|{{with index .Config.Labels "com.docker.compose.project.working_dir"}}{{.}}{{end}}' "$c" 2>/dev/null || true)"
  case "$line" in
    "|"|"") continue ;;
  esac
  projects="$projects$line
"
done
if [ -n "$projects" ]; then
  [ "$SUGGEST_ONLY" -eq 1 ] || printf '%s' "$projects" | grep -v '^$' | sort -u \
    | awk -F'|' '{printf "  %-28s %s\n", $1, $2}'
else
  say "  (inga compose-hanterade containrar)"
fi

# Den katalog flest compose-projekt ligger i — starkaste kandidaten för
# STACKS_DIR, eftersom det är där stackarna faktiskt bor idag.
COMMON_WORKDIR="$(printf '%s' "$projects" | grep -v '^$' | cut -d'|' -f2 | grep -v '^$' \
  | while read -r w; do dirname "$w"; done | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')"

# --- 4. Förslag -------------------------------------------------------------

# App-roten: den katalog de andra hanterarna ligger i.
APP_ROOT="$(printf '%s' "$MANAGER_PARENTS" | grep -v '^$' | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')"
[ -n "$APP_ROOT" ] || APP_ROOT="$TOP_PARENT"
[ -n "$APP_ROOT" ] || APP_ROOT="/volume1/docker"

SUGGEST_STACKS="${DOCKHAND_STACKS:-${COMMON_WORKDIR:-$APP_ROOT/stacks}}"

# Arcanes egen katalog får inte ligga inuti projektroten — då ser den sig
# själv som ett projekt och kan inte deploya om sig.
SUGGEST_ROOT="$APP_ROOT/arcane"
case "$SUGGEST_ROOT/" in
  "$SUGGEST_STACKS"/*) SUGGEST_ROOT="$(dirname "$SUGGEST_STACKS")/arcane" ;;
esac
case "$SUGGEST_ROOT/" in
  "$SUGGEST_STACKS"/*) SUGGEST_ROOT="/opt/arcane" ;;
esac

if [ "$SUGGEST_ONLY" -eq 1 ]; then
  printf 'ARCANE_ROOT=%s\n' "$SUGGEST_ROOT"
  printf 'STACKS_DIR=%s\n' "$SUGGEST_STACKS"
  exit 0
fi

hdr "Förslag för stacks/arcane/.env"
say ""
say "  # Arcane läggs bredvid de andra hanterarna i $APP_ROOT"
say "  ARCANE_ROOT=$SUGGEST_ROOT"
say "  STACKS_DIR=$SUGGEST_STACKS"
say ""
say "  Kör  sudo bash scripts/install-arcane.sh --autodetect  för att sätta dem."
say ""
say "  STACKS_DIR monteras på SAMMA sökväg inuti containern som på värden."
say "  Annars pekar relativa bind mounts i stackarna (./config:/config) fel,"
say "  och projektens status visas felaktigt som stoppad."
say "  https://github.com/getarcaneapp/arcane/issues/2597"
