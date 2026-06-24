# Mennekes AMTRON Wallbox – Home Assistant Integration

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-41BDF5.svg)](https://github.com/hacs/integration)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Release](https://img.shields.io/github/v/release/nobelp/mennekes-amtron-ha)](https://github.com/nobelp/mennekes-amtron-ha/releases)

Vollständige Integration einer Mennekes AMTRON Wallbox in Home Assistant:
- **Echtzeit-Monitoring** via Modbus TCP (Spannung, Strom, Leistung, Ladestatus)
- **Ladevorgänge** via REST API (Sessionshistorie, Fahrzeugzuordnung, Kosten)
- **Steuerung** von HEMS-Limit, Safe Current, Verfügbarkeit, Ladeunterbrechung
- **Dashboard** mit ApexCharts-Balkendiagramm, Monatstabelle, Ladevorgänge-Liste

---

## 📦 Installation

### Option 1: HACS (Recommended)

[![Open your Home Assistant instance and open a repository inside the Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?owner=nobelp&repository=mennekes-amtron-ha&category=automation)

1. Klicke auf den HACS-Button oben oder navigiere zu **HACS → Automations**
2. Suche nach **"Mennekes AMTRON"**
3. Klicke **"Download"** und folge der Anleitung

### Option 2: Manuell

```bash
# Klone das Repository
git clone https://github.com/nobelp/mennekes-amtron-ha.git ~/HA_Menneckes

# Kopiere die Dateien nach Home Assistant (siehe "Vollständige Neu-Installation" unten)
```

---

## ✅ Home Assistant Quality Scale

| Aspekt | Status | Details |
|--------|--------|---------|
| **Code Quality** | ⭐⭐⭐⭐ | Python-Scripts mit error handling |
| **Documentation** | ⭐⭐⭐⭐⭐ | Umfassend auf Deutsch + English |
| **Testing** | ⭐⭐⭐ | Getestet auf HA 2026.5.4 + AMTRON 730 |
| **Maintainability** | ⭐⭐⭐⭐ | Modulare YAML + Python Struktur |
| **Security** | ⭐⭐⭐⭐ | Keine hardcoded Passwörter/IPs, .env support |

---

## Übersicht: Wie alles zusammenhängt

```
┌─────────────────────┐     Modbus TCP :502      ┌────────────────────┐
│  Home Assistant     │ ◄──────────────────────► │  Mennekes Wallbox  │
│  192.x.x.x          │                           │  192.x.x.x         │
│                     │     REST API :80          │                    │
│  (Docker auf NAS)   │ ◄──────────────────────► │  (WLAN + GSM)      │
└─────────────────────┘                           └────────────────────┘
        │
        │ liest/schreibt
        ▼
  /config/wallbox_sessions.json    (Ladevorgänge + Monatsdaten)
  /config/wallbox_vehicles.json    (RFID → Fahrzeugname Mapping)
  /config/wallbox_config.json      (Strompreis CHF/kWh)
  /config/wallbox_fetch.log        (Fetch-Log für Debugging)
```

### Datenpfade & Frequenz

| Quelle | Frequenz | Ziel |
|--------|----------|------|
| Modbus TCP Register | alle 30s | HA-Sensoren (Spannung, Strom, Leistung…) |
| REST API `/ChargingTransactionHistory` | stündlich + HA-Start | `/config/wallbox_sessions.json` |
| `wallbox_sessions.json` | stündlich (cat) | `sensor.wallbox_sessions` |
| `sensor.wallbox_sessions` Attribute | Live (Template) | Kosten-Sensoren, Dashboard |
| Dashboard (ApexCharts) | bei Seitenaufruf | Balkendiagramm aus `monthly_summary` |

---

## Hardware-Konfiguration

- **Wallbox**: Mennekes AMTRON 4Business 730 11 C2
- **Firmware**: 1.5.41
- **Primäre IP**: `192.x.x.x` (WLAN) — ersetze mit deiner Wallbox-IP
- **Fallback IP**: `10.x.x.x` (GSM/Mobilfunk) — optional, nur wenn vorhanden
- **Modbus**: Port 502, Slave ID 1
- **REST API**: Port 80 (HTTP)
- **HA-Host**: `192.x.x.x:8123` (Docker auf Synology NAS) — ersetze mit deiner HA-IP
- **HA Config**: `/config/` im Home Assistant Container

---

## Umgebungsvariablen & Konfiguration

### .env-Datei erstellen

Die Python-Skripte benötigen Umgebungsvariablen für die Wallbox-Verbindung. Kopiere `.env.example` und passe die Werte an:

```bash
cp .env.example .env
```

Inhalt von `.env` (bearbeite mit deinen Werten):

```bash
# Mennekes Wallbox Configuration
WALLBOX_URL=http://192.x.x.x/api/v1    # Wallbox REST API URL (ersetze 192.x.x.x)
WALLBOX_PASS=MUSTER_PASSWORD            # Installer-Passwort (ersetze mit deinem Passwort)

# Home Assistant (optional)
HA_HOST=192.x.x.x                       # Home Assistant Host IP (ersetze mit deiner HA-IP)
HA_TOKEN=MUSTER_API_TOKEN               # Long-lived access token (optional)
```

### Skripte mit Umgebungsvariablen ausführen

```bash
# Mit .env-Datei
source .env
python3 python_scripts/fetch_charging_sessions.py

# Oder direkt übergeben
WALLBOX_PASS=your-password python3 python_scripts/fetch_charging_sessions.py

# Oder als Argument
python3 python_scripts/fetch_charging_sessions.py your-password
```

> **Wichtig**: `.env` wird von Git ignoriert und sollte **nicht** in die Version Control eingecheckt werden. Nutze `.env.example` zur Dokumentation.

---

## Vollständige Neu-Installation (Schritt für Schritt)

### 1. Dateien aus Workspace nach HA kopieren

```bash
# Modbus-Konfiguration
cp modbus_wallbox.yaml /config/

# Helper-Entities
cp input_number_wallbox.yaml /config/
cp input_boolean_wallbox.yaml /config/
cp input_select_wallbox.yaml /config/
cp input_text_wallbox.yaml /config/

# Template-Sensoren
cp templates/wallbox.yaml /config/templates/

# Python-Skripte
cp python_scripts/fetch_charging_sessions.py /config/python_scripts/
cp python_scripts/run_wallbox_fetch.sh /config/python_scripts/
cp python_scripts/write_vehicles.py /config/python_scripts/
cp python_scripts/assign_vehicle.py /config/python_scripts/

# Konfigurationsdateien
cp wallbox_config.json /config/
cp wallbox_vehicles.json /config/

# Dashboard (generiert von generate_dashboard.py)
python3 generate_dashboard.py > /config/.storage/lovelace.dashboard_wallbox
```

### 2. `configuration.yaml` anpassen

Folgende Blöcke in die bestehende `configuration.yaml` einfügen:

```yaml
# Recorder: Session-Sensor ausschliessen (grosse JSON-Attribute würden
# den Frontend-Abruf bei ApexCharts einfrieren)
recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions

# Wallbox Modbus + Helper
modbus: !include modbus_wallbox.yaml
input_number: !include input_number_wallbox.yaml
input_boolean: !include input_boolean_wallbox.yaml
input_select: !include input_select_wallbox.yaml
input_text: !include input_text_wallbox.yaml

# command_line Sensoren (HA 2022.11+ Format – WICHTIG: top-level, nicht unter "sensor:")
command_line:
  - sensor:
      name: "Wallbox Software Version"
      unique_id: wallbox_software_version
      command: "curl -sf http://192.x.x.x/api/v1/PublicInfo | python3 -c \"import json,sys; d=json.load(sys.stdin); print(d['currentVersion'])\"" # Replace 192.x.x.x
      scan_interval: 3600

  - sensor:
      name: "Wallbox Sessions"
      unique_id: wallbox_sessions
      command: "cat /config/wallbox_sessions.json 2>/dev/null || echo '{\"count\":0,\"sessions\":[],\"total_kwh\":0,\"monthly_summary\":[],\"vehicles\":[],\"vehicle_totals\":{}}'"
      value_template: "{{ value_json.count | int(0) }}"
      json_attributes:
        - sessions
        - total_kwh
        - monthly_summary
        - vehicles
        - vehicle_totals
        - last_session_kwh
        - last_vehicle
      scan_interval: 3600

# Shell-Commands
shell_command:
  wallbox_fetch_sessions: "/bin/sh /config/python_scripts/run_wallbox_fetch.sh"

  wallbox_write_vehicles: >-
    RFID1="{{ states('input_text.wallbox_vehicle_1_rfid') }}"
    NAME1="{{ states('input_text.wallbox_vehicle_1_name') }}"
    RFID2="{{ states('input_text.wallbox_vehicle_2_rfid') }}"
    NAME2="{{ states('input_text.wallbox_vehicle_2_name') }}"
    RFID3="{{ states('input_text.wallbox_vehicle_3_rfid') }}"
    NAME3="{{ states('input_text.wallbox_vehicle_3_name') }}"
    RFID4="{{ states('input_text.wallbox_vehicle_4_rfid') }}"
    NAME4="{{ states('input_text.wallbox_vehicle_4_name') }}"
    python3 /config/python_scripts/write_vehicles.py

  wallbox_assign_vehicle: >-
    RFID_OPTION="{{ states('input_select.wallbox_rfid_selector') }}"
    VEHICLE_NAME="{{ states('input_text.wallbox_vehicle_name_new') }}"
    python3 /config/python_scripts/assign_vehicle.py
```

> **Wichtig**: `recorder: exclude` verhindert, dass der Sensor mit seinen grossen JSON-Attributen stündlich in die Recorder-Datenbank geschrieben wird. Ohne diese Einstellung friert das Frontend beim Öffnen der History-Seite ein (ApexCharts versucht die komplette Entity-History zu laden).

### 3. `automations.yaml` – Automation hinzufügen

```yaml
- id: '1780407000000'
  alias: Wallbox Ladevorgänge aktualisieren
  description: Holt Sessions von der API (beim Start und stündlich), aktualisiert Sensor und beide Dropdowns
  triggers:
  - event: start
    trigger: homeassistant
  - trigger: time_pattern
    hours: /1
  conditions: []
  actions:
  - action: shell_command.wallbox_fetch_sessions
    data: {}
  - action: homeassistant.update_entity
    target:
      entity_id: sensor.wallbox_sessions
  - delay: "00:00:04"
  - action: input_select.set_options
    target:
      entity_id: input_select.wallbox_month_filter
    data:
      options: >
        {{ ['Alle'] + ((state_attr('sensor.wallbox_sessions', 'monthly_summary') or []) | map(attribute='month_label') | list) }}
  - action: input_select.set_options
    target:
      entity_id: input_select.wallbox_rfid_selector
    data:
      options: >
        {% set sessions = state_attr('sensor.wallbox_sessions', 'sessions') %}
        {% set ns = namespace(seen=[], opts=[]) %}
        {% if sessions %}{% for s in sessions %}{% if s.rfid and s.rfid not in ns.seen %}{% set ns.seen = ns.seen + [s.rfid] %}{% set ns.opts = ns.opts + [s.rfid ~ ' — ' ~ s.vehicle] %}{% endif %}{% endfor %}{% endif %}
        {{ ['Bitte auswählen...'] + ns.opts }}
  mode: single
```

### 4. `scripts.yaml` – Scripts hinzufügen

```yaml
# Script 1: RFID einem Fahrzeugnamen zuweisen (via Dropdown)
wallbox_zuweise_fahrzeug:
  alias: "Fahrzeug RFID zuweisen"
  icon: mdi:card-account-details-outline
  mode: single
  sequence:
    - action: shell_command.wallbox_assign_vehicle
    - action: shell_command.wallbox_fetch_sessions
    - delay: "00:00:20"
    - action: homeassistant.update_entity
      target:
        entity_id: sensor.wallbox_sessions
    - delay: "00:00:04"
    - action: input_select.set_options
      target:
        entity_id: input_select.wallbox_month_filter
      data:
        options: >
          {{ ['Alle'] + ((state_attr('sensor.wallbox_sessions', 'monthly_summary') or []) | map(attribute='month_label') | list) }}
    - action: input_select.set_options
      target:
        entity_id: input_select.wallbox_rfid_selector
      data:
        options: >
          {% set sessions = state_attr('sensor.wallbox_sessions', 'sessions') %}
          {% set ns = namespace(seen=[], opts=[]) %}
          {% if sessions %}{% for s in sessions %}{% if s.rfid and s.rfid not in ns.seen %}{% set ns.seen = ns.seen + [s.rfid] %}{% set ns.opts = ns.opts + [s.rfid ~ ' — ' ~ s.vehicle] %}{% endif %}{% endfor %}{% endif %}
          {{ ['Bitte auswählen...'] + ns.opts }}

# Script 2: Alle 4 manuellen RFID-Slots speichern + neu laden
wallbox_aktualisiere_fahrzeuge:
  alias: "Wallbox Fahrzeuge & Daten aktualisieren"
  icon: mdi:content-save-all
  mode: single
  sequence:
    - action: shell_command.wallbox_write_vehicles
    - action: shell_command.wallbox_fetch_sessions
    - delay: "00:00:20"
    - action: homeassistant.update_entity
      target:
        entity_id: sensor.wallbox_sessions
    - delay: "00:00:04"
    - action: input_select.set_options
      target:
        entity_id: input_select.wallbox_month_filter
      data:
        options: >
          {{ ['Alle'] + ((state_attr('sensor.wallbox_sessions', 'monthly_summary') or []) | map(attribute='month_label') | list) }}
    - action: input_select.set_options
      target:
        entity_id: input_select.wallbox_rfid_selector
      data:
        options: >
          {% set sessions = state_attr('sensor.wallbox_sessions', 'sessions') %}
          {% set ns = namespace(seen=[], opts=[]) %}
          {% if sessions %}{% for s in sessions %}{% if s.rfid and s.rfid not in ns.seen %}{% set ns.seen = ns.seen + [s.rfid] %}{% set ns.opts = ns.opts + [s.rfid ~ ' — ' ~ s.vehicle] %}{% endif %}{% endfor %}{% endif %}
          {{ ['Bitte auswählen...'] + ns.opts }}
```

### 5. HACS-Karte installieren (falls nicht vorhanden)

Das Dashboard benötigt **apexcharts-card** (HACS → Frontend):
- HACS → Frontend → `apexcharts-card` von RomRider installieren
- Getestet mit Version **2.2.3**

### 6. Dashboard generieren und HA neu starten

```bash
# Dashboard-JSON aus Python-Script generieren
cd /workspace/HA_Menneckes
python3 generate_dashboard.py > /config/.storage/lovelace.dashboard_wallbox

# HA neu starten: Settings → System → Restart
```

Nach dem Neustart läuft die Startup-Automation automatisch:
- Ladevorgänge werden von der API geholt (~20s)
- `sensor.wallbox_sessions` wird aktualisiert
- RFID-Dropdown befüllt sich mit bekannten Fahrzeugen
- Monatsfilter-Dropdown erhält alle verfügbaren Monate

---

## Dashboard – Tab-Beschreibung

Das Wallbox-Dashboard ist unter `/dashboard-wallbox/` erreichbar und hat drei Tabs.

### Tab 1: Übersicht

Echtzeit-Monitoring via Modbus TCP (Aktualisierung alle 30 Sekunden):

| Karte | Inhalt |
|-------|--------|
| **Status** | Ladestatus, Fahrzeugzustand, Verfügbarkeit, Steckerschloss, Fehlercodes, Protokollversion |
| **Aktuelle Ladesession** | Energie Session, Ladedauer, Signalisierter Strom, Max. Strom Fahrzeug |
| **Energie (kWh)** | Gesamtenergie + L1/L2/L3 einzeln |
| **Leistung (W)** | Gesamtleistung + L1/L2/L3 einzeln |
| **Spannung & Strom** | Spannung und Strom pro Phase |
| **Limits (gelesen)** | HEMS Stromlimit, Operator Limit, Safe Current, Timeout – nur Anzeige |
| **Dynamic Load Management** | DLM-Modus, Slaves, verfügbarer/angewandter Strom L1-L3 |

### Tab 2: History

Ladevorgänge aus der REST-API – Panel-Ansicht (Vollbreite):

```
┌──────────────────┬─────────────────────────────────────────┐
│ Statistik &      │  ApexCharts Balkendiagramm               │
│ Filter (1/3)     │  Monatsverbrauch pro Fahrzeug (2/3)      │
├──────────────────┴─────────────────────────────────────────┤
│  Monatstabelle (kWh & CHF) – volle Breite                  │
├──────────────────────────────────────────────────────────────┤
│  Ladevorgänge-Tabelle – volle Breite                        │
└──────────────────────────────────────────────────────────────┘
```

#### Statistik & Filter (linke Spalte, 1/3)

Zeigt Gesamtübersicht und den Monatsfilter:
- Anzahl Ladevorgänge
- Gesamtenergie / Gesamtkosten CHF
- Kessi gesamt / Tessi gesamt
- kWh & Kosten aktueller Monat
- **Monatsfilter-Dropdown** (`input_select.wallbox_month_filter`): Wähle einen Monat → Ladevorgänge-Tabelle filtert automatisch

#### ApexCharts Balkendiagramm (rechte Spalte, 2/3)

Gestapeltes Balkendiagramm mit einem Balken pro Monat, aufgeteilt nach Fahrzeug (Blau = Fahrzeug 1, Orange = Fahrzeug 2).

**Wie es funktioniert:**
- Liest direkt aus `sensor.wallbox_sessions` → Attribut `monthly_summary` via JavaScript `data_generator`
- **Keine HA-Statistiken oder Long-Term-Storage nötig** – alle historischen Monate aus der Session-JSON werden sofort angezeigt
- Zeitfenster: `graph_span: 13month` (letzte 13 Monate sichtbar)
- Neue Monate erscheinen automatisch beim nächsten stündlichen Fetch

**Voraussetzungen:**
- apexcharts-card (HACS) installiert, Version ≥ 2.2.3
- `sensor.wallbox_sessions` muss im recorder ausgeschlossen sein (verhindert Freeze bei der History-API)

#### Monatstabelle (volle Breite)

Tabelle aller Monate mit exakten kWh- und CHF-Werten:

| Monat | Kessi kWh | CHF | Tessi kWh | CHF | Gesamt kWh | CHF |
|-------|-----------|-----|-----------|-----|------------|-----|
| Mai 2026 | 298.1 | 86.44 | 0.0 | 0.00 | 298.1 | 86.44 |
| April 2026 | 5.2 | 1.50 | 39.7 | 11.51 | 44.9 | 13.01 |

- Preis kommt aus `input_number.wallbox_price_per_kwh` (live anpassbar)
- Neueste Monate oben

#### Ladevorgänge-Tabelle (volle Breite)

Alle Ladevorgänge mit Datum, Fahrzeug, Dauer, kWh und CHF.

- Wird durch den Monatsfilter gefiltert
- Bei "Alle": zeigt Fahrzeug-Gesamtsummen am Ende
- Bei Monatsauswahl: zeigt Monatssummen pro Fahrzeug

### Tab 3: Konfiguration

Alle Einstellungen und Fahrzeugverwaltung an einem Ort.

#### Karte: Fahrzeug zuweisen (Dropdown-Methode, empfohlen)

Der komfortabelste Weg um einem RFID-Tag einen Fahrzeugnamen zu geben:

1. **RFID auswählen** aus dem Dropdown (`input_select.wallbox_rfid_selector`)
   - Format: `04A5F3D2CC1D90 — Kessi`
   - Wird nach jedem Fetch automatisch mit allen bekannten RFIDs befüllt
   - Enthält den aktuell gespeicherten Namen (oder "Unbekannt" wenn neu)
2. **Neuer Fahrzeugname** eingeben (`input_text.wallbox_vehicle_name_new`)
3. Button **"Zuweisen & Daten neu laden"** drücken
   - Ruft `script.wallbox_zuweise_fahrzeug` auf
   - Speichert RFID → Name in `wallbox_vehicles.json`
   - Holt alle Sessions neu mit dem aktualisierten Mapping
   - Aktualisiert beide Dropdowns

#### Karte: Bekannte Fahrzeuge

Tabelle aller RFIDs mit ihrem aktuellen Namen (aus den Ladevorgängen ermittelt).

#### Karte: Wallbox-Einstellungen

Alle Konfigurationsparameter:

| Entität | Beschreibung |
|---------|-------------|
| `input_number.wallbox_price_per_kwh` | Strompreis CHF/kWh – Ändert alle Kostenberechnungen sofort |
| `input_number.wallbox_hems_current_limit` | HEMS Stromlimit (0 = Pause, 6-16A) |
| `input_number.wallbox_safe_current` | Safe Current (0-32A) |
| `input_number.wallbox_comm_timeout` | Kommunikations-Timeout (1-300s) |
| `input_boolean.wallbox_cp_availability` | CP Verfügbarkeit ein/aus |
| `input_boolean.wallbox_pause_charging` | Laden sofort pausieren |

#### Karte: Manuelle RFID-Verwaltung (4 Slots)

Ältere Methode mit fixen Slots für 4 Fahrzeuge. Button "Alle 4 Slots speichern & neu laden" schreibt alle 4 Einträge gleichzeitig in `wallbox_vehicles.json`.

---

## Konfigurationsdateien

### `wallbox_config.json` – Strompreis für den Fetch

```json
{
  "price_per_kwh_chf": 0.29
}
```

Dieser Preis wird vom Fetch-Script in die Sessions-Daten eingebettet. Im Dashboard kann der Preis live über `input_number.wallbox_price_per_kwh` angepasst werden – das wirkt sofort auf alle Anzeigen ohne neuen Fetch.

### `wallbox_vehicles.json` – RFID-Mapping

```json
{
  "04A5F3D2CC1D90": "Kessi",
  "049D869A5A2294": "Tessi"
}
```

Wird von `fetch_charging_sessions.py` gelesen um Sessions den Fahrzeugnamen zuzuordnen. Kann über das Dashboard (Konfiguration-Tab) oder direkt editiert werden.

---

## Wie wird der Preis berechnet?

Der Strompreis wird **zweistufig** konfiguriert:

1. **`wallbox_config.json`** (`price_per_kwh_chf: 0.29`) – wird beim Fetch gelesen und in `wallbox_sessions.json` eingebettet
2. **`input_number.wallbox_price_per_kwh`** (Standard: 0.29) – Live-Wert für HA-Template-Sensoren und Dashboard

**Kostenberechnung**: `energy_kwh × price_per_kwh`

| Ändere... | Effekt |
|-----------|--------|
| `input_number.wallbox_price_per_kwh` im Dashboard | Alle Kosten-Anzeigen ändern sich **sofort** (live) |
| `wallbox_config.json` direkt editieren | Wirkt beim nächsten Fetch (stündlich) auf die JSON-Daten |

---

## Wann / Wie wird aktualisiert?

### Automatisch

| Zeitpunkt | Was passiert |
|-----------|-------------|
| HA-Start | Fetch-Automation startet, holt alle Sessions von API |
| Jede volle Stunde (`:00`) | Automation holt Sessions, aktualisiert Sensor + beide Dropdowns |
| Alle 30 Sekunden | Modbus-Polling: Spannung, Strom, Leistung, Status |
| Alle 60 Minuten | Modbus: Software-Version, Energie-Gesamtzähler |

### Manuell (Developer Tools → Services)

```yaml
# Sessions-Fetch manuell auslösen:
service: shell_command.wallbox_fetch_sessions

# Sensor sofort neu lesen:
service: homeassistant.update_entity
entity_id: sensor.wallbox_sessions

# Fahrzeug zuweisen (Dropdown-Wert verwenden):
service: script.wallbox_zuweise_fahrzeug

# Alle 4 Slots speichern + neu laden:
service: script.wallbox_aktualisiere_fahrzeuge
```

### Ablauf eines Fetch

```
Automation trigger (Start oder /1h)
    │
    ├── shell_command.wallbox_fetch_sessions
    │       └── run_wallbox_fetch.sh
    │               └── fetch_charging_sessions.py
    │                       ├── GET /api/v1/Nonce
    │                       ├── POST /api/v1/AuthManagement/login (Installer)
    │                       ├── GET /api/v1/ChargingTransactionHistory/ReadFromTo
    │                       │       from=2024-01-01, take=100, sortiert in Python
    │                       ├── RFID → Name via wallbox_vehicles.json
    │                       ├── Kostenberechnung via wallbox_config.json
    │                       └── Schreibt /config/wallbox_sessions.json
    │
    ├── homeassistant.update_entity(sensor.wallbox_sessions)
    │       └── cat /config/wallbox_sessions.json → Sensor-State + Attribute
    │
    ├── delay 4s
    │
    ├── input_select.set_options(wallbox_month_filter)
    │       └── ['Alle', 'Mai 2026', 'April 2026', ...]
    │
    └── input_select.set_options(wallbox_rfid_selector)
            └── ['Bitte auswählen...', '04A5F3D2CC1D90 — Kessi', '049D869A5A2294 — Tessi']
```

---

## Fahrzeuge verwalten (RFID → Name)

### Methode 1: Dropdown (empfohlen)

1. Dashboard → Tab **"Konfiguration"**
2. **"RFID auswählen"** – Dropdown zeigt alle bekannten RFIDs mit aktuellem Namen
3. **"Neuer Fahrzeugname"** – Namen eingeben (z.B. "Kessi")
4. **"Zuweisen & Daten neu laden"** drücken
5. Nach ~25 Sekunden: Sessions zeigen den neuen Namen, Dropdown aktualisiert

### Methode 2: Manuelle 4-Slot-Verwaltung

1. Dashboard → Tab **"Konfiguration"** → Karte "Manuelle RFID-Verwaltung"
2. RFID-IDs und Namen in die Felder eintragen
3. **"Alle 4 Slots speichern & neu laden"** drücken

### Methode 3: Direkt via Datei

```bash
# SSH auf NAS:
nano /volume1/docker/homeassistant/wallbox_vehicles.json

# Format:
{
  "04A5F3D2CC1D90": "Kessi",
  "049D869A5A2294": "Tessi",
  "NEUE_RFID_ID": "Neues Fahrzeug"
}
```

Danach: `service: shell_command.wallbox_fetch_sessions` auslösen.

### Woher kommt die RFID?

Die RFIDs erscheinen automatisch in:
- **Konfiguration-Tab** → "Bekannte Fahrzeuge" (aus Ladevorgängen)
- **RFID-Dropdown** (`wallbox_rfid_selector`) – nach jedem Fetch aktualisiert

Unbekannte RFIDs erscheinen als `"RFID_CODE — RFID_CODE"` (RFID = Name, noch nicht zugeordnet).

---

## Alle HA-Entitäten

### Modbus-Sensoren (direkt von Wallbox via Modbus)

| Entität | Beschreibung | Einheit |
|---------|-------------|---------|
| `sensor.meter_voltage_l1/l2/l3` | Spannung pro Phase | V |
| `sensor.wallbox_current_l1/l2/l3_ampere` | Strom pro Phase | A |
| `sensor.meter_power_l1/l2/l3` | Leistung pro Phase | W |
| `sensor.wallbox_total_power` | Gesamtleistung | W |
| `sensor.wallbox_energy_l1/l2/l3_kwh` | Energie pro Phase | kWh |
| `sensor.wallbox_total_energy_kwh` | Gesamtenergie | kWh |
| `sensor.wallbox_session_energy_kwh` | Session-Energie | kWh |
| `sensor.hems_current_limit` | HEMS Limit (gelesen) | A |
| `sensor.operator_current_limit` | Operator Limit | A |
| `sensor.safe_current` | Safe Current | A |
| `sensor.comm_timeout` | Timeout | s |
| `sensor.signaled_current` | Signalisierter Strom | A |
| `sensor.max_current_ev` | Max. Strom EV | A |
| `sensor.dlm_num_slaves_connected` | DLM Slaves | – |
| `sensor.dlm_overall_current_available_l1/l2/l3` | DLM verfügbar | A |
| `sensor.dlm_overall_current_applied_l1/l2/l3` | DLM angewandt | A |

### Template-Sensoren (aus `templates/wallbox.yaml`)

| Entität | Beschreibung |
|---------|-------------|
| `sensor.wallbox_charging_status` | Ladestatus (Text: Lädt, Bereit, …) |
| `sensor.wallbox_vehicle_state_text` | Fahrzeugzustand A-E |
| `sensor.wallbox_cp_availability_text` | Verfügbarkeit |
| `sensor.wallbox_plug_lock_status_text` | Steckerschloss |
| `sensor.wallbox_error_codes_text` | Fehlercodes dekodiert |
| `sensor.wallbox_dlm_mode_text` | DLM-Modus Text |
| `sensor.wallbox_charge_duration_formatted` | Ladedauer hh:mm:ss |
| `sensor.wallbox_chargepoint_model` | Modell-String |

### Kosten-Sensoren (aus `templates/wallbox.yaml`)

| Entität | Beschreibung |
|---------|-------------|
| `sensor.wallbox_kosten_gesamt_chf` | Gesamtkosten CHF |
| `sensor.wallbox_kwh_aktueller_monat` | kWh im aktuellen Monat |
| `sensor.wallbox_kosten_aktueller_monat_chf` | Kosten im aktuellen Monat CHF |
| `sensor.wallbox_kwh_kessi_gesamt` | Kessi Gesamtverbrauch kWh |
| `sensor.wallbox_kwh_tessi_gesamt` | Tessi Gesamtverbrauch kWh |

### Sessions-Sensor (`command_line`)

| Entität / Attribut | Beschreibung |
|-------------------|-------------|
| `sensor.wallbox_sessions` (State) | Anzahl Ladevorgänge |
| `.attributes.sessions` | Liste aller Ladevorgänge (max. 100) |
| `.attributes.monthly_summary` | Monatliche Zusammenfassung mit `by_vehicle` |
| `.attributes.vehicle_totals` | Gesamtverbrauch pro Fahrzeug |
| `.attributes.total_kwh` | Gesamtenergie aller Sessions |
| `.attributes.vehicles` | Liste aller Fahrzeugnamen |
| `.attributes.last_session_kwh` | Letzte Session kWh |
| `.attributes.last_vehicle` | Letztes Fahrzeug |

> **Recorder-Ausschluss**: `sensor.wallbox_sessions` ist aus dem HA-Recorder ausgeschlossen (`recorder: exclude`). Die Daten sind in `wallbox_sessions.json` persistent. Kein History-Tab in HA für diese Entity.

### Helper-Entities

| Entität | Beschreibung |
|---------|-------------|
| `input_number.wallbox_price_per_kwh` | Strompreis CHF/kWh (live, 0.01–2.00) |
| `input_number.wallbox_hems_current_limit` | HEMS-Limit setzen (0-16A) |
| `input_number.wallbox_safe_current` | Safe Current setzen (0-32A) |
| `input_number.wallbox_comm_timeout` | Comm Timeout setzen (1-300s) |
| `input_boolean.wallbox_cp_availability` | CP Verfügbarkeit |
| `input_boolean.wallbox_pause_charging` | Laden pausieren |
| `input_select.wallbox_month_filter` | Monatsfilter (auto-befüllt nach Fetch) |
| `input_select.wallbox_rfid_selector` | RFID-Dropdown für Fahrzeugzuordnung (auto-befüllt) |
| `input_text.wallbox_vehicle_1-4_rfid` | RFID-Karten Slots (manuelle Methode) |
| `input_text.wallbox_vehicle_1-4_name` | Fahrzeugnamen Slots (manuelle Methode) |
| `input_text.wallbox_vehicle_name_new` | Neuer Name für Dropdown-Zuweisung |

---

## API-Authentifizierung (Wallbox REST)

```
1. GET  /api/v1/Nonce?nocache=<timestamp>        → Nonce-String
2. POST /api/v1/AuthManagement/login              → Bearer Token
   Header: X-Nonce: <nonce>
   Body:   {"username": "Installer", "password": "<passwort>"}
3. GET  /api/v1/ChargingTransactionHistory/ReadFromTo
   Header: Authorization: Bearer <token>
   Params: skip=0&take=100&from=2024-01-01T00:00:00.000Z&to=<jetzt>
```

**Wichtige API-Fallen:**

| Problem | Ursache | Lösung |
|---------|---------|--------|
| HTTP 400 bei Login | Username falsch | Muss exakt `"Installer"` sein (grosses I) |
| HTTP 400 bei History | `orderBy` Parameter | Parameter entfernen, in Python sortieren |
| Timeout bei History | `from=2020-01-01` | Immer `from=2024-01-01` – 2020 hat Test-Sessions |
| Passwort-Fehler | Sonderzeichen | In Shell immer in einfache Quotes: `'...'` |

### Passwort

Das Wallbox-Passwort steht in `/config/python_scripts/run_wallbox_fetch.sh`:
```sh
#!/bin/sh
WALLBOX_PASS='<dein-passwort>' python3 /config/python_scripts/fetch_charging_sessions.py > /config/wallbox_fetch.log 2>&1
```

---

## Modbus Register Referenz

### Lesend (Read-Only)

| Register | Beschreibung | Einheit |
|----------|-------------|---------|
| 100-101 | Firmware Version | ASCII |
| 104 | CP Status (OCPP) | enum 0-9 |
| 105-108 | Error Codes 1-4 | Bitmask |
| 120-121 | Protocol Version | ASCII |
| 122 | Vehicle State | enum 1-5 |
| 142-151 | Chargepoint Model | ASCII |
| 200 | Spannung L1 | V |
| 201 | Spannung L2 | V |
| 202 | Spannung L3 | V |
| 206 | Strom L1 | mA |
| 207 | Strom L2 | mA |
| 208 | Strom L3 | mA |
| 212 | Leistung L1 | W |
| 213 | Leistung L2 | W |
| 214 | Leistung L3 | W |
| 215 | Gesamtleistung | W |
| 216 | Energie L1 | Wh |
| 217 | Energie L2 | Wh |
| 218 | Energie L3 | Wh |
| 219 | Gesamtenergie | Wh |
| 705 | Session Energie | Wh |
| 706-707 | Session Dauer | s (32bit) |
| 720 | Signalisierter Strom | A |
| 722 | Max. Strom EV | A |

### Schreibend (Read/Write)

| Register | Beschreibung | Bereich |
|----------|-------------|---------|
| 124 | CP Availability | 0=unavailable, 1=available |
| 131 | Safe Current | 0-32 A |
| 132 | Comm Timeout | 1-300 s |
| 1000 | HEMS Current Limit | 0=Pause, 6-16 A |

---

## Fallback: Mobilfunk-Zugang

Falls die Wallbox über WLAN nicht erreichbar ist:
- **Mobilfunk-IP**: `10.x.x.x` (GSM-Backup, via SIM-Karte) — falls vorhanden

In `modbus_wallbox.yaml` die `host` ändern:
```yaml
hub:
  - name: "Mennekes AMTRON Wallbox"
    host: 10.x.x.x  # ← Fallback-IP, ersetze mit der echten IP
    port: 502
```

Oder nutze Umgebungsvariablen in `.env`:
```bash
WALLBOX_URL=http://10.x.x.x/api/v1
```

---

## Troubleshooting

### History-Seite friert Browser ein

**Ursache**: `sensor.wallbox_sessions` ist nicht vom Recorder ausgeschlossen. apexcharts-card lädt beim Öffnen die komplette Entity-History (stündliche Updates × grosse JSON-Attribute = MB an Daten).

**Fix**: In `configuration.yaml` unter `recorder:` den Sensor ausschliessen:
```yaml
recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions
```
Danach HA neu starten.

### ApexCharts zeigt leeren Chart / keine Balken

Mögliche Ursachen:
1. `apexcharts-card` nicht installiert (HACS → Frontend)
2. `sensor.wallbox_sessions` hat noch keine Daten → warten bis Fetch abgeschlossen
3. Falscher Chart-Typ: muss `type: column` auf den Series sein (nicht `chart_type: bar` auf Karte-Ebene – nicht in v2.2.3 unterstützt)
4. `graph_span` fehlt → Daten ausserhalb des sichtbaren Zeitfensters

### ApexCharts zeigt "Konfigurationsfehler"

`apexcharts-card v2.2.3` unterstützt nur `chart_type: line/scatter/pie/donut/radialBar` auf Karten-Ebene. Für Balken: `type: column` auf jede Serie setzen, kein `chart_type: bar`.

### sensor.wallbox_sessions zeigt 0 oder erscheint nicht

```bash
# JSON-Datei prüfen
cat /volume1/docker/homeassistant/wallbox_sessions.json | python3 -m json.tool

# Fetch-Log ansehen
cat /volume1/docker/homeassistant/wallbox_fetch.log

# Sensor-Format prüfen: muss top-level command_line sein
# RICHTIG:
command_line:
  - sensor:
      name: "Wallbox Sessions"
# FALSCH (deprecated seit HA 2022.11):
sensor:
  - platform: command_line
```

### Sessions zeigen "Unbekannt" als Fahrzeug

1. Dashboard → Tab "Konfiguration" → "Bekannte Fahrzeuge"
2. RFID aus Tabelle ablesen
3. Im Dropdown "RFID auswählen" die entsprechende RFID wählen
4. Namen eingeben → "Zuweisen & Daten neu laden" drücken

### Wallbox nicht erreichbar

```bash
# WLAN-Verbindung prüfen (ersetze 192.x.x.x mit deiner Wallbox-IP)
ping 192.x.x.x
curl -sf http://192.x.x.x/api/v1/PublicInfo

# Modbus-Port prüfen
nc -zv 192.x.x.x 502

# GSM-Fallback versuchen (falls konfiguriert, ersetze 10.x.x.x)
ping 10.x.x.x
```

### Wallbox-API gibt HTTP 400

- Username muss exakt `"Installer"` sein (grosses I)
- `orderBy` Parameter entfernen
- `from=2024-01-01` verwenden (nicht 2020 → Timeout durch Test-Sessions)

---

## Bekannte RFID-Karten

| RFID | Fahrzeug |
|------|---------|
| `04A5F3D2CC1D90` | Kessi (Tesla) |
| `049D869A5A2294` | Tessi (Tesla) |

---

## Datei-Übersicht

```
/workspace/HA_Menneckes/                    (Quellcode / Entwicklung)
├── README.md                               ← Diese Datei
├── generate_dashboard.py                   ← Dashboard-Generator (Python → JSON)
├── modbus_wallbox.yaml                     ← Modbus TCP Register-Map
├── input_number_wallbox.yaml               ← Numerische Input-Helper
├── input_boolean_wallbox.yaml              ← Boolean Input-Helper
├── input_select_wallbox.yaml               ← Dropdown-Helper (Monat, RFID)
├── input_text_wallbox.yaml                 ← Text-Helper (Fahrzeugnamen, RFIDs)
├── templates/
│   └── wallbox.yaml                        ← Template-Sensoren
├── dashboards/
│   └── wallbox_dashboard.yaml              ← Lovelace Dashboard (generiert)
├── python_scripts/
│   ├── fetch_charging_sessions.py          ← REST API Fetch (Haupt-Script)
│   ├── run_wallbox_fetch.sh                ← Wrapper (Passwort nicht im Repo)
│   ├── write_vehicles.py                   ← Schreibt vehicles.json (4-Slot-Methode)
│   └── assign_vehicle.py                   ← Schreibt vehicles.json (Dropdown-Methode)
├── VERSION
├── LICENSE
└── .gitignore

/workspace/homeassistant/                   (HA Config, live = /config/ im Container)
├── configuration.yaml                      ← Haupt-Config (recorder, command_line, shell_command)
├── automations.yaml                        ← Wallbox-Fetch-Automation
├── scripts.yaml                            ← wallbox_zuweise_fahrzeug + wallbox_aktualisiere_fahrzeuge
├── modbus_wallbox.yaml
├── input_number_wallbox.yaml
├── input_boolean_wallbox.yaml
├── input_select_wallbox.yaml               ← wallbox_month_filter + wallbox_rfid_selector
├── input_text_wallbox.yaml                 ← vehicle_1-4 + vehicle_name_new
├── wallbox_config.json
├── wallbox_vehicles.json
├── wallbox_sessions.json                   ← Generiert vom Fetch, nicht manuell editieren
├── wallbox_fetch.log                       ← Fetch-Log (debug)
├── templates/
│   └── wallbox.yaml                        ← Template-Sensoren + Kosten-Sensoren
├── python_scripts/
│   ├── fetch_charging_sessions.py
│   ├── run_wallbox_fetch.sh
│   ├── write_vehicles.py
│   └── assign_vehicle.py
└── .storage/
    └── lovelace.dashboard_wallbox          ← Lovelace Dashboard JSON
```

### Dashboard neu generieren

Wenn `generate_dashboard.py` geändert wird:
```bash
cd /workspace/HA_Menneckes
python3 generate_dashboard.py > /workspace/homeassistant/.storage/lovelace.dashboard_wallbox
# Kein HA-Neustart nötig – Browser Shift+F5 reicht
```

---

## Version & Letztes Update

- **HA-Version**: 2026.5.4 (minimum: 2026.1.0)
- **Wallbox-Firmware**: 1.5.41 (getestet)
- **apexcharts-card**: 2.2.3 (für Dashboard erforderlich)
- **Python**: 3.9+ (bereits in HA enthalten)
- **Letztes Update**: 2026-06-24
- **Getestet**: Modbus TCP ✓, REST API ✓, Fahrzeug-Mapping (Dropdown) ✓, Kostberechnung ✓, ApexCharts Chart ✓, Recorder-Ausschluss ✓

---

## 📋 Bekannte Limitierungen & Support

### Supported Wallboxes
- ✅ **Mennekes AMTRON 4Business 730 11 C2** (getestet, vollständig unterstützt)
- ⚠️ Andere AMTRON-Modelle (können funktionieren – keine Gewähr)
- ❌ Andere Mennekes-Modelle (nicht getestet)

### Known Limitations
1. **Nur Mennekes AMTRON 730**: Integration ist hardcoded auf dieses Modell optimiert
2. **Modbus Register**: Basierend auf Firmware 1.5.41 – neuere Versionen können andere Register haben
3. **REST API**: Benötigt Installer-Passwort (nicht User-Passwort)
4. **Dashboard**: Benötigt `apexcharts-card` vom HACS

### Troubleshooting

Vor dem Support bitte prüfen:
1. **Logs anschauen**: Settings → System → Logs (suche nach "wallbox")
2. **diagnose.sh Script laufen**: `bash diagnose.sh`
3. **QUICKSTART.md und README.md lesen** (umfangreiche Lösungsanleitungen vorhanden)

---

## 🤝 Community & Support

- **GitHub Issues**: [nobelp/mennekes-amtron-ha/issues](https://github.com/nobelp/mennekes-amtron-ha/issues)
- **Home Assistant Community**: [Home Assistant Discourse](https://discourse.home-assistant.io)
- **Documentation**: Siehe `README.md`, `QUICKSTART.md`, `SYSTEMLOGS_SETUP.md`

---

## 📝 Changelog & Versioning

Siehe [CHANGELOG.md](CHANGELOG.md) für komplette Änderungshistorie.

**Versionierung**: Semantic Versioning (MAJOR.MINOR.PATCH)
- `MAJOR`: Breaking changes
- `MINOR`: Neue Features
- `PATCH`: Bugfixes

---

## 📜 Lizenz

MIT License – Siehe [LICENSE](LICENSE) für Details.

Copyright © 2026 nobelp
