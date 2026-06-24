# Systemlogs in Home Assistant einrichten – Schritt-für-Schritt

**Problem**: Der Button "Sysstemlogs abrufen" zeigt "0 / 0 Logs" und "Aktualisiert: never"

**Grund**: Das Script wird nicht korrekt aufgerufen oder das Passwort fehlt.

---

## ✅ Schritt 1: Installer-Passwort der Wallbox finden

1. Öffne die Wallbox-Web-UI: `http://192.x.x.x` (ersetze mit deiner Wallbox-IP)
2. Gehe zu **Settings → Security** (oder **Administration → Users**)
3. Suche nach dem **Installer-Passwort** (nicht das User-Passwort!)
4. Notiere es und verwende es in den folgenden Schritten

---

## ✅ Schritt 2: Passwort in Home Assistant speichern

### Option A: Umgebungsvariable (sicherer)

Bearbeite `/config/.env`:
```bash
WALLBOX_PASS=MUSTER_PASSWORD  # Ersetze mit deinem echten Installer-Passwort
WALLBOX_URL=http://192.x.x.x/api/v1  # Ersetze 192.x.x.x mit deiner Wallbox-IP
```

Dann starte HA neu: Settings → System → Restart

### Option B: Secrets.yaml (traditionell)

Bearbeite `/config/secrets.yaml`:
```yaml
wallbox_pass: MUSTER_PASSWORD  # Ersetze mit deinem echten Installer-Passwort
```

In `configuration.yaml` nutzen:
```yaml
shell_command:
  wallbox_fetch_system_events: >-
    WALLBOX_PASS={{ states.input_text.wallbox_pass }}
    python3 /config/python_scripts/fetch_system_events.py
```

---

## ✅ Schritt 3: Home Assistant konfigurieren

Kopiere diese Zeilen in deine `configuration.yaml`:

```yaml
# 1. Umgebungsvariable am Start laden
homeassistant:
  # ... existierende Einstellungen ...
  extra_config_path: /config

# 2. Input Helper (optional – zum Passwort speichern ohne .env)
input_text:
  wallbox_pass:
    name: Wallbox Installer Password
    icon: mdi:lock
    mode: password
    initial: ""

# 3. Command-Line Sensor (für regelmäßige Updates)
command_line:
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

# 4. Shell Command (zum Manuell abrufen)
shell_command:
  wallbox_fetch_system_events: >-
    WALLBOX_PASS=$WALLBOX_PASS python3 /config/python_scripts/fetch_system_events.py
```

---

## ✅ Schritt 4: Python-Script kopieren

```bash
cp /workspace/HA_Menneckes/python_scripts/fetch_system_events.py /config/python_scripts/
cp /workspace/HA_Menneckes/python_scripts/fetch_system_logs.py /config/python_scripts/
```

---

## ✅ Schritt 5: Dashboard-Button hinzufügen

Öffne dein Wallbox-Dashboard im Editor (oben rechts: ⋮ → Edit dashboard) und füge diese Karte hinzu:

```yaml
- type: button
  name: Systemlogs abrufen
  icon: mdi:bug-check
  tap_action:
    action: call-service
    service: shell_command.wallbox_fetch_system_events
```

Speichern → Die Karte sollte jetzt funktionieren!

---

## ✅ Schritt 6: Testen

1. Klicke auf den Button "Systemlogs abrufen"
2. Öffne die Browser-Konsole (F12) → schaue nach Fehlern
3. Prüfe die Home Assistant Logs: Settings → System → Logs
4. Suche nach Fehlern wie `WALLBOX_PASS`, `401`, `connection refused`

---

## 🐛 Fehlerbehebung

### Fehler: "No password provided"
- `.env` ist nicht geladen
- **Lösung**: `/config` neustarten oder `WALLBOX_PASS=xxx` direkt in den shell_command schreiben

### Fehler: "Login failed"
- Passwort ist falsch
- **Lösung**: Passwort in der Wallbox nochmal überprüfen

### Fehler: "Connection refused"
- Wallbox ist nicht erreichbar
- **Lösung**: Prüfe die IP-Adresse in `WALLBOX_URL` und Netzwerk-Verbindung

### Button zeigt immer noch "0 / 0 Logs"
- Script läuft, aber schreibt nicht nach `/config/wallbox_system_logs.json`
- **Lösung**: Prüfe die Datei-Permissions: `chmod 755 /config/python_scripts/fetch_system_events.py`

---

## 📝 Regelmäßige Updates einrichten (optional)

Füge diese Automation hinzu (in `automations.yaml`):

```yaml
- id: 'wallbox_fetch_events_hourly'
  alias: Wallbox System Events (stündlich)
  triggers:
  - event: start
    trigger: homeassistant
  - trigger: time_pattern
    minutes: 0
  actions:
  - action: shell_command.wallbox_fetch_system_events
    data: {}
```

Dann werden die Logs automatisch jede Stunde aktualisiert.
