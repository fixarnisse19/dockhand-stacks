# Xia Fix Sol — Masterdokument

**Tilläggstjänst i Xia Fix-plattformen riktad till företag inom solpaneler**

| | |
|---|---|
| **Version** | 0.1 (utkast) |
| **Datum** | 2026-08-26 |
| **Status** | Underlag för beslut — se §13 Öppna frågor |
| **Ägare** | Plattformsägare, Xia Fix |
| **Arbetsnamn** | Xia Fix Sol (alt. "SolKoll", "Takkoll") — namnbeslut kvarstår |

---

## 1. Sammanfattning

Xia Fix Sol är en **tilläggstjänst ovanpå Xia Fix-plattformen** som automatiskt räknar ut
en fastighets solcellspotential utifrån kartdata — takyta i kvadratmeter, väderstreck,
lutning, skuggning och solinstrålning — och omvandlar det till ett **färdigt offertunderlag**
som fastighetsägaren skickar direkt till ett solcellsbolag.

**Kärnidén i en mening:** solcellsbolagen ska slippa lägga säljtid på att manuellt räkna ut
tak, produktion och grovpris för varje förfrågan — Xia Fix Sol gör grovjobbet automatiskt och
levererar en förkvalificerad lead där kunden redan vet ungefär vad hen vill ha och vad det
ungefär kostar.

**Precisionslöftet:** uppskattningen är avsiktligt en **uppskattning, inte en projektering**.
Vi siktar på att träffa rätt inom cirka **±30 %** — det vill säga ungefär **70 % träffsäkerhet**
mot en fysisk takbesiktning. Det är tillräckligt bra för att sortera bort dåliga leads och
starta en säljdialog, och det ska kommuniceras tydligt i varje utdata (se §7).

---

## 2. Problemet vi löser

### 2.1 För solcellsbolaget

| Problem idag | Konsekvens |
|---|---|
| Varje förfrågan kräver manuell handpåläggning: slå upp adressen, mäta taket i kartverktyg, gissa lutning och väderstreck | 20–60 min säljtid per förfrågan, innan man ens vet om kunden är seriös |
| Många förfrågningar är okvalificerade — fel tak, för litet, för skuggat, hyresrätt, bostadsrätt utan rådighet | Hög andel bortkastad tid; låg offert-till-affär-konvertering |
| Leads köps ofta styckvis från leadbolag utan underlag | Dyra leads, ofta sålda till 3–5 konkurrenter samtidigt |
| Kunden vet inte vad hen frågar efter | Lång dialog innan man ens kan lämna ett riktpris |

### 2.2 För fastighetsägaren

- Vet inte om taket ens lämpar sig för solceller.
- Vet inte hur många kvadratmeter som är användbara.
- Vet inte om det handlar om 60 000 kr eller 250 000 kr.
- Orkar inte fylla i fem olika formulär hos fem olika bolag.

### 2.3 Vad Xia Fix Sol gör åt det

Ett automatiskt räknat underlag som **båda parter** kan utgå ifrån redan i första kontakten.
Fastighetsägaren trycker på en knapp och skickar i praktiken:

> "Hej! Jag har ett tak på ca **68 m² användbar yta** i **sydvästligt läge**, lutning ca **27°**,
> begränsad skuggning. Uppskattad anläggning ca **11 kWp**, ca **9 900 kWh/år**.
> Grovt prisspann **145 000–185 000 kr** före grönt avdrag.
> **Kan ni lämna offert?**"

Solcellsbolaget får alltså en lead som redan är mätt, räknad och prissatt i grova drag.

---

## 3. Tjänsten i korthet

**Xia Fix Sol** består av fyra delar:

1. **Takanalysen** — adress in, takgeometri och användbar yta ut (§6.1–6.2).
2. **Produktionskalkylen** — yta + läge + instrålning → kWp och kWh/år (§6.3–6.4).
3. **Grovkalkylen** — kWh/år + prismodell → prisspann och återbetalningstid (§6.5).
4. **Offertförfrågan** — paketerat underlag som skickas till ett eller flera anslutna bolag (§8).

Tjänsten är en **modul inom Xia Fix**, inte en fristående produkt. Den delar inloggning,
företagsprofiler, meddelandeflöde och fakturering med resten av plattformen (§10).

---

## 4. Flöde — fastighetsägaren

```
1. Anger adress (eller pekar ut sin byggnad på kartan)
        ↓
2. Ser sitt tak markerat — kan justera vilka takfall som ska räknas
        ↓
3. Får resultat på 5–15 sekunder:
   • Användbar takyta (m²)  • Väderstreck & lutning  • Skuggindikation
   • Uppskattad anläggning (kWp)  • Uppskattad produktion (kWh/år)
   • Grovt prisspann  • Grovt återbetalningsspann
        ↓
4. Kompletterar med 3–5 frågor:
   • Ungefärlig elförbrukning per år?  • Takmaterial?  • Elbil/laddbox?
   • Batteri av intresse?  • Ägandeform (villa/lantbruk/kommersiell)?
        ↓
5. Trycker "Begär offert" → underlaget går till valda bolag i området
        ↓
6. Får svar i Xia Fix-inkorgen — inte via telefonspam
```

**Designprincip:** steg 1–3 ska gå att göra **utan inloggning**. Först vid steg 5 krävs konto.
Det maximerar toppen av tratten och gör verktyget delbart.

## 5. Flöde — solcellsbolaget

```
1. Registrerar företagsprofil i Xia Fix
   • Verksamhetsområde (kommuner/postnummer)  • Kapacitet (leads/vecka)
   • Vad man tar: villa / lantbruk / kommersiell / BRF  • Min. anläggningsstorlek
        ↓
2. Får notis när en matchande förfrågan kommer in
        ↓
3. Ser hela underlaget: takbild, ytor, väderstreck, produktion, kundens förbrukning
        ↓
4. Accepterar eller avböjer leaden (avböjd lead ska inte debiteras)
        ↓
5. Svarar kunden i plattformen — kan justera siffrorna och lämna riktig offert
        ↓
6. Markerar utfall: offert lämnad / affär / förlorad
```

Steg 6 är avgörande: **utfallsdatan är det som gör modellen bättre över tid** (§6.7).

---

## 6. Teknisk lösning

### 6.1 Identifiera byggnaden

| Källa | Vad den ger | Kommentar |
|---|---|---|
| Lantmäteriet — Fastighetskartan / Byggnad | Byggnadsfotavtryck som polygon | Nationell täckning, öppna data |
| Lantmäteriet — Laserdata NH / Laserdata Skog | 3D-punktmoln, ger takfall, lutning, nockriktning | Bästa källan för takgeometri i Sverige |
| Google Solar API (Building Insights) | Färdiga taksegment med lutning, azimut och årlig instrålning | Snabbast att komma igång med; varierande täckning i Sverige — **måste täckningstestas per kommun** |
| OpenStreetMap | Byggnadsfotavtryck | Fallback där annat saknas; ojämn kvalitet |
| Kommunala ortofoton / snedbilder | Visuell kontroll, takmaterial | Bra för presentationsbilden |

**Rekommenderad arkitektur:** en `RoofDataProvider`-abstraktion med flera implementationer och
en tydlig fallback-kedja, så att vi inte låser oss till en leverantör:

```
GoogleSolarProvider  →  (om otillräcklig täckning/konfidens)
LidarProvider (Lantmäteriet laserdata)  →  (om saknas)
FootprintProvider (fotavtryck + antaganden om lutning/riktning)  →  (annars)
ManualProvider (användaren ritar själv)
```

Varje provider returnerar samma struktur **plus en konfidensnivå**, som styr hur brett
prisspann vi visar (§7.2).

### 6.2 Räkna fram användbar takyta

Fotavtryck är inte takyta, och takyta är inte användbar takyta.

```
A_fotavtryck        = byggnadens area i m² (platt, från kartan)
A_takfall           = A_fotavtryck / cos(lutning)
A_användbar         = A_takfall × f_segment × f_hinder × f_kant
```

| Faktor | Typiskt värde | Vad den fångar |
|---|---|---|
| `f_segment` | 0,40–0,60 | Andel av taket med tillräckligt bra väderstreck (öst→syd→väst) |
| `f_hinder` | 0,80–0,90 | Skorsten, takfönster, ventilation, stegar, takkupor |
| `f_kant` | 0,90–0,95 | Marginal mot takfot, nock och gavel (montage- och brandkrav) |

**Tumregel för sanity check:** en normalvilla i Sverige landar oftast på **35–80 m² användbar yta**.
Faller resultatet utanför det spannet för en villa ska systemet flagga för manuell kontroll.

### 6.3 Från yta till anläggningsstorlek

```
Panelarea      ≈ 1,7–2,0 m² per panel
Paneleffekt    ≈ 400–450 W per panel
⇒ Ytbehov      ≈ 4,5–5,5 m² per kWp

kWp ≈ A_användbar / 5,0
```

### 6.4 Från anläggningsstorlek till produktion

```
Produktion (kWh/år) = kWp × PR × H_i
```

- `H_i` = solinstrålning mot den aktuella takytan (kWh/m²/år, i "sol-timmar-ekvivalent")
- `PR` = performance ratio, systemets verkningsgrad — typiskt **0,80–0,85** i svenskt klimat
  (växelriktarförluster, kablage, temperatur, smuts, snö)

**Instrålningskällor:**

| Källa | Användning |
|---|---|
| PVGIS (EU JRC) | Öppet API, `PVcalc`-endpoint tar lutning + azimut och returnerar kWh/år. Bra huvudkälla. |
| SMHI STRÅNG | Svensk instrålningsmodell, bra för validering och regionala korrigeringar |
| Google Solar API — Data Layers | Instrålning per rutnätscell inkl. skuggning från omgivning |

**Grov svensk referens (fast, optimalt söderläge):**

| Region | Ca specifik produktion |
|---|---|
| Skåne / Gotland / Öland | ~1 000–1 100 kWh per kWp och år |
| Mälardalen / Göta | ~950–1 050 kWh per kWp och år |
| Norrland (kust) | ~850–950 kWh per kWp och år |

Riktningskorrigering mot optimalt söderläge, som grov faktor:

| Väderstreck | Faktor |
|---|---|
| Syd | 1,00 |
| Sydöst / sydväst | 0,95 |
| Öst / väst | 0,80–0,85 |
| Nordöst / nordväst | 0,60–0,70 |
| Nord | ej lönsamt — flaggas som "räknas ej" |

> ⚠️ **Alla sifferintervall i §6.3–6.4 ska kalibreras mot verkliga anläggningar innan lansering.**
> De är rimliga branschtumregler, inte verifierade konstanter. Se §6.7.

### 6.5 Från produktion till prisspann

Grovkalkylen ska vara ett **spann**, aldrig ett exakt pris.

```
Pris ≈ kWp × pris_per_kWp   där pris_per_kWp är ett intervall
```

Prisintervallet per kWp är den enskilt viktigaste parametern att hålla uppdaterad — den
förändras med panelpriser, växelkurs och arbetsmarknad. Den ska:

- lagras som **konfigurerbar parameter i databasen**, inte hårdkodas,
- kunna sättas **per region och per anläggningsstorlek** (större anläggning = lägre kr/kWp),
- kunna **överstyras av anslutna bolag** för deras egna leads,
- versionshanteras med datumstämpel så att gamla kalkyler kan reproduceras.

**Ska också redovisas i kalkylen:**

- **Grönt avdrag för solceller** — skattereduktion på arbete och material.
  ⚠️ Nivån ändras politiskt. Ska hämtas från konfiguration, aldrig hårdkodas, och märkas med
  "gäller per [datum] — verifiera aktuell nivå hos Skatteverket".
- **Värdet av producerad el** — måste delas i egenanvänd el (sparar hela elpriset inkl. nät,
  skatt och moms) och såld överskottsel (spotpris + ev. nätnytta + skattereduktion för
  mikroproduktion). Detta är den vanligaste källan till orealistiska återbetalningskalkyler
  i branschen — vi ska vara försiktigare än branschsnittet, inte mer optimistiska.
- **Återbetalningstid** som spann, med tydlig uppgift om vilket elpris som antagits.

### 6.6 Beräkningskedjan i sin helhet

```
Adress
  → Geokodning
  → Byggnadspolygon
  → Takgeometri (segment: area, lutning, azimut)
  → Skuggmodell
  → Användbar yta per segment
  → Summerad kWp
  → PVGIS/STRÅNG-instrålning per segment
  → Produktion kWh/år (med PR)
  → Prisspann + avdrag + återbetalning
  → Offertunderlag (§8)
```

Varje steg ska logga **indata, utdata och konfidens** så att ett resultat kan felsökas i
efterhand när ett bolag säger "det där taket var ju 20 m² mindre".

### 6.7 Kalibrering — hur vi når och behåller 70 %

Modellen är värdelös om vi inte mäter hur fel den har. Därför:

1. **Utfallsloggning.** Varje gång ett bolag lämnar en riktig offert registreras deras
   faktiska siffror (verklig yta, verklig kWp, verkligt pris) mot vår uppskattning.
2. **Avvikelserapport.** Löpande mätning av median- och 90:e-percentilavvikelse per
   parameter (yta, kWp, produktion, pris) och per datakälla.
3. **Justering av faktorer.** `f_segment`, `f_hinder`, `PR` och prisintervall justeras utifrån
   utfallsdatan, per region.
4. **Publicerad träffsäkerhet.** När vi har tillräckligt underlag ska vi kunna säga
   "8 av 10 uppskattningar hamnar inom 30 % av verklig anläggning" — och kunna belägga det.

**Minsta acceptabla nivå innan skarp lansering mot företag:** dokumenterad avvikelse på
minst 30 verifierade tak. Innan dess ska tjänsten märkas som beta.

---

## 7. 70-procentsprincipen — vad vi lovar och inte lovar

Detta är dokumentets viktigaste avsnitt. Hela affären står och faller med att förväntan är rätt.

### 7.1 Formuleringen

**Vi lovar:** en *uppskattning* som ger rätt storleksordning och underlag för en säljdialog.

**Vi lovar inte:** en projektering, en dimensionering, en garanterad produktion eller ett bindande pris.

Standardformulering som ska följa med varje utdata — i appen, i PDF:en och i mejlet till bolaget:

> **Detta är en automatisk uppskattning baserad på kartdata, inte en besiktning.**
> Verklig takyta, bärighet, takmaterial, elcentralens skick och skuggförhållanden kan avvika.
> Siffrorna är avsedda som utgångspunkt för en offert — inte som ett bindande pris.
> Uppskattningen träffar erfarenhetsmässigt inom ca ±30 % av en projekterad anläggning.

### 7.2 Konfidensnivåer

Systemet ska inte visa samma säkerhet för alla tak. Tre nivåer:

| Nivå | Kriterium | Presentation |
|---|---|---|
| **Hög** | LiDAR/Solar API med taksegment, tydlig geometri, låg skuggning | Smalt spann, "Bra underlag" |
| **Medel** | Fotavtryck + antagen lutning, eller delvis skuggning | Bredare spann, "Ungefärligt" |
| **Låg** | Endast fotavtryck, komplex takform, hög skuggning, flerbostadshus | Mycket brett spann + "Kräver platsbesök" |

Vid låg konfidens ska tjänsten hellre säga "vi kan inte räkna ut det här tillförlitligt —
begär ändå offert?" än att gissa. **Ett dåligt underlag skadar förtroendet hos företagen mer
än ett uteblivet underlag.**

### 7.3 Ansvarsbegränsning

Villkoren måste slå fast att Xia Fix tillhandahåller ett *beräkningsunderlag*, inte en
teknisk konsulttjänst, och inte ansvarar för att en anläggning dimensioneras efter våra
siffror. Ska granskas juridiskt före lansering (§11).

---

## 8. Offertunderlaget

Det här är produkten som solcellsbolaget faktiskt betalar för. Den ska innehålla:

**Fastigheten**
- Adress, kommun, fastighetsbeteckning (om tillgänglig), koordinater
- Byggnadstyp och ägandeform
- Takbild med markerade segment

**Taket**
- Användbar yta per segment (m²), totalt
- Lutning och väderstreck per segment
- Takmaterial (från kunden)
- Skuggindikation
- Byggnadens uppskattade ålder om känd (relevant för bärighet)

**Anläggningen**
- Uppskattad storlek (kWp) och panelantal
- Uppskattad produktion (kWh/år), fördelat på segment
- Konfidensnivå

**Kunden**
- Årlig elförbrukning (kWh)
- Elområde (SE1–SE4) och nuvarande elavtalsform
- Intresse för batteri / laddbox
- Tidshorisont ("snarast" / "inom 6 mån" / "orienterar mig")
- Kontaktväg och önskad kontakttid

**Kalkylen**
- Prisspann, antaget kr/kWp, antaget elpris
- Avdrag som antagits, med datumstämpel
- Återbetalningsspann

**Metadata**
- Datakällor som använts
- Beräkningsversion (för spårbarhet)
- Ansvarsfriskrivningen enligt §7.1

Levereras som **strukturerad data i plattformen + en PDF** som säljaren kan ta med till kunden.

---

## 9. Affärsmodell

Fyra möjliga intäktsströmmar. Rekommendationen är att börja med **A** och lägga till **B**.

| # | Modell | Beskrivning | För | Emot |
|---|---|---|---|---|
| **A** | **Pris per accepterad lead** | Bolaget betalar först när det accepterar en lead med fullständigt underlag | Enkelt att sälja in, tydligt värde, ingen risk för köparen | Kräver volym; risk för tvist om leadkvalitet |
| **B** | **Abonnemang** | Månadsavgift för tillgång till området + X leads inkluderade | Förutsägbar intäkt, binder bolaget | Svårare första sälj |
| **C** | **Provision på avslut** | % av affärsvärdet | Högst potentiell intäkt | Kräver insyn i bolagets affärer; svårt att verifiera; risk för underrapportering |
| **D** | **White label** | Bolaget lägger kalkylatorn på sin egen sajt | Hög marginal, stärker Xia Fix som infrastruktur | Kannibaliserar leadaffären |

### 9.1 Principer oavsett modell

- **Exklusivitet är en produkt.** En lead som går till ett bolag är värd betydligt mer än en
  som går till fem. Erbjud båda, prissatt olika.
- **Avböjd lead debiteras aldrig.** Bolaget ska kunna tacka nej inom X timmar utan kostnad.
  Det är den enskilt viktigaste förtroendemekanismen mot branschen.
- **Kvalitetsgaranti.** Uppenbart felaktiga leads (fel byggnad, kunden äger inte fastigheten,
  taket finns inte) krediteras automatiskt vid reklamation.
- **Prisdifferentiering på anläggningsstorlek.** En lead på 40 kWp lantbrukstak är värd
  mångdubbelt mer än en på 6 kWp villatak. Prissätt därefter.

### 9.2 Enhetsekonomi — modell att fylla i

Detta är strukturen, inte siffrorna. Siffrorna sätts när vi har verkliga data.

```
Intäkt per lead                          =  P
Andel leads som accepteras               =  a
Andel accepterade som blir offert        =  o
Andel offerter som blir affär            =  c
⇒ Bolagets kostnad per vunnen affär      =  P / (o × c)

Detta tal måste vara tydligt lägre än bolagets nuvarande
kundanskaffningskostnad — annars finns ingen affär.
```

**Åtgärd:** ta reda på vad solcellsbolag i dag betalar per lead hos befintliga leadbolag och
vad deras konvertering är. Det är referenspunkten hela prissättningen ska hänga på (§13).

---

## 10. Integration i Xia Fix

Xia Fix Sol ska vara en **modul**, inte en parallell produkt.

**Delas med plattformen:**
- Konton, inloggning och roller (privatperson / företag / admin)
- Företagsprofiler och verifiering av företag (org.nr, F-skatt, behörigheter)
- Meddelandeflödet mellan kund och företag
- Fakturering och betalning
- Notiser (e-post/push)
- Omdömen och betyg

**Specifikt för solmodulen:**
- Kartvyn och takväljaren
- Beräkningsmotorn (§6)
- Solspecifika företagsattribut (installatörsbehörighet, elbehörighet, kapacitet i kWp/månad)
- Offertunderlaget och PDF-genereringen
- Kalibreringsdatan

**Arkitekturprincip:** beräkningsmotorn byggs som en **fristående tjänst med tydligt API**
(`POST /estimate` → offertunderlag). Då kan samma motor senare driva white label (modell D)
och en publik kalkylator utan att plattformen byggs om.

**Generaliserbarhet:** samma mönster — "räkna ut något från kartdata, paketera som
offertunderlag, matcha mot företag" — går att återanvända för fler branscher: takläggning,
fasadmålning, tomt- och markarbeten, laddstolpar. Solmodulen ska därför byggas som den
**första instansen av ett mönster**, inte som en engångslösning.

---

## 11. Juridik, data och etik

| Område | Vad som gäller / måste utredas |
|---|---|
| **GDPR** | Adress + fastighet + elförbrukning kopplat till person = personuppgifter. Krävs: rättslig grund (samtycke/avtal), personuppgiftsbiträdesavtal med anslutna bolag, gallringsrutin, registerutdrag och radering. |
| **Vidarelämning av kontaktuppgifter** | Kunden måste aktivt välja vilka bolag som får uppgifterna. Ingen automatisk spridning. |
| **Marknadsföringslagen** | Anslutna bolag får inte kallringa kunder som inte begärt kontakt. Ska regleras i anslutningsavtalet med sanktion. |
| **Datakällornas licenser** | Lantmäteriets öppna data, PVGIS och Google Solar API har olika villkor för kommersiell användning och vidaredistribution. **Måste läsas igenom innan lansering** — särskilt om vi visar kartbilder i en PDF som bolaget skickar vidare. |
| **Ansvarsfriskrivning** | Se §7.3. |
| **Vilseledande kalkyler** | Återbetalningstider ska inte räknas på högsta tänkbara elpris. Konsumentverket granskar solcellsbranschens marknadsföring. Var konservativ. |
| **Företagsverifiering** | Anslutna bolag ska kontrolleras: org.nr, F-skatt, ansvarsförsäkring, behörig elinstallatör. Detta är en förtroendeprodukt — ett oseriöst bolag i nätverket skadar hela plattformen. |

---

## 12. Roadmap

### Fas 0 — Validering (före kodning)
- Prata med **5–10 solcellsbolag**. Fråga specifikt: vad betalar ni per lead idag, vad är er
  konvertering, och skulle ni betala mer för en lead med färdigt takunderlag?
- Testa täckningen: kör 20 kända adresser mot Google Solar API och mot Lantmäteriets laserdata.
  Jämför mot manuell mätning. **Detta avgör vilken datakälla som blir huvudspår.**
- Verifiera dagens nivå på grönt avdrag och regler för mikroproduktion.

### Fas 1 — MVP
- Adress → byggnad → takyta → kWp → kWh/år → prisspann
- En datakälla + manuell fallback
- Webbvy, ingen inloggning för själva kalkylen
- Enkelt "begär offert"-formulär som mejlas till ett fåtal handplockade partnerbolag
- **Mål:** bevisa att både kund och bolag tycker underlaget är värt något

### Fas 2 — Produkt
- Företagsportal: profil, område, kapacitet, acceptera/avböj lead
- Betalning per accepterad lead
- PDF-underlag
- Konfidensnivåer och multi-provider-fallback
- Utfalls- och kalibreringsloggning (§6.7)

### Fas 3 — Skala
- Batteri- och laddboxdimensionering
- Kommersiella tak och lantbruk (stora ytor, bättre marginal per lead)
- White label / API till bolagens egna sajter
- Publicerad, belagd träffsäkerhet
- Mönstret återanvänt för nästa bransch (§10)

---

## 13. Öppna frågor — beslut som behövs

Dessa behöver besvaras innan Fas 1 kan låsas:

1. **Namn.** Xia Fix Sol, SolKoll, Takkoll — eller något annat?
2. **Vad heter plattformen exakt** och hur stavas den i skrift? ("Xia Fix" används här.)
3. **Marknad.** Hela Sverige direkt, eller start i en region där vi vet att kartdatan är bra?
4. **Kundsegment i Fas 1.** Villa (volym, låg intäkt per lead) eller lantbruk/kommersiellt
   (låg volym, hög intäkt per lead)? Rekommendation: **börja med villa för volymen på
   kalkylatorn, men prissätt lantbruk/kommersiellt högre från dag ett.**
5. **Affärsmodell.** Bekräfta A (per lead) som start, med B (abonnemang) som uppsäljning.
6. **Prisnivå.** Kräver svaret från Fas 0-samtalen.
7. **Exklusiva leads?** En köpare per lead, eller flera?
8. **Datakälla.** Beslutas efter täckningstestet i Fas 0.
9. **Finns tidigare Xia Fix-material** (specifikationer, kod, designer) som detta ska läggas
   ihop med? Repot innehåller i dagsläget bara en README — det du skrev tidigare idag finns
   inte här. Skicka in det så vävs det ihop med detta dokument.

---

## 14. Ordlista

| Term | Betydelse |
|---|---|
| **kWp** | Kilowatt peak — anläggningens märkeffekt under standardförhållanden |
| **kWh/år** | Faktisk producerad energi per år |
| **PR** | Performance ratio — hur stor andel av teoretisk produktion som faktiskt levereras |
| **Azimut** | Takets väderstreck i grader (180° = rakt söderut) |
| **Instrålning** | Solenergi mot en yta, kWh/m² och år |
| **LiDAR** | Laserskanning från flyg — ger 3D-punktmoln av tak och terräng |
| **Fotavtryck** | Byggnadens yta sedd rakt uppifrån, utan hänsyn till taklutning |
| **Egenanvändning** | Andel av producerad el som används i huset istället för att säljas |
| **Mikroproduktion** | Småskalig elproduktion som matas ut på nätet, med särskilda skatteregler |
| **Lead** | Kvalificerad kundförfrågan som säljs eller förmedlas till ett företag |

---

*Detta är ett utkast avsett som utgångspunkt för beslut. Alla siffervärden är branschtumregler
som ska kalibreras mot verkliga anläggningar innan de används skarpt — se §6.7 och §13.*
