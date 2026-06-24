#!/usr/bin/env python3
"""
Schreibt /config/wallbox_vehicles.json aus Umgebungsvariablen.
Aufruf via HA shell_command: RFID1="..." NAME1="..." ... python3 write_vehicles.py

Liest: RFID1..RFID4, NAME1..NAME4 (Umgebungsvariablen)
Schreibt: /config/wallbox_vehicles.json
"""
import os
import json

OUTPUT_FILE = "/config/wallbox_vehicles.json"

mapping = {}
for i in range(1, 5):
    rfid = os.environ.get(f"RFID{i}", "").strip()
    name = os.environ.get(f"NAME{i}", "").strip()
    if rfid and name and rfid not in ("unknown", "none", "None", ""):
        mapping[rfid] = name

with open(OUTPUT_FILE, "w") as f:
    json.dump(mapping, f, indent=2, ensure_ascii=False)

print(f"OK: {len(mapping)} Fahrzeug(e) gespeichert")
for rfid, name in mapping.items():
    print(f"  {rfid} → {name}")
