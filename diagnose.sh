#!/bin/bash
# ============================================================================
# WALLBOX DIAGNOSE SCRIPT
# Überprüft, ob alle Komponenten korrekt installiert und konfiguriert sind
# ============================================================================

echo "🔍 WALLBOX DIAGNOSE SCRIPT"
echo "=================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Test 1: Netzwerk - Wallbox erreichbar?
# Note: Replace 192.x.x.x with your actual Wallbox IP from WALLBOX_URL environment variable
echo ""
echo "📡 Test 1: Wallbox-Netzwerk"
WALLBOX_IP="${WALLBOX_URL#http://}"
WALLBOX_IP="${WALLBOX_IP#*@}"
WALLBOX_IP="${WALLBOX_IP%%/*}"
if timeout 3 curl -s -I "http://${WALLBOX_IP}/system/events" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Wallbox erreichbar (${WALLBOX_IP})${NC}"
else
    echo -e "${RED}❌ Wallbox NICHT erreichbar (${WALLBOX_IP})${NC}"
    echo -e "${YELLOW}ℹ️  Check WALLBOX_URL in .env file${NC}"
    ERRORS=$((ERRORS+1))
fi

# Test 2: Python-Scripts existieren?
echo ""
echo "📁 Test 2: Python-Scripts"
for script in \
    "/config/python_scripts/fetch_charging_sessions.py" \
    "/config/python_scripts/fetch_system_events.py" \
    "/config/python_scripts/fetch_system_logs.py" \
    "/config/python_scripts/write_vehicles.py" \
    "/config/python_scripts/assign_vehicle.py"
do
    if [ -f "$script" ]; then
        echo -e "${GREEN}✅ $(basename $script)${NC}"
    else
        echo -e "${RED}❌ $(basename $script) FEHLT${NC}"
        ERRORS=$((ERRORS+1))
    fi
done

# Test 3: YAML-Dateien vorhanden?
echo ""
echo "📄 Test 3: YAML-Konfigurationen"
for yaml in \
    "/config/modbus_wallbox.yaml" \
    "/config/input_text_wallbox.yaml" \
    "/config/input_number_wallbox.yaml" \
    "/config/input_boolean_wallbox.yaml" \
    "/config/input_select_wallbox.yaml"
do
    if [ -f "$yaml" ]; then
        echo -e "${GREEN}✅ $(basename $yaml)${NC}"
    else
        echo -e "${RED}❌ $(basename $yaml) FEHLT${NC}"
        ERRORS=$((ERRORS+1))
    fi
done

# Test 4: Passwort gesetzt?
echo ""
echo "🔐 Test 4: Wallbox-Passwort"
if [ -f "/config/.env" ]; then
    if grep -q "WALLBOX_PASS=" /config/.env; then
        echo -e "${GREEN}✅ .env mit WALLBOX_PASS vorhanden${NC}"
    else
        echo -e "${YELLOW}⚠️  .env existiert, aber WALLBOX_PASS fehlt${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
elif [ -f "/config/secrets.yaml" ]; then
    if grep -q "wallbox_pass:" /config/secrets.yaml; then
        echo -e "${GREEN}✅ secrets.yaml mit wallbox_pass vorhanden${NC}"
    else
        echo -e "${YELLOW}⚠️  secrets.yaml existiert, aber wallbox_pass fehlt${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo -e "${YELLOW}⚠️  Passwort nicht gefunden (.env oder secrets.yaml)${NC}"
    WARNINGS=$((WARNINGS+1))
fi

# Test 5: Configuration.yaml includes
echo ""
echo "⚙️  Test 5: configuration.yaml Includes"
if grep -q "input_text: !include input_text_wallbox.yaml" /config/configuration.yaml; then
    echo -e "${GREEN}✅ input_text include${NC}"
else
    echo -e "${YELLOW}⚠️  input_text include FEHLT${NC}"
    WARNINGS=$((WARNINGS+1))
fi

if grep -q "input_number: !include input_number_wallbox.yaml" /config/configuration.yaml; then
    echo -e "${GREEN}✅ input_number include${NC}"
else
    echo -e "${YELLOW}⚠️  input_number include FEHLT${NC}"
    WARNINGS=$((WARNINGS+1))
fi

if grep -q "modbus: !include modbus_wallbox.yaml" /config/configuration.yaml; then
    echo -e "${GREEN}✅ modbus include${NC}"
else
    echo -e "${YELLOW}⚠️  modbus include FEHLT${NC}"
    WARNINGS=$((WARNINGS+1))
fi

if grep -q "template: !include templates/wallbox.yaml" /config/configuration.yaml; then
    echo -e "${GREEN}✅ template include${NC}"
else
    echo -e "${YELLOW}⚠️  template include FEHLT${NC}"
    WARNINGS=$((WARNINGS+1))
fi

# Test 6: Recorder exclude
echo ""
echo "💾 Test 6: Recorder-Konfiguration"
if grep -q "exclude:" /config/configuration.yaml && grep -q "sensor.wallbox_sessions" /config/configuration.yaml; then
    echo -e "${GREEN}✅ sensor.wallbox_sessions ausgeschlossen${NC}"
else
    echo -e "${YELLOW}⚠️  Recorder-Ausschluss NICHT konfiguriert (kann zu Freezes führen)${NC}"
    WARNINGS=$((WARNINGS+1))
fi

# Test 7: Daten-Dateien
echo ""
echo "📊 Test 7: Daten-Dateien"
if [ -f "/config/wallbox_sessions.json" ]; then
    COUNT=$(python3 -c "import json; f=open('/config/wallbox_sessions.json'); d=json.load(f); print(d.get('count', 0))" 2>/dev/null || echo "?")
    echo -e "${GREEN}✅ wallbox_sessions.json ($COUNT Einträge)${NC}"
else
    echo -e "${YELLOW}⚠️  wallbox_sessions.json nicht vorhanden (wird beim ersten Fetch erstellt)${NC}"
    WARNINGS=$((WARNINGS+1))
fi

if [ -f "/config/wallbox_vehicles.json" ]; then
    echo -e "${GREEN}✅ wallbox_vehicles.json${NC}"
else
    echo -e "${YELLOW}⚠️  wallbox_vehicles.json nicht vorhanden${NC}"
    WARNINGS=$((WARNINGS+1))
fi

# Test 8: Script Permissions
echo ""
echo "🔧 Test 8: Script-Berechtigungen"
for script in /config/python_scripts/*.py /config/python_scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo -e "${GREEN}✅ $(basename $script) executable${NC}"
        else
            echo -e "${YELLOW}⚠️  $(basename $script) NOT executable${NC}"
            WARNINGS=$((WARNINGS+1))
        fi
    fi
done

# Summary
echo ""
echo "=================================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ KEINE KRITISCHEN FEHLER${NC}"
else
    echo -e "${RED}❌ $ERRORS KRITISCHE FEHLER${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS WARNUNGEN${NC}"
fi

echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALLES SIEHT GUT AUS!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Einige optionale Konfigurationen fehlen${NC}"
    echo "Siehe oben für Details."
    exit 0
else
    echo -e "${RED}❌ FEHLER MÜSSEN BEHOBEN WERDEN${NC}"
    exit 1
fi
