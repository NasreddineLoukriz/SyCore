"""SYCORE blind server — storage and policy only.

There is no cryptography in this package, and there is not meant to be. The
server receives sealed boxes, a list of recipient ids, and a signature blob it
never interprets. See spec/SPEC.md §5-§9.

If a line of this file ever needs a key, the design has already failed.
"""

from __future__ import annotations

import json
import sqlite3
import threading
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

CLEARANCES = ("E2EE", "PLAIN", "JAHR")

SCHEMA = """
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS identities (
    user_id     TEXT PRIMARY KEY,
    dh_pub      TEXT NOT NULL,
    sign_pub    TEXT NOT NULL,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS projects (
    project_id  TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS policies (
    project_id  TEXT NOT NULL,
    domain      TEXT NOT NULL,
    clearance   TEXT NOT NULL,
    created_at  TEXT NOT NULL,
    PRIMARY KEY (project_id, domain)
);

CREATE TABLE IF NOT EXISTS resources (
    id          TEXT PRIMARY KEY,
    project_id  TEXT NOT NULL,
    domain      TEXT NOT NULL,
    owner_id    TEXT NOT NULL,
    version     INTEGER NOT NULL,
    alg         TEXT NOT NULL,
    nonce       TEXT NOT NULL,
    ciphertext  TEXT NOT NULL,
    signature   TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS resources_domain ON resources (project_id, domain);
CREATE INDEX IF NOT EXISTS resources_owner  ON resources (owner_id);

CREATE TABLE IF NOT EXISTS wraps (
    resource_id  TEXT NOT NULL,
    recipient_id TEXT NOT NULL,
    kind         TEXT NOT NULL CHECK (kind IN ('owner', 'recipient')),
    epk          TEXT NOT NULL,
    nonce        TEXT NOT NULL,
    ct           TEXT NOT NULL,
    PRIMARY KEY (resource_id, recipient_id, kind)
);

CREATE INDEX IF NOT EXISTS wraps_recipient ON wraps (recipient_id);

CREATE TABLE IF NOT EXISTS audit (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    at          TEXT NOT NULL,
    actor       TEXT NOT NULL,
    action      TEXT NOT NULL,
    resource_id TEXT,
    detail      TEXT
);
"""


class StoreError(Exception):
    """A refusal the API can translate into a status code."""

    def __init__(self, code: str, status: int = 400) -> None:
        super().__init__(code)
        self.code = code
        self.status = status


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


class Store:
    def __init__(self, path: str | Path = ":memory:") -> None:
        self.path = str(path)
        self._lock = threading.Lock()
        # Keep one shared in-memory database alive; on disk, open per call.
        self._mem: sqlite3.Connection | None = None
        self._init()

    # ── plumbing ────────────────────────────────────────────────
    @contextmanager
    def conn(self) -> Iterator[sqlite3.Connection]:
        if self.path == ":memory:":
            assert self._mem is not None
            with self._lock:
                yield self._mem
            return
        c = sqlite3.connect(self.path, timeout=5)
        c.row_factory = sqlite3.Row
        try:
            yield c
            c.commit()
        finally:
            c.close()

    def _init(self) -> None:
        if self.path == ":memory:":
            self._mem = sqlite3.connect(":memory:", check_same_thread=False)
            self._mem.row_factory = sqlite3.Row
            self._mem.executescript(SCHEMA)
            return
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with self.conn() as c:
            c.executescript(SCHEMA)

    def audit(self, actor: str, action: str, resource_id: str | None = None,
              detail: str | None = None) -> None:
        with self.conn() as c:
            c.execute(
                "INSERT INTO audit (at, actor, action, resource_id, detail)"
                " VALUES (?,?,?,?,?)",
                (now(), actor or "anonymous", action, resource_id, detail),
            )

    # ── identities: the trusted public-key directory (SPEC §7) ──
    def put_identity(self, user_id: str, dh_pub: str, sign_pub: str) -> dict[str, Any]:
        with self.conn() as c:
            row = c.execute(
                "SELECT * FROM identities WHERE user_id = ?", (user_id,)
            ).fetchone()
            if row is not None:
                if row["dh_pub"] != dh_pub or row["sign_pub"] != sign_pub:
                    raise StoreError("key_conflict", 409)
                return dict(row)
            c.execute(
                "INSERT INTO identities (user_id, dh_pub, sign_pub, created_at)"
                " VALUES (?,?,?,?)",
                (user_id, dh_pub, sign_pub, now()),
            )
        self.audit(user_id, "identity.created", user_id)
        return {"user_id": user_id, "dh_pub": dh_pub, "sign_pub": sign_pub,
                "created_at": now()}

    def get_identity(self, user_id: str) -> dict[str, Any] | None:
        with self.conn() as c:
            row = c.execute(
                "SELECT * FROM identities WHERE user_id = ?", (user_id,)
            ).fetchone()
        return dict(row) if row else None

    def directory(self) -> list[dict[str, Any]]:
        with self.conn() as c:
            rows = c.execute(
                "SELECT user_id, dh_pub, sign_pub FROM identities ORDER BY user_id"
            ).fetchall()
        return [dict(r) for r in rows]

    # ── resources ───────────────────────────────────────────────
    def put_resource(
        self,
        *,
        project_id: str,
        domain: str,
        clearance: str,
        envelope: dict[str, Any],
        actor: str,
    ) -> dict[str, Any]:
        if clearance not in CLEARANCES:
            raise StoreError("invalid_clearance", 422)

        rid = envelope["id"]
        version = int(envelope["version"])
        wraps = envelope.get("wraps") or []
        nonce = envelope.get("nonce") or ""
        ciphertext = envelope.get("ciphertext") or ""
        signature = envelope.get("signature")

        # Shape checks only. The server never looks inside `ct`.
        if not rid or not ciphertext:
            raise StoreError("invalid_envelope", 422)

        if clearance == "E2EE":
            if len(nonce) < 12 or not wraps:
                raise StoreError("invalid_envelope", 422)
            if signature is not None:
                raise StoreError("invalid_envelope", 422)
        if clearance == "JAHR":
            if not signature or wraps:
                raise StoreError("invalid_envelope", 422)
        if clearance == "PLAIN":
            if wraps:
                raise StoreError("invalid_envelope", 422)

        with self.conn() as c:
            # TOFU: the first clearance seen for a domain is the only one.
            pol = c.execute(
                "SELECT clearance FROM policies WHERE project_id = ? AND domain = ?",
                (project_id, domain),
            ).fetchone()
            if pol is None:
                c.execute(
                    "INSERT INTO projects (project_id, name, created_at)"
                    " VALUES (?,?,?) ON CONFLICT(project_id) DO NOTHING",
                    (project_id, project_id, now()),
                )
                c.execute(
                    "INSERT INTO policies (project_id, domain, clearance, created_at)"
                    " VALUES (?,?,?,?)",
                    (project_id, domain, clearance, now()),
                )
            elif pol["clearance"] != clearance:
                self.audit(actor, "write.rejected", rid, "clearance_mismatch")
                raise StoreError("data_poisoning_rejected", 422)

            prev = c.execute(
                "SELECT version, owner_id FROM resources WHERE id = ?", (rid,)
            ).fetchone()
            if prev is None:
                if version != 1:
                    raise StoreError("version_conflict", 409)
            else:
                if prev["owner_id"] != envelope["owner_id"]:
                    raise StoreError("owner_mismatch", 403)
                if version != prev["version"] + 1:
                    self.audit(actor, "write.rejected", rid, "version_conflict")
                    raise StoreError("version_conflict", 409)
                c.execute("DELETE FROM wraps WHERE resource_id = ?", (rid,))

            c.execute(
                """
                INSERT INTO resources
                    (id, project_id, domain, owner_id, version, alg, nonce,
                     ciphertext, signature, created_at, updated_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET
                    version    = excluded.version,
                    alg        = excluded.alg,
                    nonce      = excluded.nonce,
                    ciphertext = excluded.ciphertext,
                    signature  = excluded.signature,
                    updated_at = excluded.updated_at
                """,
                (
                    rid, project_id, domain, envelope["owner_id"], version,
                    envelope.get("alg", "A256GCM"), nonce, ciphertext,
                    signature, now(), now(),
                ),
            )
            for w in wraps:
                c.execute(
                    "INSERT INTO wraps (resource_id, recipient_id, kind, epk, nonce, ct)"
                    " VALUES (?,?,?,?,?,?)",
                    (rid, w["to"], w["kind"], w["epk"], w["nonce"], w["ct"]),
                )

        self.audit(actor, "resource.put", rid, f"{domain}/v{version}")
        return self.get_resource(rid, requester=actor, enforce=False)

    def _envelope(self, c: sqlite3.Connection, row: sqlite3.Row) -> dict[str, Any]:
        wraps = c.execute(
            "SELECT recipient_id, kind, epk, nonce, ct FROM wraps"
            " WHERE resource_id = ? ORDER BY kind, recipient_id",
            (row["id"],),
        ).fetchall()
        return {
            "v": 1,
            "id": row["id"],
            "project_id": row["project_id"],
            "domain": row["domain"],
            "owner_id": row["owner_id"],
            "version": row["version"],
            "alg": row["alg"],
            "nonce": row["nonce"],
            "ciphertext": row["ciphertext"],
            "wraps": [
                {"to": w["recipient_id"], "kind": w["kind"], "epk": w["epk"],
                 "nonce": w["nonce"], "ct": w["ct"]}
                for w in wraps
            ],
            "signature": row["signature"],
        }

    def get_resource(self, rid: str, *, requester: str, enforce: bool = True) -> dict[str, Any]:
        with self.conn() as c:
            row = c.execute("SELECT * FROM resources WHERE id = ?", (rid,)).fetchone()
            if row is None:
                raise StoreError("not_found", 404)

            if enforce and not self._may_read(c, row, requester):
                self.audit(requester, "read.denied", rid)
                raise StoreError("forbidden", 403)

            env = self._envelope(c, row)

        if enforce:
            self.audit(requester, "resource.get", rid)
        return env

    def _policy(self, c: sqlite3.Connection, project_id: str, domain: str) -> str | None:
        row = c.execute(
            "SELECT clearance FROM policies WHERE project_id = ? AND domain = ?",
            (project_id, domain),
        ).fetchone()
        return row["clearance"] if row else None

    def _may_read(self, c: sqlite3.Connection, row: sqlite3.Row, requester: str) -> bool:
        # Public domain: JAHR is readable by anyone, including anonymous.
        if self._policy(c, row["project_id"], row["domain"]) == "JAHR":
            return True
        if requester and requester == row["owner_id"]:
            return True
        if not requester:
            return False
        hit = c.execute(
            "SELECT 1 FROM wraps WHERE resource_id = ? AND recipient_id = ?",
            (row["id"], requester),
        ).fetchone()
        return hit is not None

    # ── listing: metadata the server is allowed to see ──────────
    def list_resources(
        self, *, project_id: str, domain: str | None, requester: str
    ) -> list[dict[str, Any]]:
        sql = "SELECT * FROM resources WHERE project_id = ?"
        args: list[Any] = [project_id]
        if domain is not None:
            sql += " AND domain = ?"
            args.append(domain)
        sql += " ORDER BY updated_at DESC, id"

        out: list[dict[str, Any]] = []
        with self.conn() as c:
            for row in c.execute(sql, args).fetchall():
                if not self._may_read(c, row, requester):
                    continue
                readers = c.execute(
                    "SELECT DISTINCT recipient_id FROM wraps WHERE resource_id = ?"
                    " ORDER BY recipient_id",
                    (row["id"],),
                ).fetchall()
                out.append({
                    "id": row["id"],
                    "project_id": row["project_id"],
                    "domain": row["domain"],
                    "owner_id": row["owner_id"],
                    "version": row["version"],
                    "readers": [r["recipient_id"] for r in readers],
                    "ciphertext_chars": len(row["ciphertext"]),
                    "signed": row["signature"] is not None,
                    "updated_at": row["updated_at"],
                })
        return out

    def policy(self, project_id: str, domain: str) -> str | None:
        with self.conn() as c:
            return self._policy(c, project_id, domain)

    def audit_tail(self, limit: int = 50) -> list[dict[str, Any]]:
        with self.conn() as c:
            rows = c.execute(
                "SELECT * FROM audit ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()
        return [dict(r) for r in rows]

    # ── what an operator with the database can actually read ────
    def raw_row(self, rid: str) -> dict[str, Any] | None:
        with self.conn() as c:
            row = c.execute("SELECT * FROM resources WHERE id = ?", (rid,)).fetchone()
            if row is None:
                return None
            wraps = c.execute(
                "SELECT * FROM wraps WHERE resource_id = ?", (rid,)
            ).fetchall()
        d = dict(row)
        d["wraps"] = [dict(w) for w in wraps]
        d["ciphertext_preview"] = d["ciphertext"][:120] + "…"
        del d["ciphertext"]
        return d

    def stats(self) -> dict[str, Any]:
        with self.conn() as c:
            q = lambda sql: c.execute(sql).fetchone()[0]  # noqa: E731
            return {
                "identities": q("SELECT COUNT(*) FROM identities"),
                "resources": q("SELECT COUNT(*) FROM resources"),
                "wraps": q("SELECT COUNT(*) FROM wraps"),
                "domains": q("SELECT COUNT(*) FROM policies"),
                "audit": q("SELECT COUNT(*) FROM audit"),
            }


def dumps(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
