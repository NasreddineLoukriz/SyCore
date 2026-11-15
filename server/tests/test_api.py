"""The server's contract, as tests. Nothing here decrypts anything."""

from __future__ import annotations

import pathlib
import re

import pytest
from fastapi.testclient import TestClient

from sycore_server import main
from sycore_server.store import Store


@pytest.fixture()
def client(tmp_path, monkeypatch) -> TestClient:
    monkeypatch.setattr(main, "store", Store(tmp_path / "test.db"))
    return TestClient(main.app)


def identity(client: TestClient, user: str) -> None:
    r = client.post("/v1/identities", json={
        "user_id": user, "dh_pub": f"{user}-dh", "sign_pub": f"{user}-sig",
    })
    assert r.status_code == 201, r.text


def envelope(rid: str, owner: str, *, version: int = 1,
             recipients: list[str] | None = None,
             signature: str | None = None,
             ciphertext: str = "CT0") -> dict:
    wraps = [{"to": owner, "kind": "owner", "epk": "EPK", "nonce": "N0NCE0N0NCE0",
              "ct": "OWNER_WRAP"}]
    for rec in recipients or []:
        wraps.append({"to": rec, "kind": "recipient", "epk": "EPK",
                      "nonce": "N0NCE0N0NCE0", "ct": f"WRAP_{rec}"})
    return {
        "id": rid, "project_id": "prj", "domain": "health", "owner_id": owner,
        "version": version, "nonce": "N0NCE0N0NCE0", "ciphertext": ciphertext,
        "wraps": wraps, "signature": signature,
    }


def test_identity_roundtrip_and_key_conflict(client: TestClient) -> None:
    identity(client, "usr_ali")
    got = client.get("/v1/identities/usr_ali")
    assert got.status_code == 200
    assert got.json()["dh_pub"] == "usr_ali-dh"

    again = client.post("/v1/identities", json={
        "user_id": "usr_ali", "dh_pub": "usr_ali-dh", "sign_pub": "usr_ali-sig"})
    assert again.status_code == 201  # idempotent

    clash = client.post("/v1/identities", json={
        "user_id": "usr_ali", "dh_pub": "OTHER", "sign_pub": "usr_ali-sig"})
    assert clash.status_code == 409
    assert clash.json()["error"]["code"] == "key_conflict"

    assert client.get("/v1/identities/nobody").status_code == 404


def test_put_and_get_authorised_by_metadata(client: TestClient) -> None:
    identity(client, "usr_ali")
    identity(client, "usr_sara")
    identity(client, "usr_mona")

    put = client.post("/v1/resources",
                      headers={"X-Sycore-User": "usr_ali"},
                      json={"clearance": "E2EE",
                            "envelope": envelope("res_1", "usr_ali",
                                                 recipients=["usr_sara"])})
    assert put.status_code == 201, put.text

    owner = client.get("/v1/resources/res_1", headers={"X-Sycore-User": "usr_ali"})
    assert owner.status_code == 200
    assert owner.json()["ciphertext"] == "CT0"

    sara = client.get("/v1/resources/res_1", headers={"X-Sycore-User": "usr_sara"})
    assert sara.status_code == 200

    mona = client.get("/v1/resources/res_1", headers={"X-Sycore-User": "usr_mona"})
    assert mona.status_code == 403
    assert mona.json()["error"]["code"] == "forbidden"

    anon = client.get("/v1/resources/res_1")
    assert anon.status_code == 403

    assert client.get("/v1/resources/res_999",
                      headers={"X-Sycore-User": "usr_ali"}).status_code == 404


def test_write_requires_owner_and_a_user(client: TestClient) -> None:
    identity(client, "usr_ali")
    body = {"clearance": "E2EE", "envelope": envelope("res_1", "usr_ali")}

    assert client.post("/v1/resources", json=body).status_code == 401
    other = client.post("/v1/resources", headers={"X-Sycore-User": "usr_sara"},
                        json=body)
    assert other.status_code == 403
    assert other.json()["error"]["code"] == "not_owner"


def test_versioning_is_optimistic(client: TestClient) -> None:
    identity(client, "usr_ali")
    h = {"X-Sycore-User": "usr_ali"}
    assert client.post("/v1/resources", headers=h, json={
        "clearance": "E2EE", "envelope": envelope("res_1", "usr_ali")}).status_code == 201

    stale = client.post("/v1/resources", headers=h, json={
        "clearance": "E2EE", "envelope": envelope("res_1", "usr_ali", version=1)})
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "version_conflict"

    ahead = client.post("/v1/resources", headers=h, json={
        "clearance": "E2EE", "envelope": envelope("res_1", "usr_ali", version=5)})
    assert ahead.status_code == 409

    fresh = client.post("/v1/resources", headers=h, json={
        "clearance": "E2EE",
        "envelope": envelope("res_1", "usr_ali", version=2, ciphertext="CT1")})
    assert fresh.status_code == 201
    assert fresh.json()["version"] == 2
    assert client.get("/v1/resources/res_1", headers=h).json()["ciphertext"] == "CT1"


def test_tofu_blocks_data_poisoning(client: TestClient) -> None:
    identity(client, "usr_ali")
    h = {"X-Sycore-User": "usr_ali"}
    assert client.post("/v1/resources", headers=h, json={
        "clearance": "E2EE", "envelope": envelope("res_1", "usr_ali")}).status_code == 201

    plain = envelope("res_2", "usr_ali", ciphertext="aGVsbG8")
    plain["wraps"] = []
    plain["nonce"] = ""
    poisoned = client.post("/v1/resources", headers=h, json={
        "clearance": "PLAIN", "envelope": plain})
    assert poisoned.status_code == 422
    assert poisoned.json()["error"]["code"] == "data_poisoning_rejected"

    assert client.get("/v1/resources?project_id=prj&domain=health").json()["policy"] == "E2EE"


def test_jahr_is_public_and_requires_a_signature(client: TestClient) -> None:
    identity(client, "usr_ali")
    unsigned = client.post("/v1/resources", headers={"X-Sycore-User": "usr_ali"},
                           json={"clearance": "JAHR",
                                 "envelope": envelope("post_1", "usr_ali")})
    assert unsigned.status_code == 422

    post = envelope("post_1", "usr_ali", signature="SIG", ciphertext="hello")
    post["wraps"] = []
    post["nonce"] = ""
    signed = client.post("/v1/resources", headers={"X-Sycore-User": "usr_ali"},
                         json={"clearance": "JAHR", "envelope": post})
    assert signed.status_code == 201

    # anybody, including a stranger with no account, may read it
    anon = client.get("/v1/resources/post_1")
    assert anon.status_code == 200
    assert anon.json()["ciphertext"] == "hello"


def test_listing_filters_by_readership(client: TestClient) -> None:
    for u in ("usr_ali", "usr_sara", "usr_mona"):
        identity(client, u)
    h = {"X-Sycore-User": "usr_ali"}
    for rid, recs in (("res_1", ["usr_sara"]), ("res_2", []), ("res_3", ["usr_mona"])):
        client.post("/v1/resources", headers=h, json={
            "clearance": "E2EE", "envelope": envelope(rid, "usr_ali", recipients=recs)})

    sara = client.get("/v1/resources?project_id=prj&domain=health",
                      headers={"X-Sycore-User": "usr_sara"}).json()
    assert {r["id"] for r in sara["resources"]} == {"res_1"}

    ali = client.get("/v1/resources?project_id=prj&domain=health",
                     headers={"X-Sycore-User": "usr_ali"}).json()
    assert {r["id"] for r in ali["resources"]} == {"res_1", "res_2", "res_3"}
    assert ali["resources"][0]["ciphertext_chars"] > 0
    assert "ciphertext" not in ali["resources"][0]

    # listing never carries content
    body = client.get("/v1/resources?project_id=prj&domain=health",
                      headers=h).text
    assert "CT0" not in body


def test_audit_records_refusals(client: TestClient) -> None:
    identity(client, "usr_ali")
    client.post("/v1/resources", headers={"X-Sycore-User": "usr_ali"},
                json={"clearance": "E2EE", "envelope": envelope("res_1", "usr_ali")})
    client.get("/v1/resources/res_1", headers={"X-Sycore-User": "usr_mona"})

    entries = client.get("/v1/audit").json()["entries"]
    actions = {e["action"] for e in entries}
    assert "resource.put" in actions
    assert "read.denied" in actions


def test_health_reports_zero_crypto(client: TestClient) -> None:
    body = client.get("/health").json()
    assert body["ok"] is True
    assert body["crypto_lines"] == 0
    assert body["stats"]["resources"] >= 0


def test_the_server_source_contains_no_cryptography() -> None:
    root = pathlib.Path(main.__file__).parent
    banned = re.compile(
        r"\b(AES|GCM|X25519|Ed25519|HKDF|Argon2?|SHA256|sha256|hmac|encrypt|decrypt|"
        r"cipher_text|private_key|secret_key)\b",
        re.IGNORECASE,
    )
    offenders = []
    for path in sorted(root.glob("*.py")):
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if banned.search(line):
                offenders.append(f"{path.name}:{n}: {line.strip()}")
    assert offenders == [], "\n".join(offenders)
