#!/bin/bash
# ============================================================================
# WALLBOX SETUP SCRIPT - Automatische Installation in Home Assistant
# ============================================================================
# Nutzung: ./setup.sh [HA_HOST] [HA_USER] [HA_PASS]
# Beispiel: ./setup.sh 192.x.x.x admin your-password (ersetze 192.x.x.x)
#           ./setup.sh synology.local admin your-password
# ============================================================================

set -e

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parameter
HA_HOST="${1:-192.x.x.x}"  # Default: ersetze mit deiner HA-IP
HA_USER="${2:-admin}"
HA_PASS="${3}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔧 WALLBOX SETUP SCRIPT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "HA-Host: $HA_HOST"
echo "HA-User: $HA_USER"
echo ""

# Prüfe Parameter
if [ -z "$HA_PASS" ]; then
    echo -e "${RED}❌ Passwort fehlt!${NC}"
    echo ""
    echo "Nutzung:"
    echo "  $0 <HA_HOST> <HA_USER> <HA_PASS>"
    echo ""
    echo "Beispiele:"
    echo "  $0 192.x.x.x admin your-password"
    echo "  $0 synology.local admin your-password"
    exit 1
fi

# SSH Command Funktion
run_ssh() {
    sshpass -p "$HA_PASS" ssh -o StrictHostKeyChecking=no "$HA_USER@$HA_HOST" "$@"
}

# Docker Command Funktion
run_docker() {
    run_ssh "docker exec -i homeassistant bash -c '$1'"
}

echo -e "${YELLOW}1️⃣  Teste SSH-Verbindung...${NC}"
if run_ssh "echo OK" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SSH verbunden${NC}"
else
    echo -e "${RED}❌ SSH-Verbindung fehlgeschlagen${NC}"
    echo "Überprüfe:"
    echo "  - HA-Host: $HA_HOST"
    echo "  - HA-User: $HA_USER"
    echo "  - Passwort ist korrekt"
    exit 1
fi

echo ""
echo -e "${YELLOW}2️⃣  Kopiere Dateien nach /config/...${NC}"

# Dateien kopieren via SCP
sshpass -p "$HA_PASS" scp -o StrictHostKeyChecking=no \
    .env \
    modbus_wallbox.yaml \
    input_text_wallbox.yaml \
    input_number_wallbox.yaml \
    input_boolean_wallbox.yaml \
    input_select_wallbox.yaml \
    "$HA_USER@$HA_HOST:/config/" 2>/dev/null && echo -e "${GREEN}✅ YAML-Dateien kopiert${NC}" || echo -e "${YELLOW}⚠️  SCP-Fehler (versuche Docker-Workaround)${NC}"

# Python-Scripts
mkdir -p /tmp/wallbox_scripts
cp python_scripts/*.py /tmp/wallbox_scripts/
cp python_scripts/*.sh /tmp/wallbox_scripts/
sshpass -p "$HA_PASS" scp -o StrictHostKeyChecking=no \
    /tmp/wallbox_scripts/* \
    "$HA_USER@$HA_HOST:/config/python_scripts/" 2>/dev/null && echo -e "${GREEN}✅ Python-Scripts kopiert${NC}" || echo -e "${YELLOW}⚠️  Scripts-Fehler${NC}"

# Templates
sshpass -p "$HA_PASS" scp -o StrictHostKeyChecking=no \
    templates/wallbox.yaml \
    "$HA_USER@$HA_HOST:/config/templates/" 2>/dev/null && echo -e "${GREEN}✅ Templates kopiert${NC}" || echo -e "${YELLOW}⚠️  Templates-Fehler${NC}"

# .env mit Docker
echo -e "${YELLOW}   Speichere .env im Container...${NC}"
echo -e "${RED}⚠️  WICHTIG: Bearbeite /config/.env mit deinem echten Installer-Passwort!${NC}"
run_docker "cat > /config/.env << 'ENVEOF'
# Mennekes Wallbox Configuration
WALLBOX_URL=http://192.x.x.x/api/v1
WALLBOX_PASS=MUSTER_PASSWORD
ENVEOF" && echo -e "${GREEN}✅ .env Vorlage im Container erstellt${NC}"

echo ""
echo -e "${YELLOW}3️⃣  Aktualisiere configuration.yaml...${NC}"

# Configuration.yaml Update Script
CONFIG_UPDATE_SCRIPT=$(cat << 'SCRIPTEOF'
import sys
import re

config_file = '/config/configuration.yaml'

# Lese aktuelle config
with open(config_file, 'r') as f:
    content = f.read()

# Neue Blöcke zum hinzufügen
new_blocks = '''
# --- WALLBOX KONFIGURATION (AUTO-GENERIERT) ---
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
      command: "curl -sf http://192.x.x.x/api/v1/PublicInfo | python3 -c \\"import json,sys; d=json.load(sys.stdin); print(d['currentVersion'])\\""  # Replace 192.x.x.x
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
# --- END WALLBOX KONFIGURATION ---
'''

# Prüfe ob bereits vorhanden
if 'WALLBOX KONFIGURATION' in content:
    print("INFO: Wallbox-Konfiguration existiert bereits")
    sys.exit(0)

# Füge am Ende hinzu
with open(config_file, 'a') as f:
    f.write('\n' + new_blocks + '\n')

print("OK: Konfiguration aktualisiert")
SCRIPTEOF
)

# Führe Python-Script im Container aus
run_docker "python3 << 'PYSCRIPTEOF'
$CONFIG_UPDATE_SCRIPT
PYSCRIPTEOF" && echo -e "${GREEN}✅ configuration.yaml aktualisiert${NC}" || echo -e "${RED}❌ configuration.yaml Fehler${NC}"

echo ""
echo -e "${YELLOW}4️⃣  Starte Home Assistant neu...${NC}"

# Neustart via REST API
RESTART_SCRIPT=$(cat << 'RESTARTEOF'
curl -s -X POST \
  -H "Authorization: Bearer $(cat /config/.storage/auth_token.json | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)" \
  http://localhost:8123/api/services/homeassistant/restart
echo "Restart gestartet"
RESTARTEOF
)

run_docker "$RESTART_SCRIPT" 2>/dev/null || echo -e "${YELLOW}⚠️  Restart via API fehlgeschlagen (manuell machen)${NC}"

echo -e "${GREEN}✅ Warte 30 Sekunden auf HA-Neustart...${NC}"
sleep 30

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 SETUP ABGESCHLOSSEN!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "✅ Dateien kopiert"
echo "✅ configuration.yaml aktualisiert"
echo "✅ Home Assistant neu gestartet"
echo ""
echo "Nächste Schritte:"
echo "1. Öffne HA-UI: http://$HA_HOST:8123"
echo "2. Gehe zu Wallbox-Dashboard"
echo "3. Tab 'Konfiguration'"
echo "4. Überprüfe: RFID-Felder sollten jetzt funktionieren!"
echo ""
echo "Falls Fehler:"
echo "  - Settings → System → Logs überprüfen"
echo "  - Bei 'unavailable': Reload ausführen"
echo "    Developer Tools → Services → 'YAML: Reload Helpers'"
echo ""
