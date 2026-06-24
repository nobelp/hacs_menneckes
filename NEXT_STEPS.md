# ✅ ALLES ERLEDIGT – JETZT DEIN JOB!

Ich habe alles vorbereitet. Jetzt brauchst du nur noch folgende Schritte machen:

---

## 📋 Was wurde gemacht (Workspace)

- ✅ `.env` Datei mit deinem Passwort erstellt
- ✅ `fetch_system_logs.py` aktualisiert (REST API statt HTML-Scraping)
- ✅ `configuration.yaml.complete` erstellt (komplette Vorlage)
- ✅ `QUICKSTART.md` geschrieben (Step-by-Step Anleitung)
- ✅ `diagnose.sh` Script erstellt (zum Überprüfen)
- ✅ `SYSTEMLOGS_SETUP.md` für Systemlogs (Sysstemlogs abrufen Button)

---

## 🚀 Dein Action Plan (ca. 10 Minuten)

### Schritt 1: Dateien nach Home Assistant kopieren

SSH zu deinem HA-Container:
```bash
# Oder nutze deinen SSH-Client (z.B. Putty, Terminal)
ssh admin@192.x.x.x  # ersetze 192.x.x.x mit deiner HA-IP
# Falls auf Synology Docker:
ssh admin@synology.local
sudo docker exec -it homeassistant bash
```

Dann **alle** Dateien kopieren:
```bash
# Von /workspace/HA_Menneckes nach /config/
cp /workspace/HA_Menneckes/.env /config/
cp /workspace/HA_Menneckes/modbus_wallbox.yaml /config/
cp /workspace/HA_Menneckes/input_text_wallbox.yaml /config/
cp /workspace/HA_Menneckes/input_number_wallbox.yaml /config/
cp /workspace/HA_Menneckes/input_boolean_wallbox.yaml /config/
cp /workspace/HA_Menneckes/input_select_wallbox.yaml /config/
cp /workspace/HA_Menneckes/templates/wallbox.yaml /config/templates/

cp /workspace/HA_Menneckes/python_scripts/*.py /config/python_scripts/
cp /workspace/HA_Menneckes/python_scripts/*.sh /config/python_scripts/
chmod +x /config/python_scripts/*.py /config/python_scripts/*.sh
```

### Schritt 2: configuration.yaml anpassen

Öffne `/config/configuration.yaml` (im Editor oder per SSH):

**Füge diese Blöcke hinzu:**
```yaml
# WALLBOX CONFIGURATION - KOPIEREN!
recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions

input_text: !include input_text_wallbox.yaml
input_number: !include input_number_wallbox.yaml
input_boolean: !include input_boolean_wallbox.yaml
input_select: !include input_select_wallbox.yaml

modbus: !include modbus_wallbox.yaml

# ... (siehe configuration.yaml.complete für command_line, shell_command, template)
```

**WICHTIG**: Kopiere ALLES aus `configuration.yaml.complete` in deine `configuration.yaml`, aber:
- ERSETZE NICHT deine existierenden Einstellungen
- ERSETZE NUR die Wallbox-Teile
- ACHTE auf die Indentation (YAML-Format)

### Schritt 3: Home Assistant neu starten

Im HA-UI:
1. Settings → System
2. "Restart Home Assistant" Button
3. Warten Sie 30 Sekunden

### Schritt 4: Überprüfen, dass alles funktioniert

Im HA-UI, gehe zu:
**Settings → Devices & Services → Helper → Input Text**

Du solltest sehen:
- ✅ `wallbox_vehicle_1_rfid` (Status: ON)
- ✅ `wallbox_vehicle_1_name` (Status: ON)
- ✅ usw.

**Wenn "unavailable":**
1. Überprüfe die HA-Logs: **Settings → System → Logs**
2. Suche nach "input_text"
3. Schau nach YAML-Fehlern
4. Löse den Fehler
5. Reload: **Developer Tools → Services → "YAML: Reload Helpers"**

### Schritt 5: Dashboard neu generieren

```bash
# Im SSH:
cd /workspace/HA_Menneckes
python3 generate_dashboard.py > /config/.storage/lovelace.dashboard_wallbox
```

Dann im HA-UI den Browser neu laden (F5).

---

## 🧪 Jetzt testen!

Öffne das Wallbox-Dashboard unter: `/dashboard-wallbox/`

Gehe zum **Konfiguration** Tab und teste:

1. **"Zuweisen & Daten neu laden"** Button
   - Sollte funktionieren (Knopf wird blau/weiß, nicht grau)

2. **"Alle 4 Slots speichern & neu laden"** Button
   - Sollte funktionieren

3. **Manuelle RFID-Verwaltung (4 Slots)**
   - Sollte Eingabefelder zeigen (nicht "unavailable")

4. **"Sysstemlogs abrufen"** Button (falls hinzugefügt)
   - Sollte Systemlogs zeigen (nicht "0 / 0")

---

## 🐛 Falls Fehler auftauchen

Nutze das Diagnose-Script:
```bash
chmod +x /workspace/HA_Menneckes/diagnose.sh
/workspace/HA_Menneckes/diagnose.sh
```

Das zeigt dir, welche Dateien fehlen oder nicht richtig konfiguriert sind.

---

## 📚 Weitere Ressourcen

- `QUICKSTART.md` - Detaillierte Step-by-Step Anleitung
- `SYSTEMLOGS_SETUP.md` - Wie man Systemlogs einrichtet
- `README.md` - Vollständige Dokumentation
- `configuration.yaml.complete` - Komplette Vorlage

---

## ✨ Was wird funktionieren:

Sobald alles konfiguriert ist:

1. ✅ **Echtzeit-Monitoring** (Spannung, Strom, Leistung)
2. ✅ **Ladevorgänge-Historie** (mit Kosten in CHF)
3. ✅ **RFID-Fahrzeug-Zuordnung** (manuell editierbar)
4. ✅ **ApexCharts Diagramm** (Monatsverbrauch)
5. ✅ **Systemlogs** (wenn der Button hinzugefügt wird)
6. ✅ **Steuerung** (HEMS-Limit, Safe Current, Pause)

---

## 💡 Pro-Tips

- **Automatische Updates**: Automation in `automations.yaml` hinzufügen
  - Ladevorgänge stündlich abrufen
  - Systemlogs alle 30 Min
  
- **Fehleranalyse**: `Developer Tools → States` nutzen um die Sensor-Werte zu prüfen

- **Performance**: `sensor.wallbox_sessions` ist NICHT im Recorder eingeschlossen (verhindert Freeze)

---

## 🎯 Fertig?

Wenn alles lädt und funktioniert – **GLÜCKWUNSCH!** 🎉

Du kannst nun:
- Fahrzeuge mit RFID verwalten
- Ladevorgänge tracken
- Kosten überwachen
- Systemlogs abrufen

---

**Viel Erfolg!** 🚗⚡

Bei Fragen: Überprüfe die Logs und nutze das `diagnose.sh` Script!
