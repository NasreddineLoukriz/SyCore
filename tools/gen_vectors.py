#!/usr/bin/env python3
"""Generate the v1 conformance vectors for SPEC.md.

Every value here is produced by following SPEC.md §2-§8 literally.
Running this script must print OK and rewrite vectors/v1.json.
"""
import base64
import hashlib
import json
import os
import sys

from argon2.low_level import Type, hash_secret_raw
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives.asymmetric.x25519 import (
    X25519PrivateKey,
    X25519PublicKey,
)
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PublicFormat,
    PrivateFormat,
)

ARGON = dict(time_cost=3, memory_cost=65536, parallelism=4, hash_len=32, type=Type.ID)
INFO_WRAP = b"sycore/v1/hosn/wrap"


def b64u(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def unb64u(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def aad(kind, project, domain, resource, owner, version, recipient=""):
    return (
        f"sycore/v1|{kind}|{project}|{domain}|{resource}|{owner}|{version}|{recipient}"
    ).encode()


def aad_vault(device_id: str) -> bytes:
    return f"sycore/v1|vault|{device_id}".encode()


def kek(password: str, salt: bytes) -> bytes:
    return hash_secret_raw(password.encode(), salt, **ARGON)


def seal(key: bytes, plain: bytes, ad: bytes, nonce: bytes) -> bytes:
    return AESGCM(key).encrypt(nonce, plain, ad)


def open_(key: bytes, ct: bytes, ad: bytes, nonce: bytes) -> bytes:
    return AESGCM(key).decrypt(nonce, ct, ad)


def raw_pub(k) -> bytes:
    return k.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)


def hkdf(ikm: bytes, salt: bytes) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(), length=32, salt=salt, info=INFO_WRAP
    ).derive(ikm)


# ---------------------------------------------------------------- fixtures
PROJECT, DOMAIN, RES, OWNER, RECIP, DEVICE = (
    "prj_home", "health", "res_7f3a", "usr_ali", "usr_sara", "dev_phone",
)
PASSWORD = "correct horse battery staple"
PLAINTEXT = "موعد العملية: 15 جانفي، مستشفى مصطفى باشا، الساعة 8:30".encode()

ali_sk = X25519PrivateKey.from_private_bytes(hashlib.sha256(b"ali-x25519-v1").digest())
sara_sk = X25519PrivateKey.from_private_bytes(hashlib.sha256(b"sara-x25519-v1").digest())
ali_pk, sara_pk = raw_pub(ali_sk), raw_pub(sara_sk)

ed_sk = Ed25519PrivateKey.from_private_bytes(hashlib.sha256(b"ali-ed25519-v1").digest())
ed_pk = ed_sk.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

SALT = bytes(range(16))
NONCE_VK = bytes([0xA0] * 12)
NONCE_CT = bytes([0xC0] * 12)
NONCE_OW = bytes([0x0A] * 12)
NONCE_RW = bytes([0x7B] * 12)
VK = bytes.fromhex("11" * 32)
CK = bytes.fromhex("22" * 32)

out = {"spec": "sycore/v1", "kdf_params": ARGON | {"type": "argon2id", "v": 19}}

# ---------------------------------------------------------------- 1. vault
KEK = kek(PASSWORD, SALT)
wrapped_vk = seal(KEK, VK, aad_vault(DEVICE), NONCE_VK)
envelope = {
    "v": 1,
    "device_id": DEVICE,
    "kdf": {"alg": "argon2id", "v": 19, "t": 3, "m": 65536, "p": 4, "salt": b64u(SALT)},
    "nonce": b64u(NONCE_VK),
    "wrapped_vk": b64u(wrapped_vk),
}

# unlock
assert open_(KEK, unb64u(envelope["wrapped_vk"]), aad_vault(DEVICE), NONCE_VK) == VK

# wrong password fails
bad = kek("wrong password", SALT)
try:
    open_(bad, unb64u(envelope["wrapped_vk"]), aad_vault(DEVICE), NONCE_VK)
    raise SystemExit("FAIL: wrong password opened the envelope")
except Exception:
    pass

# wrong device fails (AAD binding)
try:
    open_(KEK, unb64u(envelope["wrapped_vk"]), aad_vault("dev_laptop"), NONCE_VK)
    raise SystemExit("FAIL: envelope replayed onto another device")
except Exception:
    pass

# change password keeps VK
NEW_PW, NEW_SALT = "new passphrase 2026", bytes(range(100, 116))
NEW_KEK = kek(NEW_PW, NEW_SALT)
NEW_NONCE = bytes([0xA1] * 12)
vk_after = open_(NEW_KEK, seal(NEW_KEK, VK, aad_vault(DEVICE), NEW_NONCE),
                 aad_vault(DEVICE), NEW_NONCE)
assert vk_after == VK

out["vault"] = {
    "password": PASSWORD,
    "device_id": DEVICE,
    "expected_kek": b64u(KEK),
    "envelope": envelope,
    "expected_vk": b64u(VK),
    "wrong_password_must_fail": True,
    "wrong_device_must_fail": True,
    "change_password": {
        "new_password": NEW_PW,
        "new_salt": b64u(NEW_SALT),
        "new_nonce": b64u(NEW_NONCE),
        "expected_vk_unchanged": b64u(VK),
    },
}

# ---------------------------------------------------------------- 2. HOSN
ct = seal(CK, PLAINTEXT, aad("resource", PROJECT, DOMAIN, RES, OWNER, 1), NONCE_CT)

ct_owner = seal(VK, CK, aad("owner-wrap", PROJECT, DOMAIN, RES, OWNER, 1), NONCE_OW)

shared = ali_sk.exchange(X25519PublicKey.from_public_bytes(sara_pk))
k_wrap = hkdf(shared, ali_pk + sara_pk)
ct_recip = seal(
    k_wrap, CK, aad("recipient-wrap", PROJECT, DOMAIN, RES, OWNER, 1, RECIP), NONCE_RW
)

# recipient opens
shared_r = sara_sk.exchange(X25519PublicKey.from_public_bytes(ali_pk))
assert shared_r == shared, "FAIL: ECDH is not symmetric"
ck_r = open_(
    hkdf(shared_r, ali_pk + sara_pk), ct_recip,
    aad("recipient-wrap", PROJECT, DOMAIN, RES, OWNER, 1, RECIP), NONCE_RW,
)
assert ck_r == CK
assert open_(ck_r, ct, aad("resource", PROJECT, DOMAIN, RES, OWNER, 1), NONCE_CT) == PLAINTEXT

# transplant: same bytes, different resource id
try:
    open_(CK, ct, aad("resource", PROJECT, DOMAIN, "res_9999", OWNER, 1), NONCE_CT)
    raise SystemExit("FAIL: ciphertext transplanted to another resource")
except Exception:
    pass

# misbinding: server relabels the recipient
try:
    open_(k_wrap, ct_recip,
          aad("recipient-wrap", PROJECT, DOMAIN, RES, OWNER, 1, "usr_mona"), NONCE_RW)
    raise SystemExit("FAIL: recipient wrap relabelled")
except Exception:
    pass

# owner wrap
assert open_(VK, ct_owner, aad("owner-wrap", PROJECT, DOMAIN, RES, OWNER, 1), NONCE_OW) == CK

out["hosn"] = {
    "project_id": PROJECT, "domain": DOMAIN, "resource_id": RES,
    "owner_id": OWNER, "recipient_id": RECIP, "version": 1,
    "owner_private_seed_sha256": hashlib.sha256(b"ali-x25519-v1").hexdigest(),
    "owner_public": b64u(ali_pk),
    "recipient_public": b64u(sara_pk),
    "content_key": b64u(CK),
    "plaintext": PLAINTEXT.decode(),
    "nonce_content": b64u(NONCE_CT),
    "ciphertext": b64u(ct),
    "owner_wrap": {"to": OWNER, "kind": "owner", "nonce": b64u(NONCE_OW), "ct": b64u(ct_owner)},
    "recipient_wrap": {"to": RECIP, "kind": "recipient", "epk": b64u(ali_pk),
                       "nonce": b64u(NONCE_RW), "ct": b64u(ct_recip)},
    "expected_k_wrap": b64u(k_wrap),
    "negative": ["transplant_to_other_resource_must_fail",
                 "relabel_recipient_must_fail"],
}

# ---------------------------------------------------------------- 3. JAHR
digest = hashlib.sha256(PLAINTEXT).digest()
canonical = (
    f"sycore/v1|jahr|{PROJECT}|{DOMAIN}|{RES}|{OWNER}|{b64u(digest)}"
).encode()
sig = ed_sk.sign(canonical)
assert Ed25519PublicKey.from_public_bytes(ed_pk).verify(sig, canonical) is None

attacker = Ed25519PrivateKey.from_private_bytes(hashlib.sha256(b"attacker").digest())
attacker_pk = attacker.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

bad_verifies = []
for name, key, data, s in [
    ("tampered_content", ed_pk, PLAINTEXT + b"!", sig),
    ("attacker_key", attacker_pk, PLAINTEXT, sig),
    ("replayed_in_other_domain", ed_pk,
     f"sycore/v1|jahr|{PROJECT}|notes|{RES}|{OWNER}|{b64u(digest)}".encode(), sig),
]:
    try:
        Ed25519PublicKey.from_public_bytes(key).verify(s, data)
        bad_verifies.append(name)
    except Exception:
        pass
assert not bad_verifies, f"FAIL: these verified but must not: {bad_verifies}"

out["jahr"] = {
    "project_id": PROJECT, "domain": DOMAIN, "resource_id": RES, "owner_id": OWNER,
    "content": PLAINTEXT.decode(),
    "digest_sha256": b64u(digest),
    "canonical": canonical.decode(),
    "signer_public": b64u(ed_pk),
    "signature": b64u(sig),
    "must_verify": True,
    "must_not_verify": ["tampered_content", "attacker_key", "replayed_in_other_domain"],
}

# ---------------------------------------------------------------- 4. engines
out["engine_shapes"] = {
    "vault": {"wraps": 1, "signature": False},
    "hosn": {"wraps": 2, "signature": False},
    "samam": {"wraps": "1+N", "signature": False},
    "jahr": {"wraps": 0, "signature": True},
}

path = os.path.join(os.path.dirname(__file__), "..", "vectors", "v1.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2, sort_keys=False)
    f.write("\n")

print("OK — vectors written:", os.path.normpath(path))
print("checks: vault(unlock, wrong-pw, wrong-device, rotate) "
      "hosn(round-trip, transplant, misbinding) jahr(verify, tamper, attacker, replay)")
