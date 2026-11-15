# sycore_app — the Flutter desktop client

Five screens over the `sycore_client` SDK. Every encryption happens in this
process; the server is contacted only through the SDK's six routes.

```bash
flutter pub get
flutter run -d linux                       # development
flutter build linux --release              # → build/linux/x64/release/bundle/sycore_app
```

The app expects the server at `http://127.0.0.1:8787` (override at build time
with `--dart-define=SYCORE_SERVER=http://host:port`).

## Signing in

Three personas, one demo passphrase — `correct horse battery staple`:

| Persona | id | role |
|---|---|---|
| Ali | `usr_ali` | owns the vault, sends, publishes, manages the group |
| Sara | `usr_sara` | the invited reader |
| Mona | `usr_mona` | the member who is removed |

On first run, whichever runs first — this app or `examples/client_demo.dart` —
registers the identities in the shared local vault directory `~/.sycore/app`
(override with `SYCORE_HOME`). The other one attaches to the same identity by
adding its own device envelope, so no keys are re-published and no content is
re-encrypted.

If the server database is reset while a local vault survives, sign-in reports
`key_conflict` / `identity_mismatch`. Run `server/reset.sh`, which clears both
sides.

## Screens

| Screen | What it does |
|---|---|
| **Vault** | identity, fingerprint, VK preview, devices, the stored envelope |
| **Messages** | HOSN inbox; opens a row and shows the ciphertext the server holds |
| **Group** | SAMAM epoch, member chips (add/remove), timeline with reader counts |
| **Public** | JAHR feed, anonymous read, and the forged-key experiment |
| **Operator** | stats, every row the API discloses, the wire JSON, the audit log |

## Demo shortcuts

For rehearsals and screenshots the app can sign in by itself:

```bash
SYCORE_DEMO_USER=usr_ali SYCORE_DEMO_TAB=2 ./build/linux/x64/release/bundle/sycore_app
```

`SYCORE_DEMO_TAB`: 0 Vault · 1 Messages · 2 Group · 3 Public · 4 Operator.
