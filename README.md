# SyCore

[![v1 conformance](https://github.com/NasreddineLoukriz/SyCore/actions/workflows/vectors.yml/badge.svg)](https://github.com/NasreddineLoukriz/SyCore/actions/workflows/vectors.yml)

**An open, end-to-end encrypted storage layer for apps.**

The server stores sealed boxes and a list of who may open them. It cannot read
the content, and it cannot be made to.

```
device ──AES-256-GCM──▶ ciphertext ─┐
       ──wrapped keys──▶ wraps[] ────┴──▶ server   (stores bytes, checks names)
                                            │
device ◀──open with a wrapped key───────────┘
```

---

## Status

| Component | State |
|---|---|
| **Wire format v1** — [`spec/SPEC.md`](spec/SPEC.md) | ✅ normative, 200 lines |
| **Conformance vectors** — [`vectors/v1.json`](vectors/v1.json) | ✅ generated, CI-verified |
| **Dart client** — [`packages/sycore_core`](packages/sycore_core) | ✅ **14 tests green** against the vectors |
| **Runnable demo** — [`examples/demo.dart`](examples/demo.dart) | ✅ 8 scenes, all four engines |
| **Presenter's script** — [`DEMO.md`](DEMO.md) | ✅ pre-flight, scene-by-scene, Q&A |
| FastAPI server (Postgres) | ⬜ next |
| Flutter application | ⬜ next |
| TypeScript client | ⬜ later |

> v1 is a **specification with a working client and executable vectors**.
> The vectors are the contract: any implementation that passes them is
> compatible. That is the whole point.

---

## Run it

```bash
cd examples
dart pub get
dart run demo.dart
```

Nothing else. No server, no database, no network.

To verify conformance:

```bash
cd packages/sycore_core
dart pub get
dart test          # 14 tests, ~6 s
```

CI runs both jobs on every push: vectors must regenerate byte-identically, and
the Dart client must pass them. The blind server is additionally checked for
**zero cryptographic imports**.

---

## What the demo proves

| # | Scene | Claim |
|---|---|---|
| 1 | Identities | one X25519 key + one Ed25519 key per user |
| 2 | Vault | one `VK`, two device envelopes, password rotation that **does not re-encrypt anything** |
| 3 | HOSN | Ali → Sara; the server tries to decrypt and fails |
| 4 | AAD | the server transplants a ciphertext to another row → unopenable |
| 5 | SAMAM | remove a member → epoch+1 → the removed member cannot read the future but keeps the past |
| 6 | JAHR | publish signed; tamper fails; **a self-signed forgery fails** against the directory |
| 7 | TOFU | a domain locked to `E2EE` rejects a `PLAIN` write |
| 8 | Summary | exactly what the server saw: readership, size, time — never content |

Every scene uses real cryptography. The only mock is `BlindServer`, an
in-memory class that contains **no cryptographic code at all**.

---

## Engines are wrap-counts

There is no `hosn.py`, no `samam` table, no `if engine == ...`. An engine is a
shape of `wraps`:

| Engine | Who can read | `wraps` |
|---|---|---|
| **Vault** | you, on any of your devices | 1 (`owner`) |
| **HOSN** | you + one person | 2 |
| **SAMAM** | you + a group | 1 + N |
| **JAHR** | everyone | 0 + signature |

`wraps` lives **outside** the ciphertext. That is the only reason a blind
server can authorize a read without decrypting.

---

## What the server knows

- who owns a row, who may read it, when, how big, which domain
- **not**: the content, the keys, or the words inside

This is stated as a limitation, not hidden: see [`SPEC.md` §10](spec/SPEC.md).
Metadata is visible by design. Content is not.

---

## Repository map

```
spec/SPEC.md              the wire format — read this first
packages/sycore_core/     Dart client (crypto, vault, envelope, group, jahr)
vectors/v1.json           conformance vectors (Python generator included)
examples/demo.dart        the 8-scene live demonstration
examples/expected-output.txt  the exact output, for offline presenting
DEMO.md                   presenter's script: checklist, scenes, Q&A, limits
tools/gen_vectors.py      regenerates the vectors; CI requires a clean diff
sycore-backend/           ⚠ legacy Django prototype (2026-05) — reference only
sycore-sdk/               ⚠ legacy SDK
docs/                     design notes and the original decision log
```

The `sycore-backend/` and `sycore-sdk/` trees are the May 2026 prototype. They
predate the spec and do not implement it (no `wraps` table, no AAD). They are
kept for the design history, not as a starting point.

---

## بالعربية

**SyCore طبقة تخزين مشفّرة من الطرف إلى الطرف.** التطبيق يشفّر قبل الإرسال،
والخادم يخزّن صناديق مقفولة وقائمة بمن يملك مفاتيحها، ولا يستطيع قراءة المحتوى.

**المحرّكات ليست وحدات في الخادم** — هي عدد اللفّات:
الخزنة = 1 · HOSN = 2 · SAMAM = 1+N · JAHR = 0 + توقيع.

**للتحقق السريع:** `cd examples && dart pub get && dart run demo.dart`
ثمانية مشاهد تُظهر الخزنة وHOSN وSAMAM وJAHR ومنع نقل الرسائل ومنع الانتحال.

المواصفة في `spec/SPEC.md`، واختبارات المطابقة في `vectors/v1.json`.

---

## License

Apache-2.0 — see [`LICENSE`](LICENSE).
