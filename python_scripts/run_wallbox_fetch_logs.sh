#!/bin/sh
# Mennekes AMTRON - Systemlogs holen
# Wird via HA shell_command oder command_line sensor aufgerufen
# Password must be set via environment variable WALLBOX_PASS (from .env or secrets)
if [ -z "$WALLBOX_PASS" ]; then
    echo "ERROR: WALLBOX_PASS environment variable not set" >> /config/wallbox_fetch_logs.log
    exit 1
fi
python3 /config/python_scripts/fetch_system_logs.py > /config/wallbox_fetch_logs.log 2>&1
