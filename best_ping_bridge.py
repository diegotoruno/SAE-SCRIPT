"""Local Roblox BestLatency companion; credentials stay in this process.

The executor exchanges sanitized requests/results through its workspace.
No inbound network listener, browser extraction, or credential forwarding.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

PLACE_ID = 107778070777162
REQUEST_FILE = "sae_best_ping_request.json"
RESPONSE_FILE = "sae_best_ping_response.json"
MAX_AGE = 180
INTERVAL = 15


class NoRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def read_cookie(path):
    value = path.read_text(encoding="utf-8-sig").strip()
    if value.startswith(".ROBLOSECURITY="):
        value = value[len(".ROBLOSECURITY="):].removesuffix(";")
    if not value or ";" in value or any(ord(c) < 32 or ord(c) > 126 for c in value):
        raise ValueError("cookie format")
    return value


def read_request(path, now):
    try:
        raw = path.read_bytes()
        if len(raw) > 100_000:
            return None
        data = json.loads(raw)
        nonce, at = data.get("requestId"), data.get("requestedAt")
        excluded = data.get("excluded")
        if (data.get("placeId") != PLACE_ID or not isinstance(nonce, str) or not 1 <= len(nonce) <= 100
                or type(at) not in (int, float) or not 0 <= now - at <= 120
                or not isinstance(excluded, list) or len(excluded) > 1000
                or any(not isinstance(s, str) or len(s) > 100 for s in excluded)):
            return None
        return {"requestId": nonce, "excluded": set(excluded)}
    except (OSError, ValueError, TypeError, AttributeError):
        return None


def atomic_json(path, data):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, path)


class Catalogue:
    def __init__(self, now):
        self.reset(now)

    def reset(self, now):
        self.started = now
        self.rows = {}
        self.cursor = None
        self.cursors = set()
        self.complete = False
        self.rank = 0
        self.pages = 0
        self.error = None

    def add(self, payload, now):
        data = payload.get("data") if isinstance(payload, dict) else None
        if not isinstance(data, list):
            self.error = "invalid_response"
            return False
        for row in data:
            self.rank += 1
            if not isinstance(row, dict):
                continue
            sid, count = row.get("id"), row.get("playing")
            if (not isinstance(sid, str) or not 1 <= len(sid) <= 100 or row.get("maxPlayers") != 7
                    or type(count) is not int or not 1 <= count <= 6):
                continue
            previous = self.rows.get(sid)
            self.rows[sid] = {"id": sid, "playing": count, "maxPlayers": 7,
                              "nativeRank": previous["nativeRank"] if previous else self.rank,
                              "observedAt": int(now)}
        self.pages += 1
        cursor = payload.get("nextPageCursor")
        if cursor is None or cursor == "":
            self.complete, self.cursor = True, None
        elif not isinstance(cursor, str) or cursor in self.cursors:
            self.error = "repeated_cursor"
            return False
        else:
            self.cursor = cursor
            self.cursors.add(cursor)
        self.error = None
        return True

    def response(self, request, now, proof=None):
        # A long/incomplete scan cannot prove lower groups are exhausted now.
        complete = self.complete and 0 <= now - self.started <= MAX_AGE
        rows = [row for row in self.rows.values() if row["id"] not in request["excluded"]
                and 0 <= now - row["observedAt"] <= MAX_AGE]
        rows.sort(key=lambda row: (row["playing"], row["nativeRank"]))
        lowest = proof.lowest if proof and proof.valid(request, now) else None
        if lowest is not None:
            rows = [row for row in rows if row["playing"] == lowest]
        occupancy = rows[0]["playing"] if rows else None
        verified = lowest is not None and occupancy == lowest
        ready = not self.error and occupancy is not None and (occupancy == 1 or complete or verified)
        group = [row for row in rows if ready and row["playing"] == occupancy][:8]
        return {"schema": 1, "placeId": PLACE_ID, "orderBy": "BestLatency",
                "requestId": request["requestId"], "updatedAt": int(now), "scanStartedAt": int(self.started),
                "complete": complete, "state": "error" if self.error else "ready" if ready else "scanning",
                "lowestOccupancy": lowest, "occupancyCheckedAt": int(proof.checked) if lowest is not None else None,
                "error": self.error, "pages": self.pages, "fetched": self.rank,
                "occupancy": occupancy if ready else None, "servers": group}


class OccupancyProof:
    """An ascending stream establishes the lowest unvisited occupancy cheaply."""
    def __init__(self, request, now):
        self.excluded = set(request["excluded"])
        self.started = now
        self.checked = 0
        self.lowest = None
        self.cursor = None
        self.cursors = set()
        self.finished = False
        self.previous_count = 0

    def valid(self, request, now):
        return (self.finished and self.lowest is not None and self.excluded == request["excluded"]
                and 0 <= now - self.started <= 90)

    def add(self, payload, now):
        rows = payload.get("data") if isinstance(payload, dict) else None
        if not isinstance(rows, list):
            return False
        first = None
        previous_count = self.previous_count
        for row in rows:
            if not isinstance(row, dict):
                return False
            count = row.get("playing")
            if type(count) is not int or count < previous_count or not 0 <= count <= 7:
                return False
            previous_count = count
            if (row.get("maxPlayers") == 7 and 1 <= count <= 6 and isinstance(row.get("id"), str)
                    and row["id"] not in self.excluded):
                if first is None:
                    first = count
        self.previous_count = previous_count
        if first is not None:
            self.lowest, self.checked, self.finished = first, now, True
            return True
        cursor = payload.get("nextPageCursor")
        if cursor is None or cursor == "":
            self.finished, self.checked = True, now
        elif not isinstance(cursor, str) or cursor in self.cursors:
            return False
        else:
            self.cursor = cursor
            self.cursors.add(cursor)
        return True


def fetch_page(opener, cookie_path, cursor, order_by="BestLatency"):
    assert order_by in ("BestLatency", "OccupancyAsc")
    url = (f"https://games.roblox.com/v2/games/{PLACE_ID}/servers/Public"
           f"?orderBy={order_by}&sortOrder={'Desc' if order_by == 'BestLatency' else 'Asc'}&excludeFullGames=true&limit=100")
    if cursor:
        url += "&cursor=" + urllib.parse.quote(cursor, safe="")
    headers = {"Accept": "application/json", "User-Agent": "SAE-SCRIPT-local-bridge"}
    if order_by == "BestLatency":
        headers["Cookie"] = ".ROBLOSECURITY=" + read_cookie(cookie_path)
    req = urllib.request.Request(url, headers=headers)
    try:
        with opener.open(req, timeout=20) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        # Do not serialize response bodies, headers, cookie or account data.
        try:
            payload = json.loads(error.read())
            codes = [row.get("code") for row in payload.get("errors", []) if isinstance(row, dict)]
        except (ValueError, AttributeError):
            codes = []
        return error.code, {"errorCodes": codes}


def serve(workspace, cookie_path, pid_file):
    opener = urllib.request.build_opener(NoRedirects())
    catalogue = Catalogue(time.time())
    proof = None
    next_fetch, fatal, cookie_version = 0, False, None
    pid_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.write_text(str(os.getpid()), encoding="ascii")
    while True:
        now = time.time()
        request = read_request(workspace / REQUEST_FILE, now)
        if not request:
            time.sleep(1)
            continue
        try:
            version = cookie_path.stat().st_mtime_ns
        except OSError:
            version = None
        if version != cookie_version:
            cookie_version, fatal = version, False
            catalogue.reset(now)
            proof = None
        if not fatal and ((catalogue.complete and now - catalogue.started > MAX_AGE) or now - catalogue.started > 3600):
            catalogue.reset(now)
        if proof is None or proof.excluded != request["excluded"] or now - proof.started > 90:
            proof = OccupancyProof(request, now)
        result = catalogue.response(request, now, proof)
        try:
            atomic_json(workspace / RESPONSE_FILE, result)
        except OSError:
            time.sleep(1)
            continue
        # Stop issuing requests once eight unvisited 1/7 candidates are ready,
        # or the stream is complete. Resume the cursor when hops consume them.
        needs_proof = not proof.finished and not (result["state"] == "ready" and result["occupancy"] == 1)
        needs_page = needs_proof or (not catalogue.complete and not (result["state"] == "ready" and len(result["servers"]) >= 8))
        if not fatal and needs_page and now >= next_fetch:
            next_fetch = now + INTERVAL
            try:
                cursor = proof.cursor if needs_proof else catalogue.cursor
                status, payload = fetch_page(opener, cookie_path, cursor, "OccupancyAsc" if needs_proof else "BestLatency")
                if status == 200:
                    if needs_proof:
                        valid = proof.add(payload, time.time())
                        catalogue.error = None if valid else "invalid_occupancy_response"
                    else:
                        valid = catalogue.add(payload, time.time())
                    if not valid:
                        fatal = True  # Never treat malformed/repeated cursors as completion.
                elif status == 429:
                    catalogue.error = "rate_limited"
                    next_fetch = time.time() + 60
                elif status == 400 and cursor and 7 not in payload.get("errorCodes", []):
                    catalogue.reset(time.time())
                    proof = None
                    catalogue.error = "cursor_expired"
                    next_fetch = time.time() + 60
                else:
                    catalogue.error = "authentication" if status in (400, 401, 403) else "http_" + str(status)
                    fatal = status in (400, 401, 403) or 300 <= status < 400
                    next_fetch = time.time() + 60
            except (OSError, ValueError, urllib.error.URLError, TimeoutError):
                catalogue.error = "connection_or_cookie"
                next_fetch = time.time() + 60
        time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cookie-file", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--pid-file", type=Path, required=True)
    args = parser.parse_args()
    if not args.workspace.is_dir():
        parser.error("workspace must exist")
    serve(args.workspace, args.cookie_file, args.pid_file)


if __name__ == "__main__":
    main()
