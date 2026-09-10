# Migrera från Dokploy till Arcane

Upplägget här är att **köra båda parallellt**. Arcane installeras utan att röra
Dokploys portar, Traefik eller data, du flyttar en app i taget, och Dokploy
stängs av först när ingenting är kvar. Går något fel finns Dokploy hela tiden
kvar orörd.

## Innan du börjar: vad du faktiskt byter mot vad

Arcane är en Docker- och compose-hanterare, inte en PaaS. Det mesta blir
enklare och mer genomskinligt — men tre saker gör Dokploy som du får lösa på
annat sätt.

| Dokploy | Arcane |
|---|---|
| Deploya från git | **Git-synkade projekt** — repo + sökväg till compose-filen, med Auto Sync |
| Domän + TLS via formulär | Traefik-labels i compose-filen (mallen i `templates/app-with-traefik/`) |
| Miljövariabler i UI | `.env` i projektkatalogen, redigerbar i Arcanes UI |
| Bygga från källkod | **Image Builds** — men kräver Dockerfile, ingen Nixpacks-autodetektering |
| Ett-klicks-databaser | Compose-mall från templates eller community-registret |
| Volymbackuper | **Backups** — rustic-snapshots, lokalt och/eller S3 |
| Flera servrar | **Environments** med edge-agenter (`stacks/arcane-agent/`) |
| Preview-deploys per PR | Finns inte |
| Instant redeploy via push-webhook | Auto Sync pollar repot med valt intervall |
| Inbyggd Traefik | Du äger Traefik själv |

Tre saker att fatta beslut om **innan** du börjar:

1. **Appar som Dokploy byggde med Nixpacks** behöver en Dockerfile, eller en
   färdig image i ett registry. Skriv Dockerfilen först — det är oftast den
   enda riktigt tidskrävande biten i hela migreringen.
2. **Traefik.** Antingen behåller du Dokploys Traefik (sätt
   `PROXY_NETWORK=dokploy-network` i `stacks/arcane/.env`) och äger den själv
   när Dokploy är borta, eller så startar du en egen Traefik på ett nytt
   nätverk. Kör du en egen kan bara en av dem lyssna på 80/443 — låt Dokploys
   ha dem tills du är klar och byt sist.
3. **Databasernas data.** Ligger i namngivna Docker-volymer. De flyttas inte —
   du pekar bara den nya compose-filen på samma volym. Se steg 4.

## 1. Installera Arcane

Enligt [`stacks/arcane/README.md`](../stacks/arcane/README.md). Använder du
Dokploys Traefik:

```bash
sudo ARCANE_HOST=arcane.dindoman.se PROXY_NETWORK=dokploy-network \
     bash scripts/install-arcane.sh --yes
```

Arcane rör inte Dokploy. Den ser Dokploys containrar i UI:t direkt — det är bara
Docker — men Dokploys egna stackar hanteras fortfarande av Dokploy tills du
flyttar dem.

Kontrollera innan du går vidare: Dokploy svarar fortfarande, och dess appar
fungerar.

## 2. Inventera vad som ska flyttas

För varje app i Dokploy, skriv ned:

* image (eller git-repo + Dockerfile)
* domän
* portar
* miljövariabler och secrets
* volymer — exakta namn:
  ```bash
  docker inspect -f '{{range .Mounts}}{{.Type}} {{.Name}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' <container>
  ```
* nätverk och beroenden mellan tjänster

Ett snabbt utkast på compose-filen från en körande container:

```bash
docker inspect <container> | less
```

Titta särskilt på `Env`, `Mounts`, `NetworkSettings.Networks` och `Labels`.

## 3. Lägg appen i den här repon

```bash
cp -r templates/app-with-traefik stacks/minapp
cd stacks/minapp
$EDITOR compose.yaml .env.example
```

Committa och pusha. Mallen har redan Traefik-labels, healthcheck och rätt
nätverk.

## 4. Peka på den befintliga volymen

Det här är det enda steget där data kan gå förlorad, så gör det medvetet.
Databasen ligger kvar i sin volym; deklarera den som **extern** så att compose
använder den i stället för att skapa en ny:

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
    external: true
    name: dokploy-minapp-postgres-data   # exakt namn från docker volume ls
```

Ta en dump först — `docker exec ... pg_dump` eller motsvarande — och lägg den
någonstans utanför volymen.

## 5. Koppla in GitOps

I Arcane:

1. **Customization → Git Repositories** — lägg till den här repon med en
   HTTPS-token (read-only räcker) eller SSH-nyckel.
2. **Projects → Create Project → From Git Repo** — välj repot, ange
   `stacks/minapp/compose.yaml`.
3. Slå på **Auto Sync**, och **Redeploy After Sync** om du vill att en push ska
   rulla ut ändringen automatiskt.

Notera hur Arcane hanterar filerna: hela katalogen som compose-filen ligger i
hämtas, inte bara filen. Compose-filen blir skrivskyddad i UI:t — den ägs av
git. `.env` går fortfarande att redigera, och dina ändringar sparas separat i
`project.env` medan `.env.git` behåller värdena från repot. Secrets stannar
alltså på NAS:en och behöver aldrig committas.

## 6. Byt över, en app i taget

1. Stoppa appen i **Dokploy** (stoppa, ta inte bort — då finns vägen tillbaka).
2. Deploya projektet i Arcane.
3. Kontrollera: svarar domänen, är certifikatet giltigt, ser loggarna friska ut,
   finns data kvar?
4. Först när allt stämmer: ta bort appen i Dokploy.

Går något fel — starta appen i Dokploy igen och stoppa Arcane-projektet.

## 7. Avveckla Dokploy

När inga appar är kvar:

```bash
# Vad Dokploy fortfarande kör
docker ps --filter "label=com.docker.compose.project=dokploy"
docker service ls          # Dokploy kör i swarm-läge

# Stäng av — men behåll allt, så att beslutet går att ångra
docker service scale dokploy=0
```

Låt det stå så i någon vecka. Är allt lugnt kan du avinstallera på riktigt:

```bash
docker service rm dokploy
docker stack rm dokploy 2>/dev/null || true
# Kontrollera vad som ligger i /etc/dokploy innan du raderar
ls -la /etc/dokploy
```

> Tar du bort Dokploy försvinner **Dokploys Traefik**. Kör Arcane-apparna på
> `dokploy-network` måste du starta en egen Traefik på samma nätverk *innan* du
> river Dokploy, annars slutar alla domäner svara. Kolla att port 80/443 är
> lediga för den nya innan du startar.

## 8. Efter migreringen

* **Settings → Security** — MFA eller passkey. Arcane har fullt Docker-API.
* **Backups** — schemalägg volymbackuper, och lägg till ett S3-mål. En lokal
  snapshot på samma disk skyddar inte mot diskhaveri.
* **Notifications** — larm när en deploy misslyckas.
* **Vulnerability Scans** — Trivy mot dina images.
* **Fler värdar** — [`stacks/arcane-agent/`](../stacks/arcane-agent/).
* **Säkerhetskopiera** `stacks/arcane/.env` och `/volume1/docker/arcane/data`.
