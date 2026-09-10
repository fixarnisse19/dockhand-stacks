# dockhand-stacks

Docker-stackar för **spectre-green**, hanterade av
[Arcane](https://getarcane.app/). Repot är sanningskällan: Arcane synkar
projekten härifrån via GitOps, secrets stannar på NAS:en.

## Innehåll

| Sökväg | Vad |
|---|---|
| [`stacks/arcane/`](stacks/arcane/) | Arcane själv — deployas en gång med `scripts/install-arcane.sh` |
| [`stacks/arcane-agent/`](stacks/arcane-agent/) | Edge-agent för andra Docker-värdar |
| [`templates/`](templates/) | Mallar, i Arcanes format för lokala templates |
| [`scripts/inspect-docker-layout.sh`](scripts/inspect-docker-layout.sh) | Kartlägger hur Docker ligger på värden och föreslår sökvägar |
| [`scripts/install-arcane.sh`](scripts/install-arcane.sh) | Idempotent installations-/uppdateringsskript |
| [`docs/samexistens.md`](docs/samexistens.md) | Arcane sida vid sida med Dockhand, Portainer och Dokploy |
| [`docs/migrera-fran-dokploy.md`](docs/migrera-fran-dokploy.md) | Migrering från Dokploy, app för app |

## Kom igång

```bash
git clone https://github.com/fixarnisse19/dockhand-stacks.git /volume1/docker/arcane/repo
cd /volume1/docker/arcane/repo

bash scripts/inspect-docker-layout.sh          # var ligger allting idag?
sudo bash scripts/install-arcane.sh --autodetect
```

Sedan `https://<din-domän>`, logga in med `admin` / `admin` och byt lösenord.
Detaljer i [`stacks/arcane/README.md`](stacks/arcane/README.md).

## Lägga till en app

```bash
cp -r templates/app-with-traefik stacks/minapp
$EDITOR stacks/minapp/compose.yaml
git add stacks/minapp && git commit -m "Lägg till minapp" && git push
```

I Arcane: **Projects → Create Project → From Git Repo**, peka på
`stacks/minapp/compose.yaml` och slå på Auto Sync.

## Konventioner

* En katalog per stack under `stacks/`, med `compose.yaml`.
* `.env` committas **aldrig** — bara `.env.example`. Riktiga värden läggs in i
  Arcanes UI och sparas i projektets `project.env` på NAS:en.
* Appar publicerar inga portar; de nås via Traefik-labels på proxy-nätverket.
* En mapp per program under appkatalogen, precis som Portainer och Dockhand —
  Arcanes egen data i `/volume1/docker/arcane/`, utanför projektroten.
* Projektroten monteras på **samma sökväg** inuti containern som på värden,
  annars pekar relativa bind mounts fel. Se
  [`docs/samexistens.md`](docs/samexistens.md).
