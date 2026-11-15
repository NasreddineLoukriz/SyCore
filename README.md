# SyCore

[![v1 conformance](https://github.com/NasreddineLoukriz/SyCore/actions/workflows/vectors.yml/badge.svg)](https://github.com/NasreddineLoukriz/SyCore/actions/workflows/vectors.yml)

**An open, end-to-end encrypted storage layer for apps.**

The server stores sealed boxes and a list of who may open them. It cannot read
the content, and it cannot be made to.

```
device ──AES-256-GCM──▶ ciphertext ─┐
       ──wrapped keys──▶ wraps[] ────┴──▶ server   (stores bytes, checks names)
                                            │
device ◀──open with a wrapped key──────────┘
```

---

## Status

| Component | State |
|---|---|
| **Wire format v1** — [`spec/SPEC.md`](spec/SPEC.md) | ✅ normative |
| **Conformance vectors** — [`vectors/v1.json`](vectors/v1.json) | ✅ generated, CI-verified |
| **Blind server** — [`server/`](server) | ✅ FastAPI + SQLite, 10 tests, **zero crypto** |
| **Dart SDK** — [`packages/sycore_client`](packages/sycore_client) | ✅ `vault`, `hosn`, `samam`, `jahr`, `operator` |
| **Flutter app** — [`apps/sycore_app`](apps/sycore_app) | ✅ Linux desktop, five screens, live server |
| **Crypto core** — [`packages/sycore_core`](packages/sycore_core) | ✅ 14 conformance tests |
| **Walkthroughs** — [`examples/`](examples) | ✅ `client_demo.dart` (server) · `demo.dart` (offline) |
| **Presenter's script** — [`DEMO.md`](DEMO.md) | ✅ pre-flight, scene by scene, Q&A |

> The server has no cryptography in it, and a test fails the build if anyone
> adds a line. The client has all of it. That asymmetry *is* the design.

---

## Run it

Three terminals, in this order. Every command is short on purpose.

```bash
# 1 · the server (starts clean: fresh DB, fresh local vaults)
cd server && ./reset.sh
#    → http://127.0.0.1:8787  (Ctrl-C to stop; ./run.sh next time keeps the data)

# 2 · the app
cd apps/sycore_app
flutter run -d linux          # or: flutter build linux --release
#    → sign in as Ali / Sara / Mona with the demo passphrase
#    → the switch in the header turns the whole interface Arabic (RTL)
#      or back; SYCORE_LANG=ar starts in Arabic

# 3 · the SDK walkthrough (optional, but it is the proof without a UI)
cd examples
dart run client_demo.dart     # 6 sections against the same live server
```

The demo passphrase is `correct horse battery staple`.

`examples/client_demo.dart` and the app share `~/.sycore/app`, so whichever runs
first registers the identities and the other one simply unlocks them. If the
server is reset while a vault survives, the app says
`key_conflict`/`identity_mismatch` — run `server/reset.sh`, which clears both.

To verify conformance and the offline proof:

```bash
cd examples && dart run demo.dart          # 8 scenes, no server, no network
cd packages/sycore_core && dart test       # 14 tests, ~6 s
cd server && ./.venv/bin/python -m pytest  # 10 tests, includes the zero-crypto scan
```

---

## The app — five screens, one envelope

| Screen | What you see | What it proves |
|---|---|---|
| **Vault** | identity, fingerprint, VK, devices (`cli`, `laptop`, `phone`) | the password opens a key; the key never moves |
| **Messages** | inbox + plaintext + the same row as the server stores it | HOSN: owner wrap + one recipient wrap |
| **Group** | epoch, member chips, timeline, `3 readers` vs `2 readers` | SAMAM: removing Mona rotates the key |
| **Public** | signed post, "Read as anonymous", the forgery experiment | JAHR: the directory, not the payload, decides authorship |
| **Operator** | stats, every row, the wire JSON, the audit log | metadata yes, content no |

The interface is bilingual — English and Arabic, switched from the header — and
mirrors right-to-left when Arabic is chosen. It is set on paper: ink text, one
dark-green accent, hairline rules instead of cards, and colour used only for
meaning (verified, refused, removed). Fonts are bundled, so it looks the same on
any machine and with no network.

The forgery experiment is the one to run in front of an audience: a forged post
verifies **true** against the key shipped inside it, and **false** against the
directory. Two buttons, same bytes, opposite answers.

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

`wraps` lives **outside** the ciphertext. That is the only reason a blind server
can authorize a read without decrypting.

---

## What the server knows

- who owns a row, who may read it, when, how big, which domain
- **not**: the content, the keys, or the words inside

This is stated as a limitation, not hidden: see [`SPEC.md` §10](spec/SPEC.md).
Metadata is visible by design. Content is not.

The server also refuses, and records the refusal in `audit`:

| Attempt | Answer |
|---|---|
| a non-reader fetches a row | `403 forbidden` |
| a non-owner writes a row | `403 not_owner` |
| a stale `version` | `409 version_conflict` |
| `PLAIN` inside an `E2EE` domain | `422 data_poisoning_rejected` |
| `JAHR` without a signature | `422 invalid_envelope` |
| the same name with different keys | `409 key_conflict` |

---

## Repository map

```
spec/SPEC.md                    the wire format — read this first
server/                         blind FastAPI server (6 endpoints, SQLite, no crypto)
  sycore_server/store.py        schema, policy, authorization — the whole server
  sycore_server/main.py         the six routes
server/tests/test_api.py        the contract + a scan proving zero crypto
packages/sycore_core/           crypto, envelope, vault, group, jahr (14 tests)
packages/sycore_client/         the SDK: vault, hosn, samam, jahr, operator
apps/sycore_app/                the Flutter desktop app (five screens)
examples/client_demo.dart       SDK walkthrough against the live server
examples/demo.dart              the offline 8-scene proof (no server at all)
examples/expected-output.txt    a reference run of demo.dart
vectors/v1.json                 conformance vectors
tools/gen_vectors.py            regenerates the vectors; CI requires a clean diff
DEMO.md                         presenter's script: checklist, scenes, Q&A, limits
sycore-backend/                 ⚠ legacy Django prototype (2026-05) — reference only
sycore-sdk/                     ⚠ legacy SDK
docs/                           design notes and the original decision log
```

The `sycore-backend/` and `sycore-sdk/` trees are the May 2026 prototype. They
predate the spec and do not implement it (no `wraps` table, no AAD). They are
kept for the design history, not as a starting point.

---

## بالعربية

**SyCore طبقة تخزين مشفّرة من الطرف إلى الطرف.** التطبيق يشفّر قبل الإرسال،
والخادم يخزّن صناديق مقفولة وقائمة بمن يملك مفاتيحها، ولا يستطيع قراءة المحتوى.

هذه النسخة تعمل فعلاً: **خادم FastAPI** بستّ نقاط نهاية وقاعدة SQLite،
**حزمة Dart** (`sycore_client`) بواجهة واضحة لكل ميزة، و**تطبيق Flutter**
بخمس شاشات. الأوامر:

```bash
cd server && ./reset.sh                 # الخادم على 127.0.0.1:8787
cd apps/sycore_app && flutter run -d linux
cd examples && dart run client_demo.dart
```

**المحرّكات ليست وحدات في الخادم** — هي عدد اللفّات:
الخزنة = 1 · HOSN = 2 · SAMAM = 1+N · JAHR = 0 + توقيع.

كلمة السر للتجربة: `correct horse battery staple`.

---

## License

Apache-2.0 — see [`LICENSE`](LICENSE).
