# ⚡ QUICKSTART – Wallbox + RFID vollständig einrichten

## 🎯 TL;DR (Die schnelle Version)

1. **Passwort in Home Assistant speichern** (Umgebungsvariable)
2. **Dateien kopieren** nach `/config/`
3. **Configuration anpassen** (siehe unten)
4. **HA neu starten**

---

## 📋 Checkliste

### ✅ Vor dem Start
- [ ] Du hast das Installer-Passwort der Wallbox (findest du in der Wallbox Web-UI oder Dokumentation)
- [ ] Du hast SSH-Zugang zu deinem HA (Docker auf Synology?)
- [ ] Du kannst die `/config/configuration.yaml` bearbeiten

### ✅ Schritt 1: Passwort in HA speichern

**Option A: Über Environment Variable (einfach & sicher)**

SSH zu deinem HA-Container:
```bash
ssh user@synology.local
sudo docker exec -it homeassistant bash
```

Dann: Bearbeite `/config/.env`:
```bash
cat > /config/.env << 'EOF'
WALLBOX_PASS=MUSTER_PASSWORD
WALLBOX_URL=http://192.x.x.x/api/v1
EOF
```

Oder einfach mit nano:
```bash
nano /config/.env
# Bearbeite die Werte:
# WALLBOX_PASS=dein-echter-installer-passwort
# WALLBOX_URL=http://192.x.x.x/api/v1 (ersetze 192.x.x.x mit deiner Wallbox-IP)
# Speichern: Ctrl+O, Enter, Ctrl+X
```

**Option B: Über Secrets (traditionell)**

Bearbeite `/config/secrets.yaml`:
```yaml
wallbox_pass: "MUSTER_PASSWORD"  # Ersetze mit deinem echten Passwort
```

Dann in `configuration.yaml` nutzen:
```yaml
shell_command:
  wallbox_fetch_system_events: >-
    WALLBOX_PASS={{ secrets.wallbox_pass }}
    python3 /config/python_scripts/fetch_system_events.py
```

### ✅ Schritt 2: Dateien kopieren

```bash
# Python-Scripts
cp python_scripts/fetch_charging_sessions.py /config/python_scripts/
cp python_scripts/fetch_system_events.py /config/python_scripts/
cp python_scripts/fetch_system_logs.py /config/python_scripts/
cp python_scripts/run_wallbox_fetch.sh /config/python_scripts/
cp python_scripts/write_vehicles.py /config/python_scripts/
cp python_scripts/assign_vehicle.py /config/python_scripts/

# YAML-Konfigurationen
cp modbus_wallbox.yaml /config/
cp input_text_wallbox.yaml /config/
cp input_number_wallbox.yaml /config/
cp input_boolean_wallbox.yaml /config/
cp input_select_wallbox.yaml /config/

# Templates
cp templates/wallbox.yaml /config/templates/

# Dashboard
python3 generate_dashboard.py > /config/.storage/lovelace.dashboard_wallbox
```

### ✅ Schritt 3: configuration.yaml anpassen

Öffne `/config/configuration.yaml` und überprüfe, dass FOLGENDES existiert:

```yaml
# DIESE BLÖCKE MÜSSEN VORHANDEN SEIN:

recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions

input_text: !include input_text_wallbox.yaml
input_number: !include input_number_wallbox.yaml
input_boolean: !include input_boolean_wallbox.yaml
input_select: !include input_select_wallbox.yaml

modbus: !include modbus_wallbox.yaml

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

  - sensor:
      name: "Wallbox System Events"
      unique_id: wallbox_system_events
      command: "WALLBOX_PASS=$WALLBOX_PASS python3 /config/python_scripts/fetch_system_events.py"
      value_template: "{{ value_json.count | int(0) }}"
      json_attributes:
        - events
        - last_update
        - error
      scan_interval: 1800

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

  wallbox_fetch_system_events: >-
    WALLBOX_PASS=$WALLBOX_PASS python3 /config/python_scripts/fetch_system_events.py

template: !include templates/wallbox.yaml
```

### ✅ Schritt 4: HA neu starten

Im HA-UI: **Settings → System → Restart Home Assistant**

### ✅ Schritt 5: Überprüfen, dass alles funktioniert

Öffne: **Settings → Devices & Services → Helper → Input Text**

Du solltest sehen:
- ✅ `wallbox_vehicle_1_rfid` → Status: "ON" (grün)
- ✅ `wallbox_vehicle_1_name` → Status: "ON" (grün)
- ✅ `wallbox_vehicle_2_rfid` → Status: "ON" (grün)
- ✅ usw.

**WENN SIE "unavailable" ZEIGEN:**
- Der `!include` in `configuration.yaml` funktioniert nicht
- Die YAML-Dateien sind nicht im richtigen Format
- Es gibt einen YAML-Fehler → Schaue in die HA-Logs: **Settings → System → Logs**

---

## 🐛 Fehlerbehebung

### Fehler: "Input Text entities sind unavailable"

**Schritt 1**: Überprüfe die Logs
```
Settings → System → Logs → Suche nach "input_text"
```

**Schritt 2**: Überprüfe die YAML-Syntax
```bash
# In SSH:
python3 -m yaml /config/input_text_wallbox.yaml
```

**Schritt 3**: Manueller Reload
```
Developer Tools → Services → Suche "reload"
→ "YAML: Reload Helpers" ausführen
```

### Fehler: "RFID-Felder zeigen 'unknown' oder leer"

Das ist **normal** beim ersten Start! Die Felder werden gefüllt, wenn:
1. Das Script `fetch_charging_sessions.py` läuft (beim Start oder stündlich)
2. Es Ladevorgänge in der Wallbox gibt

### Fehler: "Wallbox nicht erreichbar"

```bash
# In SSH testen (ersetze 192.x.x.x mit deiner Wallbox-IP):
curl -I http://192.x.x.x/system/events
# Sollte HTTP 200 zurückgeben
```

---

## 🎉 Erfolg-Indikatoren

Wenn du folgendes siehst, funktioniert alles:

1. ✅ Dashboard lädt ohne "unavailable" Felder
2. ✅ "Zuweisen & Daten neu laden" Button funktioniert
3. ✅ "Alle 4 Slots speichern & neu laden" Button funktioniert
4. ✅ "Sysstemlogs abrufen" zeigt Logs (nicht "0 / 0")
5. ✅ RFID-Felder zeigen die tatsächlichen Fahrzeug-RFIDs (nicht "unknown")

---

## 📞 Support

Wenn etwas nicht funktioniert:
1. Schreibe die Fehlermeldung auf (HA Logs)
2. Überprüfe die YAML-Syntax
3. Starte HA neu
4. Warte 5 Minuten (Scripts brauchen Zeit)

**Viel Erfolg!** 🚗⚡
