Mennekes AMTRON Wallbox – Home Assistant Integration

[![HACS](https://img.shields.io/badge/HACS-Custom-orange.svg)](https://github.com/hacs/integration)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Complete integration of a Mennekes AMTRON Wallbox in Home Assistant with real-time Modbus TCP monitoring, REST API charging session tracking, RFID vehicle identification, and comprehensive cost management.

## Key Features

- **Real-time Monitoring**: Voltage, current, power per phase via Modbus TCP
- **Charging History**: Complete session tracking via REST API with RFID vehicle identification
- **Cost Management**: Configurable electricity rates with cost calculation per vehicle
- **Dashboard**: ApexCharts visualization with real-time overview, historical analysis, and configuration management
- **Vehicle Management**: Automatic RFID detection with manual override capabilities
- **Advanced Control**: HEMS limit configuration, Safe Current settings, availability control, and charging pause functionality

## Installation

### Via HACS (Recommended)

1. Open Home Assistant
2. Navigate to **HACS** → **Automations**
3. Click **"Explore & Download Repositories"**
4. Search for **"Mennekes AMTRON"**
5. Click **"Install"**
6. **Restart Home Assistant**

### Manual Installation

Clone the repository and copy files to your Home Assistant configuration:

```bash
git clone https://github.com/nobelp/hacs_menneckes.git
cp -r hacs_menneckes/* /config/
Quick Start Guide
Step 1: Environment Configuration
Create .env file from template:
bash
Kopieren
cp .env.example .env
`Edit `.env` with your wallbox credentials:`bash
WALLBOX_URL=http://192.168.x.x/api/v1
WALLBOX_PASS=your-installer-password
HA_HOST=192.168.x.x
HA_TOKEN=your-long-lived-access-token
`### Step 2: Copy Configuration Files`bash
cp modbus_wallbox.yaml /config/
cp input_*.yaml /config/
cp templates/wallbox.yaml /config/templates/
cp -r python_scripts /config/
Step 3: Update configuration.yaml
Add the following to your Home Assistant configuration:
yaml
Kopieren
# Exclude large JSON sensor from recorder to prevent history freezing
recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions

# Modbus and input helpers configuration
modbus: !include modbus_wallbox.yaml
input_number: !include input_number_wallbox.yaml
input_boolean: !include input_boolean_wallbox.yaml
input_select: !include input_select_wallbox.yaml
input_text: !include input_text_wallbox.yaml

# Command line sensors for wallbox data
command_line:
  - sensor:
      name: "Wallbox Sessions"
      unique_id: wallbox_sessions
      command: "cat /config/wallbox_sessions.json 2>/dev/null || echo '{}'"
      value_template: "{{ value_json.count | int(0) }}"
      json_attributes:
        - sessions
        - monthly_summary
        - vehicle_totals
      scan_interval: 3600

# Shell command for fetching sessions
shell_command:
  wallbox_fetch_sessions: "/bin/sh /config/python_scripts/run_wallbox_fetch.sh"
Step 4: Add Automation
Add to automations.yaml:
yaml
Kopieren
- id: '1780407000000'
  alias: Update Wallbox Charging Sessions
  description: Fetches sessions from Wallbox API (hourly and on startup)
  triggers:
  - event: start
    trigger: homeassistant
  - trigger: time_pattern
    hours: /1
  actions:
  - action: shell_command.wallbox_fetch_sessions
  - action: homeassistant.update_entity
    target:
      entity_id: sensor.wallbox_sessions
  mode: single
Step 5: Restart Home Assistant
Settings → System → Restart
Home Assistant Entities
Sensors (Modbus TCP)
Entity	Description	Unit
sensor.wallbox_charging_status	Current charging status	-
sensor.wallbox_vehicle_state_text	Vehicle state (A-E)	-
sensor.wallbox_total_power	Total power consumption	W
sensor.wallbox_total_energy_kwh	Session energy	kWh
sensor.meter_voltage_l1/l2/l3	Phase voltage	V
sensor.wallbox_current_l1/l2/l3_ampere	Phase current	A
sensor.wallbox_sessions	Charging sessions (JSON)	-
Input Numbers (Control & Configuration)
Entity	Range	Purpose
input_number.wallbox_price_per_kwh	0.01–2.00	Electricity price (live adjustable)
input_number.wallbox_hems_current_limit	0–16 A	HEMS current limit control
input_number.wallbox_safe_current	0–32 A	Safe current limit
input_number.wallbox_comm_timeout	1–300 s	Communication timeout
Input Booleans (Switches)
Entity	Purpose
input_boolean.wallbox_cp_availability	Wallbox availability control
input_boolean.wallbox_pause_charging	Pause charging immediately
Input Selects (Dropdowns)
Entity	Purpose
input_select.wallbox_month_filter	Filter dashboard by month
input_select.wallbox_rfid_selector	Select RFID for vehicle assignment
Configuration Files
wallbox_config.json
Electricity price configuration:
json
Kopieren
{
  "price_per_kwh_chf": 0.29
}
This price is used for cost calculations in charging sessions.
wallbox_vehicles.json
RFID to vehicle name mapping:
json
Kopieren
{
  "04A5F3D2CC1D90": "Tesla Model 3",
  "049D869A5A2294": "Tesla Model Y"
}
Automatically populated when wallbox detects new RFID tags.
Dashboard
Access the wallbox dashboard at: /dashboard-wallbox/
Tab 1: Overview
Real-time monitoring with:
Charging status and vehicle information
Voltage, current, power per phase
HEMS limits and Safe Current values
Error codes and diagnostics
Tab 2: History
Charging session analysis:
Monthly consumption statistics
ApexCharts visualization by vehicle
Session-by-session details with costs
Monthly totals and vehicle summaries
Tab 3: Configuration
Management interface:
Vehicle RFID assignment
Electricity price adjustment
Known vehicles listing
Manual configuration options
Troubleshooting
History Page Freezes
Cause: Large JSON attributes in sensor.wallbox_sessions being loaded from history
Solution: Ensure recorder exclusion in configuration.yaml:
yaml
Kopieren
recorder:
  exclude:
    entities:
      - sensor.wallbox_sessions
Then restart Home Assistant.
No Data Showing
Checklist:
Verify .env file has correct WALLBOX_URL and WALLBOX_PASS
Test wallbox connectivity: ping 192.168.x.x
Check fetch log: tail /config/wallbox_fetch.log
Verify Python scripts have execute permissions: chmod +x /config/python_scripts/*.sh
Wallbox Not Reachable
Test network connectivity:
bash
Kopieren
# Check WiFi connection
ping 192.168.x.x

# Check Modbus TCP port
nc -zv 192.168.x.x 502

# Try GSM fallback (if configured)
ping 10.x.x.x
API Returns HTTP 400
Common API issues:
Username wrong: Must be exactly "Installer" (capital I)
orderBy parameter: Remove any orderBy parameters
Old dates: Use from=2024-01-01 (not 2020 to avoid timeouts)
Hardware Requirements
Wallbox Model: Mennekes AMTRON 4Business 730 11 C2
Firmware Version: 1.5.41+
Home Assistant: 2024.1.0+
Network: TCP:502 (Modbus) and TCP:80 (REST API)
Network: Wallbox must be reachable from Home Assistant host
API Reference
REST API Authentication

Kopieren
1. GET  /api/v1/Nonce?nocache=<timestamp>        → Nonce string
2. POST /api/v1/AuthManagement/login              → Bearer token
   Header: X-Nonce: <nonce>
   Body:   {"username": "Installer", "password": "<password>"}
3. GET  /api/v1/ChargingTransactionHistory/ReadFromTo
   Header: Authorization: Bearer <token>
   Params: skip=0&take=100&from=2024-01-01&to=<now>
Modbus TCP Registers
Read-Only Registers:
100-101: Firmware version
200-202: Voltage L1/L2/L3
206-208: Current L1/L2/L3
215: Total power
219: Total energy
Read/Write Registers:
124: CP availability (0=unavailable, 1=available)
131: Safe current (0-32 A)
1000: HEMS current limit (0-16 A)
Support & Contributing
Report Issues
GitHub Issues: Open an issue
Discussions: Ask questions
Home Assistant Community
Community Forums: Home Assistant Discussions
License
This project is licensed under the MIT License – See LICENSE file for details.
Changelog
See CHANGELOG.md for version history and updates.
Made with ❤️ for Home Assistant
