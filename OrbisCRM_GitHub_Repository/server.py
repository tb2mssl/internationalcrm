#!/usr/bin/env python3
"""
Turnkey Render.com & Local Web Server for OrbisCRM Global.
Automatically detects whether `index.html` is in `./public` or root `./`,
connects to `database/crm_enterprise.db` (or `crm_enterprise.db` in root),
and serves the complete CRM application + REST API on Render's $PORT.
"""

import http.server
import json
import os
import pathlib
import socketserver
import sqlite3
import urllib.parse

PORT = int(os.environ.get("PORT", 10000))
ROOT_DIR = pathlib.Path(__file__).resolve().parent

# Automatically choose ./public if public/index.html exists, otherwise serve from root directory
if (ROOT_DIR / "public/index.html").exists():
    SERVE_DIR = ROOT_DIR / "public"
else:
    SERVE_DIR = ROOT_DIR

# Automatically locate SQLite database
if (ROOT_DIR / "database/crm_enterprise.db").exists():
    DB_PATH = ROOT_DIR / "database/crm_enterprise.db"
else:
    DB_PATH = ROOT_DIR / "crm_enterprise.db"


class CRMRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(SERVE_DIR), **kwargs)

    def _send_json(self, data, status=200):
        payload = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if path == "/api/health":
            lead_count = 100
            if DB_PATH.exists():
                conn = sqlite3.connect(str(DB_PATH))
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*) FROM leads")
                lead_count = cur.fetchone()[0]
                conn.close()
            return self._send_json({"status": "ok", "service": "OrbisCRM Global", "leads_count": lead_count})

        if path == "/api/leads" and DB_PATH.exists():
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            country = qs.get("country", [None])[0]
            industry = qs.get("industry", [None])[0]
            status = qs.get("status", [None])[0]
            sql = "SELECT * FROM leads WHERE 1=1"
            params = []
            if country:
                sql += " AND country_name = ?"
                params.append(country)
            if industry:
                sql += " AND industry_name = ?"
                params.append(industry)
            if status:
                sql += " AND lead_status = ?"
                params.append(status)
            sql += " ORDER BY lead_id ASC"
            rows = [dict(r) for r in cur.execute(sql, params).fetchall()]
            conn.close()
            return self._send_json({"count": len(rows), "data": rows})

        if path == "/api/companies" and DB_PATH.exists():
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            rows = [dict(r) for r in cur.execute("SELECT * FROM companies ORDER BY company_id ASC").fetchall()]
            conn.close()
            return self._send_json({"count": len(rows), "data": rows})

        return super().do_GET()


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), CRMRequestHandler) as httpd:
        print("=" * 68)
        print(f"🚀 OrbisCRM Global Enterprise Website Running on Port {PORT}")
        print(f"📁 Serving Directory: {SERVE_DIR}")
        print(f"🗄️  Database Path: {DB_PATH}")
        print("=" * 68)
        httpd.serve_forever()
