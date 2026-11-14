# SYCORE Wire Format v1

**Status:** Draft (normative) · **Version:** 1 · **Date:** 2026-11-14

This document defines the bytes. It is the only source of truth: an
implementation in any language that follows §2–§9 byte-for-byte is compatible.
`vectors/v1.json` is the conformance suite.

The server is **blind**: it stores `ciphertext`, `nonce`, `wraps[]` and
`signature`, and never derives a key. Everything below happens on the client.

---

## 1. Conventions

- All identifiers (`project_id`, `domain`, `resource_id`, `owner_id`,
  `recipient_id`, `device_id`) MUST match `^[A-Za-z0-9_-]{1,64}$`.
- Binary values on the wire are **base64url without padding** (RFC 4648 §5).
- Integers are decimal ASCII, no leading zeros, no sign.
- Strings are UTF-8, normalized to NFC.
- `|` (U+007C) is the field separator. It cannot appear in an identifier (§1),
  which makes the concatenations below unambiguous.

---

## 2. Primitives

| Name | Algorithm | Parameters |
|---|---|---|
| AEAD | AES-256-GCM | 32-byte key, 12-byte nonce, 16-byte tag appended to ciphertext |
| DH | X25519 (RFC 7748) | 32-byte keys |
| SIG | Ed25519 (RFC 8032) | 32-byte public, 32-byte seed |
| HASH | SHA-256 | — |
| KDF | Argon2id v=19 | t=3, m=65536 KiB, p=4, salt=16B, output=32B |
| HKDF | HKDF-SHA256 | — |

Nonces MUST be 12 random bytes from a CSPRNG. They MUST NOT be derived from
counters that can repeat across devices.

---

## 3. Associated Data (normative)

Every AEAD operation MUST pass AAD. A ciphertext without AAD is a protocol
error and MUST be rejected.

```
aad(kind, project_id, domain, resource_id, owner_id, version, recipient_id)
  = UTF8( "sycore/v1" "|" kind "|" project_id "|" domain "|"
          resource_id "|" owner_id "|" version "|" recipient_id )
```

`kind` is one of: `resource`, `owner-wrap`, `recipient-wrap`, `group-wrap`.
`recipient_id` is the empty string for `resource` and `owner-wrap`.

Vault wraps use a separate, shorter AAD:

```
aad_vault(device_id) = UTF8( "sycore/v1|vault|" device_id )
```

**Why this exists:** it binds each ciphertext to one tenant, one domain, one
resource, one owner, one version and (for wraps) one recipient. Moving a
ciphertext to another row, or relabelling a recipient, makes the AAD differ and
the AEAD open fails. This is what stops a blind-but-untrusted server from
transplanting payloads.

---

## 4. Device envelope (the vault)

`create(password, device_id)`:

```
salt        = random(16)
KEK         = Argon2id(password, salt, §2)              // 32 bytes
VK          = random(32)                                 // vault key, never leaves the device
nonce       = random(12)
wrapped_vk  = AESGCM_SEAL(KEK, VK, aad_vault(device_id))
```

Envelope on the wire:

```json
{
  "v": 1,
  "device_id": "dev_phone",
  "kdf": { "alg": "argon2id", "v": 19, "t": 3, "m": 65536, "p": 4,
           "salt": "<b64u>" },
  "nonce": "<b64u>",
  "wrapped_vk": "<b64u>"
}
```

`unlock(password, envelope)` re-derives `KEK` and opens `wrapped_vk`. Any
failure (wrong password, wrong `device_id`, corrupted tag) MUST be reported as
the same generic error: `vault_unlock_failed`. It MUST NOT reveal which check
failed.

`changePassword(old, new, envelope)`:

1. unlock with `old` → `VK`
2. `salt' = random(16)`, `KEK' = Argon2id(new, salt')`
3. `nonce' = random(12)`, `wrapped_vk' = AESGCM_SEAL(KEK', VK, aad_vault(device_id))`

`VK` MUST be byte-identical before and after. **No content is re-encrypted.**

**Invariant:** one envelope per device. Adding a device adds an envelope; it
never duplicates content.

---

## 5. Resource envelope

```json
{
  "v": 1,
  "id": "res_7f3a",
  "project_id": "prj_home",
  "domain": "health",
  "owner_id": "usr_ali",
  "version": 1,
  "alg": "A256GCM",
  "nonce": "<b64u>",
  "ciphertext": "<b64u>",
  "wraps": [ { "to": "...", "kind": "owner", "epk": "<b64u>",
               "nonce": "<b64u>", "ct": "<b64u>" } ],
  "signature": null
}
```

`wraps` MUST be stored **outside** `ciphertext`. The server needs the list to
authorize reads; if it were sealed inside, the server would have to decrypt —
which is the one thing it must never do.

### 5.1 Sealing

```
CK     = random(32)                                    // content key
ct     = AESGCM_SEAL(CK, plaintext, aad("resource", …))
```

Owner wrap (always present):

```
ct_owner = AESGCM_SEAL(VK, CK, aad("owner-wrap", …, recipient_id=""))
```

Recipient wrap (one per recipient, HOSN / SAMAM):

```
shared = X25519(sk_owner, pk_recipient)
k_wrap = HKDF-SHA256(ikm = shared,
                     salt = pk_owner || pk_recipient,
                     info = UTF8("sycore/v1/hosn/wrap"),
                     L = 32)
ct_r   = AESGCM_SEAL(k_wrap, CK, aad("recipient-wrap", …, recipient_id))
epk    = pk_owner
```

`shared` MUST never be transmitted and MUST NOT be used directly as an AEAD key
(RFC 7748 §6.1). It is always passed through HKDF.

### 5.2 Opening

Recipient:

```
shared = X25519(sk_recipient, epk)
k_wrap = HKDF-SHA256(shared, pk_owner || pk_recipient, "sycore/v1/hosn/wrap", 32)
CK     = AESGCM_OPEN(k_wrap, ct_r, aad("recipient-wrap", …, my_id))
plain  = AESGCM_OPEN(CK, ct, aad("resource", …))
```

Owner (new device): `VK ← unlock(envelope)`, then `CK = AESGCM_OPEN(VK, ct_owner, …)`.

---

## 6. Engines are wrap-counts

The server MUST NOT know an engine name. An engine is a shape of `wraps`:

| Engine | `wraps` |
|---|---|
| Vault | 1 (`owner`) |
| HOSN | 2 (`owner` + 1 `recipient`) |
| SAMAM | 1 + N (`owner` + N `recipient`, same `CK`) |
| JAHR | 0, `signature != null`, `ciphertext` is plaintext |

An implementation MUST NOT branch on engine name when storing or authorizing.

---

## 7. JAHR (public, signed)

Content is stored in clear. Integrity and authorship come from a signature.

```
digest   = SHA256(content_bytes)
canonical = UTF8( "sycore/v1|jahr|" project_id "|" domain "|"
                  resource_id "|" owner_id "|" base64url_nopad(digest) )
signature = Ed25519_SIGN(sk_owner, canonical)
```

Verification MUST:

1. rebuild `canonical` from the **stored** row (not from the payload);
2. resolve `owner_id → pk_owner` from the **identity directory**, not from the
   payload;
3. `Ed25519_VERIFY(pk_owner, canonical, signature)`.

A verifier that uses a public key supplied alongside the signature is not
verifying anything and MUST be considered non-conformant.

---

## 8. Versions and conflicts

- `create` sets `version = 1`.
- `update` carries `base_version`. The server accepts only if
  `base_version == current.version`, then stores `version + 1`.
- Otherwise the server returns `409 version_conflict` with the current version.
- The client MUST NOT auto-merge in v1. It re-fetches and re-applies.

---

## 9. Errors

Fail closed. A protocol error MUST NOT be downgraded to plaintext, and error
messages MUST NOT contain key material, plaintext, or plaintext length.

| Code | When |
|---|---|
| `vault_unlock_failed` | wrong password / device / tag |
| `wrap_open_failed` | AAD mismatch, wrong recipient, tampered wrap |
| `resource_open_failed` | AAD mismatch, tampered ciphertext |
| `signature_invalid` | JAHR verification failed |
| `version_conflict` | §8 |

---

## 10. Known limitations (explicit, not accidental)

1. **No forward secrecy.** `epk` is the owner's static key (v1). If a long-term
   private key leaks, past content decrypts. A future version may add ephemeral
   keys; the field name `epk` already exists so the wire format does not change.
2. **No post-compromise security.** There is no ratchet.
3. **Metadata is visible**: owner, domain, recipient graph, size, timestamps.
   This is deliberate and MUST be stated in any product built on this.
4. **TOFU protects integrity, not confidentiality.** A malicious first writer
   can lock a domain to `PLAIN`. Server-side policy cannot fix a lying client.
5. **No threshold recovery.** Losing the password and the recovery key means
   permanent loss — by design.
6. **No key transparency.** A signed public-key directory (§7) is the intended
   answer; until it is deployed, key substitution is possible.
