#!/usr/bin/env python3
"""
Mennekes AMTRON - Systemereignisse via REST API holen.
Speichert JSON nach /config/wallbox_system_events.json.
"""

import sys
import os
import json
import time
import urllib.request
import urllib.parse
from datetime import datetime, timezone

BASE_URL = os.environ.get("WALLBOX_URL") or "http://192.x.x.x/api/v1"  # Replace 192.x.x.x with your Wallbox IP
OUTPUT_FILE = "/config/wallbox_system_events.json"

def get_nonce():
    with urllib.request.urlopen(f"{BASE_URL}/Nonce?nocache={time.time()}", timeout=10) as r:
        return r.read().decode().strip()

def login(password):
    nonce = get_nonce()
    payload = json.dumps({"username": "Installer", "password": password}).encode()
    req = urllib.request.Request(
        f"{BASE_URL}/AuthManagement/login",
        data=payload,
        headers={"Content-Type": "application/json", "X-Nonce": nonce},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        data = json.loads(r.read().decode())
        return data.get("token") or data.get("accessToken") or data.get("access_token")

def get_system_events(token):
    nonce = get_nonce()
    url = f"{BASE_URL}/SystemManagement/SystemEvents"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "X-Nonce": nonce,
        "Cache-Control": "no-cache",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())

def main():
    password = os.environ.get("WALLBOX_PASS") or (sys.argv[1] if len(sys.argv) > 1 else "")
    if not password:
        result = {"error": "No password", "events": [], "count": 0}
        print(json.dumps(result))
        sys.exit(1)

    try:
        token = login(password)
        if not token:
            result = {"error": "Login failed", "events": [], "count": 0}
            print(json.dumps(result))
            sys.exit(1)

        data = get_system_events(token)
        items = data if isinstance(data, list) else data.get("list", data.get("items", data.get("data", data.get("systemEvents", []))))

        events = []
        for e in items:
            timestamp = e.get("timestamp") or e.get("time") or ""
            event_id = e.get("eventId") or e.get("id") or ""
            level = e.get("level") or e.get("severity") or "INFO"
            description = e.get("description") or e.get("message") or ""

            events.append({
                "timestamp": timestamp,
                "event_id": event_id,
                "level": level,
                "description": description,
                "details": e
            })

        events.sort(key=lambda x: x.get("timestamp") or "", reverse=True)

        result = {
            "count": len(events),
            "events": events,
            "last_update": datetime.now(timezone.utc).isoformat()
        }

        with open(OUTPUT_FILE, "w") as f:
            json.dump(result, f, indent=2)

        print(json.dumps(result))

    except Exception as e:
        result = {"error": str(e), "events": [], "count": 0}
        print(json.dumps(result), file=sys.stderr)
        print(json.dumps(result))
        sys.exit(1)

if __name__ == "__main__":
    main()
