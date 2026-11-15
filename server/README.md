# The blind server

FastAPI + SQLite. Six endpoints. **No cryptography, by construction** — a test
fails the build if a cryptographic term appears in the package source.

```bash
./run.sh        # create .venv on first run, serve on http://127.0.0.1:8787
./reset.sh      # stop the server, delete sycore.db*, delete ~/.sycore/app, restart
```

`reset.sh` is the one command to run before a demonstration: fresh database,
fresh local vaults, same passphrase.

## The six routes

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/v1/identities` | publish a user's two public keys |
| `GET` | `/v1/identities/{user_id}` | the trusted directory (SPEC §7) |
| `POST` | `/v1/resources` | store a sealed envelope |
| `GET` | `/v1/resources/{resource_id}` | fetch one row, authorised by metadata |
| `GET` | `/v1/resources?project_id=…&domain=…` | list metadata (the inbox) |
| `GET` | `/v1/audit` | what was done, and what was refused |

Plus `GET /health`, which is not part of the API surface: it reports
`crypto_lines: 0` and the row counts.

## Authorisation, in one paragraph

A row is readable when the requester is its owner, or is named in one of its
`wraps`, or the domain's clearance is `JAHR` (public). The server learns this
from the `wraps` table and the `policies` table — never from the ciphertext.
That is why an engine can be added without changing a line here: an engine is a
*wrap count*, not a code path.

The server also refuses, and records the refusal in `audit`:

| Attempt | Answer |
|---|---|
| a non-reader fetches a row | `403 forbidden` |
| a non-owner writes a row | `403 not_owner` |
| a stale `version` | `409 version_conflict` |
| `PLAIN` inside an `E2EE` domain | `422 data_poisoning_rejected` |
| `JAHR` without a signature, or with wraps | `422 invalid_envelope` |
| the same user id with different keys | `409 key_conflict` |

The first clearance seen for a project/domain is the only one it will accept
afterwards (trust-on-first-use, SPEC §5).

## Authentication — the one deliberate simplification

Requests carry `X-Sycore-User: usr_ali`. There is no token, no session, no
signature check on the header. This is **not** part of the wire format; it is a
stand-in so the prototype can be run and demonstrated without an auth server.
Production replaces it with a real session token and keeps everything else.

Because the header is unauthenticated, the server's authorisation proves *what
the server does with a name*, not *who is behind the name*. This is stated in
`DEMO.md` and in SPEC §10 rather than hidden.

## Tests

```bash
./.venv/bin/python -m pytest -q       # 10 tests
```

They cover the identity directory and `key_conflict`, read authorisation,
owner-only writes, optimistic versioning, TOFU, JAHR signatures and anonymous
reads, listing that never returns content, audit refusals — and a scan that
proves the package source contains no cryptography.

## Storage

SQLite at `server/sycore.db` (WAL mode). Tables: `identities`, `projects`,
`policies`, `resources`, `wraps`, `audit`. `wraps` lives outside the ciphertext
on purpose: it is the only reason a server that cannot decrypt anything can
still decide who may.
