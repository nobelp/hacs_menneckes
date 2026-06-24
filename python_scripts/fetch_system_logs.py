#!/usr/bin/env python3
"""
Mennekes AMTRON - Systemlogs aus Transaktionsdaten generieren.
Die API hat keinen /SystemManagement/SystemEvents Endpunkt (404 auf Firmware 1.5.41).
Stattdessen werden aus ChargingTransactionHistory detaillierte Log-Eintraege erstellt.
"""

import sys, os, json, time, urllib.request, urllib.parse
from datetime import datetime, timezone

BASE_URL = os.environ.get("WALLBOX_URL") or "http://192.x.x.x/api/v1"  # Replace 192.x.x.x with your Wallbox IP
OUTPUT_FILE = "/config/wallbox_system_logs.json"
VEHICLES_FILE = "/config/wallbox_vehicles.json"


def get_nonce():
    with urllib.request.urlopen(f"{BASE_URL}/Nonce?nocache={time.time()}", timeout=10) as r:
        return r.read().decode().strip()


def login(password):
    nonce = get_nonce()
    payload = json.dumps({"username": "Installer", "password": password}).encode()
    req = urllib.request.Request(
        f"{BASE_URL}/AuthManagement/login", data=payload,
        headers={"Content-Type": "application/json", "X-Nonce": nonce}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        d = json.loads(r.read().decode())
        return d.get("token") or d.get("accessToken") or d.get("access_token")


def get_transactions(token):
    nonce = get_nonce()
    params = urllib.parse.urlencode({
        "skip": 0, "take": 200,
        "from": "2024-01-01T00:00:00.000Z",
        "to": datetime.now(timezone.utc).strftime("%Y-%m-%dT23:59:59.999Z"),
    })
    req = urllib.request.Request(
        f"{BASE_URL}/ChargingTransactionHistory/ReadFromTo?{params}",
        headers={"Authorization": f"Bearer {token}", "X-Nonce": nonce, "Cache-Control": "no-cache"}
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())
        return d if isinstance(d, list) else d.get("list", [])


def load_vehicles():
    try:
        with open(VEHICLES_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def tx_to_logs(tx, vehicles):
    rfid = ""
    ut = tx.get("userToken", {})
    if isinstance(ut, dict):
        rfid = ut.get("identifier", "")
    vehicle = vehicles.get(rfid, tx.get("whitelistEntryFirstName") or rfid or "Unbekannt")

    start_status = tx.get("startTransactionStatus", "")
    stop_status  = tx.get("stopTransactionStatus", "")
    stop_reason  = tx.get("stopReason", "")
    aborted      = tx.get("isAborted", False)
    energy       = round(tx.get("chargedEnergy", 0), 3)
    duration     = tx.get("formattedChargedTime", "")
    ocpp_id      = tx.get("ocppTransactionId", "")
    auth         = tx.get("authorizationOption", "")

    logs = []

    # START event
    start_ts = tx.get("startTimestamp", "")
    start_level = "ERROR" if start_status not in ("", "Successful") else "INFO"
    logs.append({
        "timestamp":   start_ts,
        "event_id":    f"TX-{ocpp_id}-START",
        "level":       start_level,
        "description": f"START {vehicle} | RFID: {rfid or '-'} | Auth: {auth} | Status: {start_status or 'OK'}",
        "vehicle":     vehicle,
        "rfid":        rfid,
    })

    # STOP event
    stop_ts = tx.get("stopTimestamp", "")
    if stop_ts:
        normal_stop = stop_reason in ("", "Remote", "Local", "EVDisconnected")
        stop_level  = "ERROR" if aborted else ("WARNING" if not normal_stop else "INFO")
        logs.append({
            "timestamp":   stop_ts,
            "event_id":    f"TX-{ocpp_id}-STOP",
            "level":       stop_level,
            "description": f"STOP {vehicle} | {energy} kWh | {duration} | Grund: {stop_reason or '-'} | Status: {stop_status or 'OK'}{' | ABGEBROCHEN' if aborted else ''}",
            "vehicle":     vehicle,
            "rfid":        rfid,
        })

    return logs


def main():
    password = os.environ.get("WALLBOX_PASS") or (sys.argv[1] if len(sys.argv) > 1 else "")
    if not password:
        result = {"error": "Kein Passwort - WALLBOX_PASS setzen", "logs": [], "count": 0}
        print(json.dumps(result))
        sys.exit(1)

    try:
        vehicles = load_vehicles()
        token = login(password)
        if not token:
            result = {"error": "Login fehlgeschlagen", "logs": [], "count": 0}
            print(json.dumps(result))
            sys.exit(1)

        items = get_transactions(token)
        all_logs = []
        for tx in items:
            all_logs.extend(tx_to_logs(tx, vehicles))

        all_logs.sort(key=lambda x: x.get("timestamp") or "", reverse=True)

        result = {
            "count": len(all_logs),
            "logs":  all_logs[:500],
            "last_update": datetime.now(timezone.utc).isoformat(),
        }

        with open(OUTPUT_FILE, "w") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        print(json.dumps(result))

    except Exception as e:
        result = {"error": str(e), "logs": [], "count": 0}
        print(json.dumps(result), file=sys.stderr)
        print(json.dumps(result))
        sys.exit(1)


if __name__ == "__main__":
    main()
