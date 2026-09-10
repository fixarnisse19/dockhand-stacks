# Mallar

Katalogstrukturen här (`<namn>/compose.yaml` + `<namn>/.env.example`) är exakt
det format Arcane läser som **lokala templates**. Kopiera in dem så dyker de upp
under *Customization → Templates* och kan skapa nya projekt med ett klick:

```bash
cp -r /volume1/docker/arcane/repo/templates/* /volume1/docker/arcane/data/templates/
```

Arcane bevakar katalogen och plockar upp ändringar direkt.

Utöver de lokala finns community-registret
`https://registry.getarcane.app/registry.json` inbyggt, med färdiga stackar för
de vanligaste apparna.

## `app-with-traefik/`

Den mall du utgår från när du flyttar en app från Dokploy: routing, TLS,
healthcheck och miljövariabler i klartext i stället för i Dokploys formulär.
Se [migreringsguiden](../docs/migrera-fran-dokploy.md).
