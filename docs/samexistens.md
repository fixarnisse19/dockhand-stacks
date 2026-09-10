# Arcane sida vid sida med Dockhand, Portainer och Dokploy

Flera Docker-hanterare på samma värd är oproblematiskt — de läser alla samma
Docker-API och äger ingenting exklusivt. Det som kan gå fel är **sökvägarna** och
**vem som deployar vad**.

Kör `bash scripts/inspect-docker-layout.sh` på NAS:en först. Den listar varje
hanterare, dess bind mounts, alla compose-projekt med arbetskatalog, och
föreslår `ARCANE_ROOT`/`STACKS_DIR`.

## Mappkonventionen

En mapp per program under appkatalogen — det är vad både Portainer
(`/volume1/docker/portainer:/data`) och Dockhand följer, och det är där Arcane
ska ligga:

```
/volume1/docker/
├── portainer/
├── dockhand/app-data/
├── arcane/            <- ARCANE_ROOT
└── <appens namn>/
```

`ARCANE_ROOT` måste ligga **utanför** projektroten. Ligger den inuti ser Arcane
sig själv som ett projekt och kan inte deploya om sig
([arcane#2371](https://github.com/getarcaneapp/arcane/issues/2371)).
`install-arcane.sh` avbryter om du nästlar dem fel.

## Dela stacks-katalog med Dockhand

Dockhand lägger som standard sina stackar i `DATA_DIR/stacks` (`DATA_DIR`
är `/app/data` om inget annat sagts), och `STACKS_DIR` kan peka någon
annanstans. Inspektionsskriptet läser båda variablerna ur den körande
containern och översätter till värdens sökväg.

Pekar du Arcanes `STACKS_DIR` dit ser båda hanterarna samma stackar. Då gäller:

* **Matchande sökväg krävs.** `${STACKS_DIR}:${STACKS_DIR}`, aldrig
  `:/app/data/projects`. Dockhand rekommenderar samma sak av samma skäl
  (`/opt/dockhand:/opt/dockhand`): relativa bind mounts i stackarna måste peka
  på samma katalog inifrån som utifrån.
* **Deploya från ett ställe i taget.** Båda kan läsa och visa allt, men kör inte
  `up` på samma stack från båda samtidigt — sista skrivningen till `.env` vinner
  och du kan förlora ändringar.
* **Arcane skriver `project.env`.** För git-synkade projekt hålls dina värden i
  `project.env` och git-versionen i `.env.git`. Dockhand känner inte till den
  uppdelningen, så flytta en stack helt till Arcane innan du slår på Auto Sync.

Vill du hellre hålla dem åtskilda: låt `STACKS_DIR` peka på en egen katalog
(`/volume1/docker/stacks`) och flytta en stack i taget dit.

## Portainer

Portainer rör inte katalogstrukturen — dess stackar ligger i `/data` inuti
containern. Arcane och Portainer stör inte varandra. Vill du migrera: exportera
compose-filen från Portainer, lägg den i `stacks/<namn>/` i den här repon och
deploya via Arcane, och ta bort stacken i Portainer först när den nya kör.

## Dokploy

Dokploy kör i swarm-läge med egen Traefik. Se
[migreringsguiden](migrera-fran-dokploy.md) — kortversionen är att båda kan köra
parallellt, men bara en Traefik kan äga port 80/443.

## Portar

| Program | Port |
|---|---|
| Arcane | 3552 |
| Dockhand | 3000 |
| Portainer | 9443 / 9000 |
| Dokploy | 3000 |

Dockhand och Dokploy krockar på 3000 om båda publicerar den — Arcanes 3552
krockar inte med något av dem.
