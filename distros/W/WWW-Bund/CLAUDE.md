# CLAUDE.md - WWW::Bund

## Projekt-Übersicht

**WWW::Bund** ist ein umfassender CLI-Client und Perl-Bibliothek für deutsche Bundes-APIs (bund.dev).

- **Moo**-basiert (kein Moose)
- **Dist::Zilla** mit `[@Author::GETTY]` Bundle
- **16 öffentliche APIs** mit 78 Endpoints implementiert
- **7 Sprachen** vollständig unterstützt (DE, EN, FR, ES, IT, NL, PL)
- **497 YAML-Templates** für formatierte Ausgabe
- **290 Tests** - alle bestehend

## Quick Commands

```bash
# Tests
prove -l t/                        # Alle Tests
prove -l t/00-load.t               # Module-Loading (42 Module)
prove -l t/cli.t                   # CLI-Funktionalität
WWW_BUND_LIVE_TEST=1 prove -l t/integration.t  # Live-API-Tests

# CLI-Entwicklung
perl -Ilib bin/bund autobahn roads # Live-Test
perl -Ilib bin/bund list            # API-Liste
perl -Ilib bin/bund info autobahn   # API-Details

# Build & Release
dzil build                          # Distribution bauen
dzil test                           # Tests laufen lassen
dzil release                        # Zu CPAN releasen
```

## Architektur

### Dateistruktur

```
bin/
  bund                              # CLI (Deutsch default, ENV WWW_BUND_LANG=de)
  bunden                            # CLI (Englisch default, ENV WWW_BUND_LANG=en)
  bundfr                            # CLI (Französisch default, ENV WWW_BUND_LANG=fr)
  bundes                            # CLI (Spanisch default, ENV WWW_BUND_LANG=es)
  bundit                            # CLI (Italienisch default, ENV WWW_BUND_LANG=it)
  bundnl                            # CLI (Niederländisch default, ENV WWW_BUND_LANG=nl)
  bundpl                            # CLI (Polnisch default, ENV WWW_BUND_LANG=pl)

lib/WWW/Bund.pm                     # Haupt-Client, baut alle Komponenten zusammen

lib/WWW/Bund/CLI.pm                 # Root-CLI (MooX::Cmd + MooX::Options)
                                    # - Globale Options: --output, --lang, --template
                                    # - Helper-Methoden: _s, _resolve_api, etc.
                                    # - cmd_* Methoden: cmd_list, cmd_info, cmd_call

lib/WWW/Bund/CLI/Role/APICommand.pm # Shared Role für API-Dispatch
                                    # - requires 'api_id'
                                    # - execute() dispatcht via $chain->[0]->cmd_call()

lib/WWW/Bund/CLI/Cmd/
  List.pm                           # bund list
  Info.pm                           # bund info <api>
  Autobahn.pm                       # bund autobahn <action>
  Pegel.pm                          # bund pegel <action> (api_id: pegel_online)
  Tagesschau.pm                     # bund tagesschau <action>
  Nina.pm                           # bund nina <action>
  Bundestag.pm                      # bund bundestag <action>
  Dwd.pm                            # bund dwd <action>
  Feiertage.pm                      # bund feiertage <action>
  Smard.pm                          # bund smard <action>
  Bundeshaushalt.pm                 # bund bundeshaushalt <action>
  Bundesrat.pm                      # bund bundesrat <action>
  BundestagLobbyregister.pm         # bund bundestag-lobbyregister <action>
  DashboardDeutschland.pm           # bund dashboard-deutschland <action>
  Travelwarning.pm                  # bund travelwarning <action>
  Ladestationen.pm                  # bund ladestationen <action>
  EcoVisio.pm                       # bund eco-visio <action>
  Hilfsmittel.pm                    # bund hilfsmittel <action>

lib/WWW/Bund/CLI/Formatter.pm       # Template-Rendering (table/list/record)
lib/WWW/Bund/CLI/Strings.pm         # Lokalisierte Strings aus YAML

lib/WWW/Bund/Registry.pm            # API- und Endpunkt-Registry aus YAML
lib/WWW/Bund/Caller.pm              # HTTP-Aufrufe mit Auth/Cache/RateLimit
lib/WWW/Bund/Cache.pm               # Disk-Cache unter XDG_CACHE_HOME
lib/WWW/Bund/Auth.pm                # Auth-Header pro API
lib/WWW/Bund/RateLimit.pm           # Rate-Limiting pro API

lib/WWW/Bund/LWPIO.pm               # LWP-basierter IO-Adapter
lib/WWW/Bund/HTTPRequest.pm         # Request-Objekt
lib/WWW/Bund/HTTPResponse.pm        # Response-Objekt
lib/WWW/Bund/Role/IO.pm             # IO-Rolle (für MockIO in Tests)

lib/WWW/Bund/Response/
  JSON.pm                           # JSON-Response-Parser
  XML.pm                            # XML-Response-Parser (XML::Twig)
  Raw.pm                            # Raw-Response-Passthrough

lib/WWW/Bund/API/                   # Typed API-Adapter (optional)
  Autobahn.pm                       # $bund->autobahn->roads()
  NINA.pm                           # $bund->nina->warnings($ars)
  PegelOnline.pm                    # $bund->pegel_online->stations()
  Tagesschau.pm                     # $bund->tagesschau->homepage()
  Bundestag.pm                      # $bund->bundestag->conferences()
  DWD.pm                            # $bund->dwd->municipality_warnings()

share/
  registry.yml                      # 31 API-Definitionen (id, title, provider, auth, tags)
  endpoints.yml                     # 78 Endpunkt-Definitionen
                                    # (name, api, base_url, path, method, cache_ttl, query_params)

  templates/
    de/*.yml                        # 71 Deutsche Templates
    en/*.yml                        # 71 Englische Templates
    fr/*.yml                        # 71 Französische Templates
    es/*.yml                        # 71 Spanische Templates
    it/*.yml                        # 71 Italienische Templates
    nl/*.yml                        # 71 Niederländische Templates
    pl/*.yml                        # 71 Polnische Templates
    # Total: 497 Templates (71 × 7 Sprachen)

  strings/
    de.yml                          # Deutsche CLI-Strings (~48 Keys)
    en.yml                          # Englische CLI-Strings
    fr.yml                          # Französische CLI-Strings
    es.yml                          # Spanische CLI-Strings
    it.yml                          # Italienische CLI-Strings
    nl.yml                          # Niederländische CLI-Strings
    pl.yml                          # Polnische CLI-Strings

t/
  00-load.t                         # Module-Loading (42 Module)
  auth.t                            # Auth-Tests
  cache.t                           # Cache-Tests
  caller.t                          # Caller-Tests (mit MockIO)
  cli.t                             # CLI-Tests (Subprocess-basiert)
  formatter.t                       # Formatter-Tests
  integration.t                     # Live-API-Tests (opt-in via ENV)
  registry.t                        # Registry-Tests
  response.t                        # Response-Parser-Tests
  strings.t                         # Strings-Tests
  # Total: 290 Tests, alle bestehend
```

### CLI-Architektur (MooX::Cmd + MooX::Options)

**Root** (`CLI.pm`):
- Globale Options: `--output` (`-o`), `--lang`, `--template` (`-t`)
- Helper-Methoden: `_s()`, `_resolve_api()`, `_action_to_endpoint()`, `_path_param_names()`, `_format_output()`
- Command-Methoden: `cmd_list()`, `cmd_info()`, `cmd_api_help()`, `cmd_call()`
- `execute()`: Dispatcht unbekannte Commands mit Error+exit(1), sonst Overview

**API-Commands** (z.B. `Cmd::Autobahn`):
- `with 'Role::APICommand'`
- Nur `sub api_id { 'autobahn' }` definieren (~10 LOC pro Klasse)
- `execute()` kommt von Role

**Role::APICommand**:
- `requires 'api_id'`
- Generisches `execute($self, $args, $chain)`:
  - Wenn keine Args → `cmd_api_help()` via `$chain->[0]`
  - Sonst Action parsen und `cmd_call()` via `$chain->[0]`
  - Bei Fehler: `exit($rc)`

**Alias-Mapping** (`bin/bund`, `bin/bunden`):
- `pegel-online` / `pegel_online` → `pegel` gemappt vor `new_with_cmd`
- Geht durch `@ARGV`, skippt Options (`-`), mappt ersten Command

**WICHTIG:**
- **KEIN `namespace::clean`** in CLI-Klassen (inkompatibel mit MooX::Options - entfernt injizierte Methoden wie `_options_data`, `_options_config`)

## Wichtige Konventionen

### Dateinamen

- Template- und Endpunkt-Dateinamen nutzen **originale API-Bezeichnungen** (meist deutsch)
- Beispiel: `autobahn_roadworks`, `pegel_online_stations`, `nina_mapdata_katwarn`
- **NICHT** übersetzen - nur die **Headers/Labels** innerhalb der Templates werden pro Sprache übersetzt

### i18n-System

- `bund` = default Deutsch
- `bunden` = default Englisch (via `$ENV{WWW_BUND_LANG}`)
- `--lang XX` überschreibt Sprache zur Laufzeit (MooX::Options)
- **Unterstützte Sprachen:** de, en, fr, es, it, nl, pl
- `lang` ist `ro` (read-only) - wird bei Konstruktion gesetzt, keine Clearers nötig
- Templates in `share/templates/{lang}/`
- Strings in `share/strings/{lang}.yml`
- Strings.pm: `get($key)` oder `get($key, @sprintf_args)`, unbekannter Key → Key selbst
- **Neue Sprache hinzufügen:** Ordner + Templates + Strings-YAML anlegen, fertig

### UTF-8

- STDOUT/STDERR werden in `bin/bund` und `bin/bunden` auf `:encoding(UTF-8)` gesetzt
- Formatter liefert **immer Character-Strings** (keine Bytes):
  - JSON: `JSON::MaybeXS->new(utf8 => 0)` → Character-Strings
  - YAML: `decode('UTF-8', Dump($data))` → YAML::XS gibt Bytes, muss dekodiert werden
  - Templates: arbeiten direkt mit Character-Strings aus decode_json
- **Wenn Umlaute kaputt sind:** Prüfen ob alle Dump()-Aufrufe in decode() gewrappt sind
- **Template-Übersetzung:** Native Perl `open(..., '>:utf8', ...)` verwenden, **NICHT** File::Slurp (Encoding-Probleme)

### Cache

- XDG-konform: `$XDG_CACHE_HOME/www-bund/` (Fallback: `$HOME/.cache/www-bund/`)
- Per-Endpunkt TTLs in `share/endpoints.yml` als `cache_ttl` Feld
- Cache.pm: `get($key, $ttl)` - optionaler TTL-Override pro Aufruf
- **TTL-Stufen:**
  - `120s` - Notfälle/Warnungen (NINA, DWD, Autobahn-Warnungen)
  - `300s` - Echtzeit (Tagesschau, Pegel-Messwerte, Baustellen)
  - `1800s` - Moderat (Webcams, Suche, Zeitreihen)
  - `86400s` - Statisch (Straßenlisten, Stationslisten, Metadaten)
- **Nur GET-Requests** werden gecacht

### Template-System

- **3 Typen:**
  - `table` - Spalten (columns-Array mit field/header/width/wrap)
  - `list` - Aufzählung (columns: N für Anzahl Einträge pro Zeile)
  - `record` - Key-Value (fields-Array mit field/label)
- `extract: pfad.zum.array` - Daten vor dem Rendern extrahieren
- Dotted-Path-Zugriff: `water.shortname` navigiert verschachtelte Hashes
- `empty: "Keine Daten."` - Message wenn Array leer oder Feld fehlt
- **Kein Template gefunden** → YAML-Fallback

### Tests

- `t/caller.t` - benutzt MockIO (implementiert Role::IO) für HTTP-Mocking
- `t/cli.t` - testet via Subprocess (`$^X -Ilib bin/bund ...`)
- `t/integration.t` - braucht `WWW_BUND_LIVE_TEST=1` und Internet
- **MooX::Options --help:** Generiert automatisch Help-Output, Tests müssen auf Options prüfen (nicht auf Overview-Text)

### XML-Parsing (Bundestag/Bundesrat)

- Bundestag API gibt **XML** zurück (nicht JSON)
- Response::XML mit XML::Twig verwenden
- `LWP::UserAgent->decoded_content` gibt Perl character strings zurück
- **XML::Parser braucht Bytes** → `encode_utf8($content)` vor `$twig->parse()` wenn `utf8::is_utf8` true
- Cache muss auch `encode_utf8` vor `write` mit `:raw` (vermeidet Latin-1 Byte-Korruption)

## Implementierte APIs (16 von 31)

| API | Endpoints | Auth | Templates | Status |
|-----|-----------|------|-----------|--------|
| **autobahn** | 7 | none | ✓ | ✓ Vollständig |
| **pegel_online** | 5 | none | ✓ | ✓ Vollständig |
| **tagesschau** | 4 | none | ✓ | ✓ Vollständig |
| **nina** | 13 | none | ✓ | ✓ Vollständig |
| **bundestag** | 8 | none | ✓ | ✓ Vollständig (XML) |
| **dwd** | 5 | none | ✓ | ✓ Vollständig |
| **feiertage** | 1 | none | ✓ | ✓ Vollständig |
| **smard** | 3 | none | ✓ | ✓ Vollständig |
| **bundeshaushalt** | 1 | none | ✓ | ⚠️ API-Fehler (400) |
| **bundesrat** | 10 | none | ✓ | ✓ Vollständig (XML) |
| **bundestag_lobbyregister** | 1 | none | ✓ | ✓ Vollständig |
| **dashboard_deutschland** | 3 | none | ✓ | ✓ Vollständig |
| **travelwarning** | 6 | none | ✓ | ✓ Vollständig |
| **ladestationen** | 1 | none | ✓ | ⚠️ URL-Korrektur nötig |
| **eco_visio** | 2 | none | ✓ | 🔄 Zu testen |
| **hilfsmittel** | 7 | none | ✓ | 🔄 Zu testen |

**Total: 78 Endpoints**

## API-Roadmap

### ✅ Implementiert (16 APIs)
Siehe Tabelle oben

### 🔄 Geplant (Public, kein Auth - 10 APIs)
- abfallnavi (10 endpoints)
- ddb - Deutsche Digitale Bibliothek (3 endpoints)
- destatis (4 endpoints) - **High Priority**
- deutschlandatlas (1 endpoint)
- handelsregister (1 endpoint)
- luftqualitaet (13 endpoints) - **High Priority**
- marktstammdaten (8 endpoints)
- mudab - Meeresumweltdatenbank (11 endpoints)
- pflanzenschutzmittelzulassung (6 endpoints)
- regionalatlas (1 endpoint)

### 🔐 Nicht geplant (Auth erforderlich - 5 APIs)
- ausbildungssuche (BA API-Key)
- bewerberboerse (BA API-Key)
- jobsuche (BA API-Key)
- lebensmittelwarnung (API-Key)
- dip_bundestag (API-Key)

## Bekannte Issues / TODOs

- **bundeshaushalt:** API gibt HTTP 400 zurück - base_url oder params prüfen
- **ladestationen:** URL zeigt auf HTML-Seite statt GeoJSON - URL korrigieren
- **eco_visio, hilfsmittel:** Live-Tests ausstehend
- **Weitere APIs:** 10 öffentliche APIs ohne Auth könnten implementiert werden

## Best Practices für neue APIs hinzufügen

1. **registry.yml** prüfen ob API schon registriert ist
2. **endpoints.yml** neue Endpoints hinzufügen:
   - `name`: `{api_id}_{action}` (snake_case)
   - `base_url`: von OpenAPI-Spec `servers[0].url`
   - `cache_ttl`: passend zur Datenfrequenz
   - `query_params`: optionale Query-Parameter-Liste
3. **CLI-Command-Klasse** erstellen: `lib/WWW/Bund/CLI/Cmd/{ApiName}.pm`
   - `with 'Role::APICommand'`
   - `sub api_id { 'api_name' }`
4. **t/00-load.t** neue Klasse hinzufügen
5. **Live-Test** durchführen: `perl -Ilib bin/bund api-name action`
6. **Templates erstellen** für alle 7 Sprachen:
   - Response-Struktur analysieren
   - `type` wählen (table/list/record)
   - Headers übersetzen
7. **Tests aktualisieren**, **CLAUDE.md** & **README.md** aktualisieren

## Nützliche Kommandos für Entwicklung

```bash
# Alle API-IDs aus registry.yml
grep -E "^- id:" share/registry.yml | sed 's/- id: //' | sort

# APIs MIT Endpoints
grep -E "^- name:" share/endpoints.yml | sed 's/- name: //' | sed 's/_.*$//' | sort -u

# APIs OHNE Endpoints
comm -23 <(grep -E "^- id:" share/registry.yml | sed 's/- id: //' | sort) \
         <(grep -E "^- name:" share/endpoints.yml | sed 's/- name: //' | sed 's/_.*$//' | sort -u)

# Template-Zählung
for lang in de en fr es it nl pl; do echo -n "$lang: "; ls -1 share/templates/$lang/ | wc -l; done

# Live-API-Test mit Debug
perl -Ilib bin/bund -o json api-name action | jq .

# String-Übersetzung prüfen
grep "^title:" share/strings/*.yml
```

## Release-Checklist

- [ ] Alle Tests bestehen: `prove -l t/`
- [ ] Changes aktualisiert mit neuen Features
- [ ] README.md Roadmap aktualisiert
- [ ] CLAUDE.md aktualisiert
- [ ] POD-Dokumentation aktualisiert (via `pod-writer` agent)
- [ ] Version-Bump in dist.ini
- [ ] `dzil build && dzil test`
- [ ] `dzil release` (pushed zu CPAN)
