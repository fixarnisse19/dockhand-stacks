# Arcane på spectre-green

Webbgränssnitt för hela Docker-installationen på NAS:en: containrar, images,
volymer, nätverk, compose-projekt, loggar, terminal, image-builds,
volymbackuper och GitOps mot den här repon.

* Image: `ghcr.io/getarcaneapp/manager`
* Port: `3552`
* Dokumentation: <https://getarcane.app/docs>

## Så här ligger det på NAS:en

Arcane läggs i samma appkatalog som de andra hanterarna — en mapp per program,
vilket är konventionen både Portainer (`/volume1/docker/portainer:/data`) och
Dockhand följer:

```
/volume1/docker/
├── portainer/               Portainers data
├── dockhand/
│   └── app-data/            Dockhands DATA_DIR
│       └── stacks/          ← stackarna bor här
├── arcane/                  ARCANE_ROOT — Arcanes egen data
│   ├── data/                databas, inställningar, git-arbetskopior  (/app/data)
│   ├── builds/              arbetsyta för image-builds                (/builds)
│   └── backups/             rustic-snapshots av volymer              (/backups)
├── vaultwarden/
└── ...
```

Var stackarna ligger hos *dig* vet bara NAS:en. Kör

```bash
bash scripts/inspect-docker-layout.sh
```

så listas varje hanterare, dess bind mounts, alla compose-projekt med sina
arbetskataloger, och ett förslag på `ARCANE_ROOT`/`STACKS_DIR`. Skriptet läser
bara — det ändrar ingenting.

### Två regler som styr sökvägarna

**1. `STACKS_DIR` monteras på samma sökväg inuti containern som på värden.**

```yaml
- ${STACKS_DIR}:${STACKS_DIR}      # inte :/app/data/projects
```

Docker-daemonen tolkar alla bind mounts mot *värdens* filsystem. Monteras
projektroten på en annan sökväg inuti Arcane pekar en stack med
`./config:/config` på en katalog som bara finns inuti Arcane-containern. Samma
avvikelse gör att Arcane jämför fel `com.docker.compose.project.working_dir`
och visar körande projekt som stoppade ([arcane#2597]).

Delar du katalog med Dockhand är matchande sökvägar dessutom vad Dockhand själv
rekommenderar (`/opt/dockhand:/opt/dockhand` med `DATA_DIR=/opt/dockhand`), så
båda hanterarna ser stackarna likadant.

**2. `ARCANE_ROOT` ligger utanför `STACKS_DIR`.**

Låg den inuti skulle Arcane se sig själv som ett projekt, och en container kan
inte riva och återskapa sig själv mitt i en redeploy ([arcane#2371]).
Installationsskriptet vägrar starta om sökvägarna nästlas fel. Uppgradera
Arcane från kommandoraden i stället — se *Uppgradera* nedan.

[arcane#2371]: https://github.com/getarcaneapp/arcane/issues/2371
[arcane#2597]: https://github.com/getarcaneapp/arcane/issues/2597

## Installation

Checka ut repon på NAS:en och kör installationsskriptet:

```bash
git clone https://github.com/fixarnisse19/dockhand-stacks.git /volume1/docker/arcane/repo
cd /volume1/docker/arcane/repo

bash scripts/inspect-docker-layout.sh          # var ligger allting idag?
sudo bash scripts/install-arcane.sh --autodetect
```

`--autodetect` sätter `ARCANE_ROOT`, `STACKS_DIR`, `PUID` och `PGID` efter vad
som faktiskt finns på värden: Arcane hamnar bredvid Dockhand och Portainer,
projektroten pekas på den katalog stackarna redan ligger i, och användaren tas
från den hanterare som redan skriver där (på Synology typiskt `1026:100`, inte
`1000:1000`). Utan flaggan används värdena i `.env`. Miljövariabler du sätter
själv vinner alltid över autodetekteringen.

Skriptet **chown:ar aldrig en katalog som redan fanns** — att ta över ägarskapet
på Dockhands stacks-katalog kan ta ifrån Dockhand skrivrätten. Stämmer inte
ägaren med `PUID`/`PGID` varnar det och ber dig ändra `.env` i stället.

Skriptet frågar efter domän, genererar `ENCRYPTION_KEY`, skapar katalogerna med
rätt ägare, kontrollerar att Traefiks nätverk finns och startar stacken. Det är
idempotent — kör om det när du vill.

Icke-interaktivt:

```bash
sudo ARCANE_HOST=arcane.dindoman.se PROXY_NETWORK=dokploy-network \
     PUID=$(id -u din-användare) PGID=$(id -g din-användare) \
     bash scripts/install-arcane.sh --yes
```

Vill du köra utan direkt tillgång till Docker-socketen: lägg till `--hardened`,
då används [`compose.socket-proxy.yaml`](compose.socket-proxy.yaml) i stället.

### Första inloggningen

1. Öppna `https://<din-domän>` (eller `http://<nas-ip>:3552`).
2. Logga in med `admin` / `admin`. Fungerar det inte, prova
   `arcane` / `arcane-admin`.
3. Byt lösenord direkt — Arcane tvingar fram det.
4. **Settings → Security**: slå på MFA eller registrera en passkey.
   Containern har fullt Docker-API, så kontot är i praktiken root på NAS:en.
5. **Settings → Builds**: sätt *Builds Directory* till `/builds`.

## Konfiguration

Allt sitter i `.env` bredvid `compose.yaml` (kopia av
[`.env.example`](.env.example), gitignorerad).

| Variabel | Betydelse |
|---|---|
| `ARCANE_HOST` | Domänen Traefik svarar på |
| `APP_URL` | Måste vara exakt samma URL som du surfar på — annars går websockets, OIDC och passkeys sönder |
| `ENCRYPTION_KEY` | 32 bytes. Krypterar registry-lösenord, git-tokens och OIDC-secrets i databasen |
| `ARCANE_ROOT` / `STACKS_DIR` | Sökvägarna ovan — sätts enklast med `--autodetect` |
| `PROXY_NETWORK` | Traefiks docker-nätverk (`proxy`, eller `dokploy-network` om du använder Dokploys Traefik) |
| `TRUSTED_PROXIES` | CIDR:er som får sätta `X-Forwarded-For` |
| `PUID` / `PGID` | Ägare till filerna Arcane skriver i `STACKS_DIR` |
| `ARCANE_PORT` / `ARCANE_BIND_ADDR` | Direktporten som fallback när proxyn ligger nere |
| `ARCANE_IMAGE_TAG` | `latest`, eller pinna en version |

> **Säkerhetskopiera `.env`.** Tappar du `ENCRYPTION_KEY` går alla sparade
> credentials i databasen förlorade och måste läggas in på nytt.

### Traefik

`compose.yaml` sätter två routrar:

* `arcane-web` (priority 10) — UI, REST-API och websockets (loggar, terminal,
  live-statistik).
* `arcane-grpc` (priority 100) — `POST /api/tunnel/connect` med
  `Content-Type: application/grpc`, backend-schema `h2c`. Behövs för
  edge-agenter på andra Docker-värdar.

Traefik måste ligga på samma nätverk som `PROXY_NETWORK` pekar ut. Terminal och
loggströmmar är långlivade anslutningar — sätt på Traefiks entrypoint:

```
--entrypoints.websecure.transport.respondingtimeouts.readtimeout=0s
```

Utan det bryts terminalsessioner efter Traefiks standardtimeout.

### Direktporten

Port `3552` publiceras även med Traefik igång, med flit: går reverse proxyn ner
måste du fortfarande kunna nå Docker-hanteringen. Är NAS:en exponerad mot
internet — sätt `ARCANE_BIND_ADDR` till LAN-IP:t eller `127.0.0.1`.

## Drift

```bash
cd /volume1/docker/arcane/repo/stacks/arcane

docker compose --env-file .env logs -f          # loggar
docker compose --env-file .env ps               # status
docker compose --env-file .env restart          # starta om
```

### Uppgradera

```bash
cd /volume1/docker/arcane/repo && git pull
sudo bash scripts/install-arcane.sh --yes       # pull + up -d, .env rörs inte
```

Före en större uppgradering: ta en kopia av `${ARCANE_ROOT}/data` (SQLite-fil
plus inställningar). Arcane vägrar som standard nedgradering — `ALLOW_DOWNGRADE`
finns men databasmigreringar går inte alltid att rulla tillbaka, så en kopia är
den riktiga vägen tillbaka.

### Backup

Två separata saker:

1. **Arcanes egen konfiguration** — `${ARCANE_ROOT}/data` + `.env`. Ta med i
   NAS:ens vanliga backupjobb.
2. **Volymbackuper** — Arcane kör rustic i kortlivade containrar och lägger
   snapshots i `${ARCANE_ROOT}/backups`. En lokal backup på samma disk skyddar
   inte mot diskhaveri; konfigurera S3-mål under **Backups** också.

## Felsökning

| Symptom | Orsak |
|---|---|
| `Additional property cgroup is not allowed` | För gammal Docker Compose. Kommentera bort `cgroup: host` i `compose.yaml` — bara statistikgrafer påverkas. |
| Traefik hittar inte tjänsten | `PROXY_NETWORK` matchar inte Traefiks nätverk, eller Traefik är inte ansluten till det. |
| Terminal/loggar dör efter ~60 s | `readtimeout` på Traefiks entrypoint, se ovan. |
| Inloggning studsar tillbaka | `APP_URL` matchar inte adressen i webbläsaren. |
| Containern blir `unhealthy` | `docker logs --tail 100 arcane`. Vid första start körs databasmigreringar — `start_period` är 30 s. |
| Inga projekt syns | Fel `STACKS_DIR`, eller compose-filerna ligger djupare än `PROJECT_SCAN_MAX_DEPTH`. Kör `scripts/inspect-docker-layout.sh`. |
| Projekt visas som stoppade fast de kör | `STACKS_DIR` är monterad på en annan sökväg inuti containern. Ska vara `${STACKS_DIR}:${STACKS_DIR}` ([arcane#2597]). |
| Stackens `./config`-mappar hamnar fel | Samma sak — matchande sökväg saknas. |
| `permission denied` mot socketen | Kör Arcane som root på värden eller använd `--hardened`-varianten. |

## Se även

* [Migrera från Dokploy](../../docs/migrera-fran-dokploy.md)
* [Mall för app bakom Traefik](../../templates/app-with-traefik/)
* [Edge-agent för fler Docker-värdar](../arcane-agent/)
