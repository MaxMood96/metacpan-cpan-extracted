# WWW::Bund

**Perl CLI-Client und Bibliothek für deutsche Bundes-APIs** ([bund.dev](https://bund.dev))

[![CPAN Version](https://img.shields.io/cpan/v/WWW-Bund.svg)](https://metacpan.org/pod/WWW::Bund)
[![Tests](https://img.shields.io/badge/tests-290%20passing-success)](t/)
[![APIs](https://img.shields.io/badge/APIs-15%2F31-blue)](#api-roadmap)
[![Languages](https://img.shields.io/badge/languages-7-green)](#supported-languages)
[![POD](https://img.shields.io/badge/POD-100%25-success)](#)

---

## 🚗 Live-Beispiele

### Stauabfrage A3

```bash
$ bund autobahn roadworks A3
TITEL                                     UNTERTITEL                    GESPERRT
--------------------------------------------------------------------------------
A3 | Rottal-West - Neuhaus am Inn        Passau -> Linz                nein
A3 | Manzing - Isarblick                 Passau -> Nürnberg            nein
A3 | Nürnberg - Brunn                    Halle/Leipzig -> Nürnberg     nein
A3 | Neumarkt-Ost - Deusmauerer Moor     Nürnberg -> Passau            nein
A3 | Wolfstein - Neumarkt-Ost            Nürnberg -> Passau            nein
...
```

### 💧 Pegelstände

```bash
$ bund pegel stations
STATION                    GEWAESSER  KM
----------------------------------------------
CELLE                      ALLER      1.74
MARKLENDORF                ALLER      38.47
AHLDEN                     ALLER      58.71
RETHEM                     ALLER      82.32
EITZE                      ALLER      107.75
...
```

### 📰 Tagesschau-Nachrichten

```bash
$ bund tagesschau homepage
SCHLAGZEILE                     TITEL                                    DATUM
-----------------------------------------------------------------------------------------
US-Einschätzung zu Treibhausga  Trump kippt zentrale Vorgabe für Klim... 2026-02-13T04:46
Nach zehn Wochen                ICE-Einsatz in Minnesota wird beendet    2026-02-12T20:29
EU-Gipfel zu Lage der Wirtscha  Gemeinsamer Weg - aber auch gemeinsam.. 2026-02-12T20:36
Klöckner im Gazastreifen        Große Kritik nach kleinem Besuch         2026-02-12T14:04
...
```

### 🏛️ Bundestag Plenarkonferenzen

```bash
$ bund bundestag conferences
DATUM       NR  SITZUNG
-----------------------------------------------------
28.01.2026  55  55. Sitzung des Deutschen Bundestages
29.01.2026  56  56. Sitzung des Deutschen Bundestages
30.01.2026  57  57. Sitzung des Deutschen Bundestages
25.02.2026  58  58. Sitzung des Deutschen Bundestages
...
```

### 🌡️ DWD Wetterwarnungen

```bash
$ bund dwd municipality-warnings
WARNUNG                                   EREIGNIS            STUFE  BESCHREIBUNG
------------------------------------------------------------------------------------------------------
Amtliche WARNUNG vor STURMBÖEN            STURMBÖEN           3      Es treten oberhalb 800 m Sturm..
Amtliche WARNUNG vor SCHWEREN STURMBÖEN   SCHWERE STURMBÖEN   3      Es treten oberhalb 1000 m schw..
...
```

### 📅 Deutsche Feiertage 2026

```bash
$ bund feiertage list
---
NATIONAL:
  Neujahr:
    datum: 2026-01-01
  Karfreitag:
    datum: 2026-04-03
  Ostermontag:
    datum: 2026-04-06
  Tag der Arbeit:
    datum: 2026-05-01
  Christi Himmelfahrt:
    datum: 2026-05-14
  1. Weihnachtstag:
    datum: 2026-12-25
  2. Weihnachtstag:
    datum: 2026-12-26
```

### 🚨 NINA Katastrophenwarnungen

```bash
$ bund nina mapdata-katwarn
Keine Warnungen.

$ bund nina warnings 091620000000
# (Zeigt aktuelle Warnungen für Kreis mit AGS-Code 091620000000)
```

### ✈️ Reisewarnungen

```bash
$ bund travelwarning warnings
---
'199124':
  countryCode: PL
  countryName: Polen
  effective: 1768485600
  iso3CountryCode: POL
  title: 'Polen: Reise- und Sicherheitshinweise'
  warning: 0
'200382':
  countryCode: BE
  countryName: Belgien
  effective: 1764837900
  iso3CountryCode: BEL
  title: 'Belgien: Reise- und Sicherheitshinweise'
  warning: 0
...
```

### 🏛️ Bundesrat Mitglieder

```bash
$ bund bundesrat mitglieder renderXml
---
list:
  employee:
  - firstname: Winfried
    name: Kretschmann
    party: BÜNDNIS 90/DIE GRÜNEN
    state: Baden-Württemberg
    brmitglied: 'true'
  - firstname: Thomas
    name: Strobl
    party: CDU
    state: Baden-Württemberg
    brmitglied: 'true'
...
```

### 📊 Dashboard Deutschland

```bash
$ bund dashboarddeutschland get
NAME             BESCHREIBUNG
--------------------------------------------------------------
Arbeitsmarkt     Indikatoren zur Erwerbstätigkeit, Kurzarbeit...
Energie          Preisentwicklung verschiedener Energieträger...
Außenhandel      Aktuelle Veränderungen im Außenhandel...
Branchen         Entwicklungen aus Dienstleistungs- und Industrie...
...
```

### 🚴 Fahrrad-Zähler (Eco Visio)

```bash
$ bund -o json ecovisio counters 4586
[
   {
      "idPdc" : 100044994,
      "nom" : "Long Beach (US)",
      "nomOrganisme" : "Bike Count Display Interactive Map",
      "lat" : 33.75895,
      "lon" : -118.14846,
      ...
   }
]
```

### 💊 Hilfsmittel-Verzeichnis (GKV)

```bash
$ bund -o json hilfsmittel tree 1
[
   {
      "displayValue" : "01 - Absauggeräte",
      "xSteller" : "01",
      "id" : "835f127b-8355-4ac4-90f8-e3b7ff80ba80"
   },
   {
      "displayValue" : "02 - Adaptionshilfen",
      "xSteller" : "02",
      "id" : "339cc855-29fa-4f9e-b822-e024ed90637b"
   },
   ...
]
```

---

## 🌍 Supported Languages

**7 Sprachen mit vollständiger Übersetzung:**

🇩🇪 Deutsch • 🇬🇧 English • 🇫🇷 Français • 🇪🇸 Español • 🇮🇹 Italiano • 🇳🇱 Nederlands • 🇵🇱 Polski

**Dedizierte Befehle pro Sprache:**

```bash
bund   autobahn roads   # 🇩🇪 Deutsch (default)
bunden autobahn roads   # 🇬🇧 English
bundfr autobahn roads   # 🇫🇷 Français
bundes autobahn roads   # 🇪🇸 Español
bundit autobahn roads   # 🇮🇹 Italiano
bundnl autobahn roads   # 🇳🇱 Nederlands
bundpl autobahn roads   # 🇵🇱 Polski
```

**Oder mit --lang Flag:**

```bash
bund --lang en autobahn roads     # Englisch
bund --lang fr nina warnings 123  # Französisch
```

---

## 📦 Installation

```bash
cpanm WWW::Bund
```

Oder aus dem Repository:

```bash
git clone https://github.com/Getty/p5-www-bund.git
cd p5-www-bund
cpanm --installdeps .
perl -Ilib bin/bund
```

---

## 🚀 Quick Start

### Übersicht anzeigen

```bash
bund                    # Zeigt alle verfügbaren APIs
bund list               # Detaillierte API-Liste
bund info autobahn      # Details zu einer API
bund autobahn           # Verfügbare Befehle für autobahn
```

### API-Aufrufe

```bash
# Autobahn-API
bund autobahn roads                    # Alle Autobahnen
bund autobahn roadworks A3             # Baustellen auf der A3
bund autobahn warnings A7              # Warnungen auf der A7
bund autobahn webcams A9               # Webcams auf der A9

# Pegel-Online (Wasserstandsdaten)
bund pegel stations                    # Alle Messstationen
bund pegel station WUERZBURG           # Details für eine Station
bund pegel measurements WUERZBURG W    # Wasserstand-Messungen

# Tagesschau
bund tagesschau homepage               # Startseite
bund tagesschau search Ukraine         # Nachrichten suchen

# NINA (Katastrophenwarnungen)
bund nina warnings 091620000000        # Warnungen für Kreis (AGS-Code)
bund nina mapdata-katwarn              # KATWARN Kartendaten

# DWD (Deutscher Wetterdienst)
bund dwd municipality-warnings         # Gemeindewarnungen
bund dwd warnings-nowcast              # Nowcast-Warnungen

# Bundestag
bund bundestag conferences              # Plenarkonferenzen
bund bundestag mdb-index               # Abgeordnete

# Bundesrat
bund bundesrat startlist               # Startliste
bund bundesrat aktuelles               # Aktuelle Meldungen

# Feiertage
bund feiertage list                    # Alle Feiertage (aktuelles Jahr)

# SMARD (Strommarktdaten)
bund smard indices 1 DE hour           # Strommarkt-Indizes

# Reisewarnungen
bund travelwarning warnings            # Alle Reisewarnungen

# Dashboard Deutschland
bund dashboarddeutschland get          # Dashboard-Daten

# Weitere...
bund bundestaglobbyregister search     # Lobbyregister-Suche
bund ecovisio counters 4586            # Fahrrad-Zähler
bund hilfsmittel tree 1                # Hilfsmittel-Verzeichnis
```

---

## 🎨 Output-Formate

### Template-basiert (Standard)

Formatierte Tabellen, Listen und Records basierend auf YAML-Templates:

```bash
bund pegel stations
# STATION              GEWAESSER       GEWTYPE  LAT      LON
# WUERZBURG            Main            river    49.7994  9.9292
# BAMBERG              Regnitz         river    49.8901  10.8903
# ...
```

### JSON

```bash
bund -o json pegel stations
{
  "stations": [
    {
      "shortname": "WUERZBURG",
      "water": {"shortname": "Main", "type": "river"},
      ...
    }
  ]
}
```

### YAML

```bash
bund -o yaml pegel stations
---
stations:
  - shortname: WUERZBURG
    water:
      shortname: Main
      type: river
```

### Eigene Templates

```bash
bund -t mein_template.yml pegel stations
```

**Template-Beispiel** (`mein_template.yml`):

```yaml
type: table
columns:
  - field: shortname
    header: STATION
    width: 20
  - field: water.shortname
    header: GEWÄSSER
    width: 15
```

---

## 📊 API Roadmap

### ✅ Vollständig implementiert (15 APIs, 76 Endpoints)

| API | Endpoints | Beschreibung | Auth |
|-----|-----------|-------------|------|
| **autobahn** | 7 | Baustellen, Sperrungen, Webcams, Warnungen, Ladestationen, LKW-Parkplätze | ❌ |
| **pegel_online** | 5 | Pegelstände, Stationen, Gewässer, Zeitreihen, Messwerte | ❌ |
| **tagesschau** | 4 | Nachrichten, Suche, Kanäle, Homepage | ❌ |
| **nina** | 13 | Katastrophenwarnungen, Kartendaten (6 Quellen), Version, Logos, FAQs, Notfalltipps | ❌ |
| **bundestag** | 8 | Redner, Konferenzen, Ausschüsse, Abgeordnete, Artikel, Videos | ❌ |
| **dwd** | 5 | Wetterwarnungen (Gemeinde/Küste/Nowcast), Stationsdaten, Crowdmeldungen | ❌ |
| **feiertage** | 1 | Deutsche Feiertage nach Bundesland/Jahr | ❌ |
| **smard** | 3 | Strommarktdaten (Indizes, Zeitreihen, Tabellen) | ❌ |
| **bundeshaushalt** | 1 | Bundeshaushalt-Daten | ❌ |
| **bundesrat** | 10 | Startliste, Aktuelles, Termine, Plenum, Mitglieder, Präsidium | ❌ |
| **bundestag_lobbyregister** | 1 | Lobbyregister-Suche | ❌ |
| **dashboard_deutschland** | 3 | Dashboard-Daten, Indikatoren, GeoJSON | ❌ |
| **travelwarning** | 6 | Reisewarnungen, Vertretungen, Länder-Info, Gesundheit | ❌ |
| **eco_visio** | 2 | Fahrrad-Zähler, Zähldaten | ❌ |
| **hilfsmittel** | 7 | GKV Hilfsmittelverzeichnis (Baum, Produkte, Gruppen) | ❌ |

**Total: 76 Endpoints über 15 APIs**

### ⚠️ Deaktiviert (Auth erforderlich)

| API | Endpoints | Status | Grund |
|-----|-----------|--------|-------|
| **ladestationen** | 1 | Deaktiviert | ArcGIS FeatureServer benötigt Token (seit 2026) |

**Hinweis:** Das Ladesäulenregister der Bundesnetzagentur hat die öffentliche GeoJSON-Datei entfernt und auf einen authentifizierten ArcGIS FeatureServer umgestellt.

### 🔄 In Planung (Public, kein Auth erforderlich)

| API | Endpoints | Status | Priorität |
|-----|-----------|--------|-----------|
| **abfallnavi** | 10 | Geplant | Medium |
| **ddb** (Digitale Bibliothek) | 3 | Geplant | Medium |
| **destatis** | 4 | Geplant | High |
| **deutschlandatlas** | 1 | Geplant | Medium |
| **handelsregister** | 1 | Geplant | Low |
| **luftqualitaet** | 13 | Geplant | High |
| **marktstammdaten** | 8 | Geplant | Medium |
| **mudab** (Meeresumwelt) | 11 | Geplant | Low |
| **pflanzenschutzmittelzulassung** | 6 | Geplant | Low |
| **regionalatlas** | 1 | Geplant | Medium |

### 🔐 Authentifizierung erforderlich (nicht geplant)

Diese APIs benötigen API-Keys und sind daher für den öffentlichen CLI-Client nicht vorgesehen:

- **ausbildungssuche** (BA API-Key)
- **bewerberboerse** (BA API-Key)
- **jobsuche** (BA API-Key)
- **lebensmittelwarnung** (API-Key)
- **dip_bundestag** (API-Key)

---

## 🗂️ Cache

API-Antworten werden automatisch gecacht:

```
$XDG_CACHE_HOME/www-bund/responses/
# Fallback: ~/.cache/www-bund/responses/
```

**Cache-TTLs** (automatisch pro Endpoint):

| TTL | Typ | Beispiele |
|-----|-----|-----------|
| **120s** | Notfälle | NINA-Warnungen, DWD-Wetterwarnungen, Autobahn-Warnungen |
| **300s** | Echtzeit | Tagesschau, Pegel-Messwerte, Baustellen, Bundesrat Aktuelles |
| **1800s** | Moderat | Webcams, Suche, Strommarkt-Zeitreihen, Reisewarnungen |
| **86400s** | Statisch | Straßenlisten, Stationslisten, Feiertage, Metadaten |

Cache löschen:

```bash
rm -rf ~/.cache/www-bund/
```

Oder programmatisch:

```perl
use WWW::Bund;
WWW::Bund->new->cache->clear;
```

---

## 🏗️ Architektur

### CLI (MooX::Cmd + MooX::Options)

```
bin/bund                              Deutsch (via ENV)
bin/bunden                            Englisch (via ENV)

lib/WWW/Bund/CLI.pm                   Root CLI (globale Options, Helper)
lib/WWW/Bund/CLI/Role/APICommand.pm   Shared Role für API-Commands
lib/WWW/Bund/CLI/Cmd/*.pm             18 API-Command-Klassen (~10 LOC each)
lib/WWW/Bund/CLI/Cmd/{List,Info}.pm   Meta-Commands
lib/WWW/Bund/CLI/Formatter.pm         Template-Rendering
lib/WWW/Bund/CLI/Strings.pm           i18n Strings
```

### Core Library

```
lib/WWW/Bund.pm                       Haupt-Client
lib/WWW/Bund/Registry.pm              API- und Endpoint-Registry
lib/WWW/Bund/Caller.pm                HTTP-Aufrufe mit Auth/Cache/RateLimit
lib/WWW/Bund/Cache.pm                 Disk-Cache (XDG-konform)
lib/WWW/Bund/Auth.pm                  Auth-Header pro API
lib/WWW/Bund/RateLimit.pm             Rate-Limiting pro API
lib/WWW/Bund/LWPIO.pm                 LWP-basierter IO-Adapter
lib/WWW/Bund/HTTPRequest.pm           Request-Objekt
lib/WWW/Bund/HTTPResponse.pm          Response-Objekt
lib/WWW/Bund/Response::{JSON,XML,Raw}.pm  Response-Parser
lib/WWW/Bund/API/*.pm                 Typed API-Adapter (optional)
```

### Data Files

```
share/registry.yml                    31 API-Definitionen
share/endpoints.yml                   77 Endpoint-Definitionen (76 aktiv, 1 deaktiviert)
share/templates/{de,en,fr,es,it,nl,pl}/*.yml  665 Templates (95 × 7 Sprachen)
share/strings/{de,en,fr,es,it,nl,pl}.yml      7 Strings-Dateien
```

---

## 🌐 Neue Sprache hinzufügen

1. **Strings-Datei erstellen:**

```bash
cp share/strings/en.yml share/strings/xx.yml
# Alle Werte übersetzen (Keys NICHT ändern)
```

2. **Template-Ordner erstellen:**

```bash
mkdir share/templates/xx
cp share/templates/en/* share/templates/xx/
# Nur `header:` und `empty:` Felder übersetzen
```

3. **Verwenden:**

```bash
bund --lang xx autobahn roads
```

---

## 🪟 Windows EXE

Standalone `.exe` ohne Perl-Installation via [PAR::Packer](https://metacpan.org/pod/PAR::Packer):

```bash
# Mit Strawberry Perl
pp -x -M LWP::Protocol::https -M Moo -a "share/;share/" -o bund.exe bin/bund
```

**Wichtig:**
- XS-Module (YAML::XS, JSON::XS) explizit einbinden
- SSL-Zertifikate (Mozilla::CA) mitliefern
- Auf sauberem Windows-System testen

Alternative: Strawberry Perl Portable als ZIP.

---

## 📚 Dokumentation

Alle 42 Module haben vollständige POD-Dokumentation:

```bash
perldoc WWW::Bund                    # Hauptmodul
perldoc WWW::Bund::CLI               # CLI-Dokumentation
perldoc WWW::Bund::API::Autobahn     # API-Adapter
perldoc bund                         # Bin-Command
```

**POD-Features:**
- SYNOPSIS mit Verwendungsbeispielen für jedes Modul
- Vollständige Beschreibung aller Attribute (=attr)
- Dokumentation aller Methoden (=method)
- Cross-References zwischen verwandten Modulen
- Inline-POD für automatische PodWeaver-Generierung

**Umfang:**
- 42 Module mit POD
- 2,112 Zeilen Dokumentation
- 7 Bin-Scripts mit vollständigem POD

---

## 🧪 Tests

```bash
prove -l t/                        # Alle Tests (290)
prove -l t/00-load.t               # Module loading
prove -l t/cli.t                   # CLI-Funktionalität
WWW_BUND_LIVE_TEST=1 prove -l t/integration.t  # Live-API-Tests
```

---

## 📝 Lizenz

Dieses Modul ist freie Software. Es kann unter denselben Bedingungen wie Perl
selbst weiterverbreitet und/oder modifiziert werden.

---

## 👥 Autor

**Torsten Raudssus** (GETTY) <torsten@raudss.us>

---

## 🔗 Links

- [bund.dev](https://bund.dev) - Offizielle API-Registry
- [GitHub](https://github.com/Getty/p5-www-bund)
- [MetaCPAN](https://metacpan.org/pod/WWW::Bund)
- [Issues](https://github.com/Getty/p5-www-bund/issues)
