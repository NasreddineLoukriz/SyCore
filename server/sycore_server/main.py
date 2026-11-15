"""SYCORE v1 API — six endpoints, zero cryptography.

    POST   /v1/identities                  publish public keys
    GET    /v1/identities/{user_id}        the trusted key directory
    POST   /v1/resources                   store a sealed envelope
    GET    /v1/resources/{resource_id}     fetch it, authorised by metadata
    GET    /v1/resources?project_id=…      list metadata (inbox)
    GET    /v1/audit                       what the operator did / was refused

The server decides *who may read a row* (owner, named in `wraps`, or a public
JAHR domain). It never decides *what the row means*: `ciphertext`, the wrap
blobs and the signature are opaque strings it stores and returns verbatim.

Authentication in this prototype is the `X-Sycore-User` header standing in for
a session token. That is a deliberate simplification, documented in
server/README.md — it is not part of the wire format.
"""

from __future__ import annotations

from typing import Any, Literal

from fastapi import FastAPI, Header, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from .store import Store, StoreError

DB_PATH = "sycore.db"

app = FastAPI(
    title="SYCORE v1",
    version="1.0.0",
    description="Blind storage: sealed boxes, recipient lists, signatures. No keys.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

store = Store(DB_PATH)


# ── errors: one shape, no stack traces, no hints ─────────────────
@app.exception_handler(StoreError)
async def store_error_handler(_: Request, exc: StoreError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status,
        content={"error": {"code": exc.code}},
    )


class IdentityIn(BaseModel):
    user_id: str = Field(min_length=1, max_length=128)
    dh_pub: str = Field(min_length=1, max_length=256)
    sign_pub: str = Field(min_length=1, max_length=256)


class WrapIn(BaseModel):
    to: str
    kind: Literal["owner", "recipient"]
    epk: str
    nonce: str
    ct: str


class EnvelopeIn(BaseModel):
    id: str = Field(min_length=1, max_length=128)
    project_id: str = Field(min_length=1, max_length=128)
    domain: str = Field(min_length=1, max_length=128)
    owner_id: str
    version: int = Field(ge=1)
    nonce: str = ""
    ciphertext: str = ""
    wraps: list[WrapIn] = Field(default_factory=list)
    signature: str | None = None
    alg: str = "A256GCM"


class PutIn(BaseModel):
    clearance: Literal["E2EE", "PLAIN", "JAHR"]
    envelope: EnvelopeIn


def actor_of(user: str | None) -> str:
    return (user or "").strip()


# ── 1. identities ───────────────────────────────────────────────
@app.post("/v1/identities", status_code=201)
def create_identity(body: IdentityIn) -> dict[str, Any]:
    return store.put_identity(body.user_id, body.dh_pub, body.sign_pub)


# ── 2. the trusted directory ────────────────────────────────────
@app.get("/v1/identities/{user_id}")
def read_identity(user_id: str) -> dict[str, Any]:
    found = store.get_identity(user_id)
    if found is None:
        raise StoreError("not_found", 404)
    return found


# ── 3. store a sealed envelope ──────────────────────────────────
@app.post("/v1/resources", status_code=201)
def put_resource(
    body: PutIn,
    x_sycore_user: str | None = Header(default=None),
) -> dict[str, Any]:
    actor = actor_of(x_sycore_user)
    if not actor:
        raise StoreError("unauthenticated", 401)
    if actor != body.envelope.owner_id:
        raise StoreError("not_owner", 403)

    env = body.envelope.model_dump()
    return store.put_resource(
        project_id=env["project_id"],
        domain=env["domain"],
        clearance=body.clearance,
        envelope=env,
        actor=actor,
    )


# ── 5. list metadata (declared before /{id} so the path wins) ────
@app.get("/v1/resources")
def list_resources(
    project_id: str = Query(min_length=1),
    domain: str | None = None,
    x_sycore_user: str | None = Header(default=None),
) -> dict[str, Any]:
    rows = store.list_resources(
        project_id=project_id,
        domain=domain,
        requester=actor_of(x_sycore_user),
    )
    return {
        "project_id": project_id,
        "domain": domain,
        "count": len(rows),
        "resources": rows,
        "policy": store.policy(project_id, domain) if domain else None,
    }


# ── 4. fetch one row ────────────────────────────────────────────
@app.get("/v1/resources/{resource_id}")
def get_resource(
    resource_id: str,
    x_sycore_user: str | None = Header(default=None),
) -> dict[str, Any]:
    return store.get_resource(resource_id, requester=actor_of(x_sycore_user))


# ── 6. audit ────────────────────────────────────────────────────
@app.get("/v1/audit")
def audit(limit: int = Query(default=50, ge=1, le=500)) -> dict[str, Any]:
    return {"count": len(store.audit_tail(limit)), "entries": store.audit_tail(limit)}


# ── health: not part of the API surface ─────────────────────────
@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "wire": "v1", "crypto_lines": 0, "stats": store.stats()}
