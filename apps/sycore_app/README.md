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

## Language

The whole interface exists twice — English and Arabic — and the switch in the
header (or on the login page) swaps it instantly: words, alignment, and text
direction. Arabic mirrors the layout properly (`Directionality` + Arabic
Material localisations), it is not a translation bolted onto a left-to-right
page. Wire JSON is the one exception: bytes are always shown left to right.

The choice is remembered between runs in `~/.config/sycore/lang` (honouring
`XDG_CONFIG_HOME`), so the app opens the way you left it. To pin a language for
one run — a rehearsal, a screenshot — set `SYCORE_LANG`; it wins over the
remembered choice:

```bash
SYCORE_LANG=ar ./build/linux/x64/release/bundle/sycore_app
SYCORE_LANG=en ./build/linux/x64/release/bundle/sycore_app
```

Text lives in one table, [`lib/l10n.dart`](lib/l10n.dart): `Strings(AppLang.ar)`
and `Strings(AppLang.en)`, with `{name}` placeholders. A missing key renders as
`!key` so it is visible rather than silently English.

## Design

Paper, ink, and one pine accent. No cards, no shadows, no glow: structure comes
from hairlines and white space, and colour is reserved for meaning (verified,
refused, removed). Headings are set in Linux Libertine, reading text in Lato,
key material in Hack, and Arabic in Noto Naskh. All four faces are bundled in
`assets/fonts`, so the app renders identically offline and on a machine that
has none of them installed.

## Tests

```bash
flutter test          # translation parity, placeholders, English/Arabic switch
flutter analyze
```

## Demo shortcuts

For rehearsals and screenshots the app can sign in by itself:

```bash
SYCORE_DEMO_USER=usr_ali SYCORE_DEMO_TAB=2 ./build/linux/x64/release/bundle/sycore_app
```

`SYCORE_DEMO_TAB`: 0 Vault · 1 Messages · 2 Group · 3 Public · 4 Operator.
