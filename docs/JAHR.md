---
marp: true
theme: default
paginate: true
backgroundColor: #f8f9fa
style: |
  h1 {
    color: #2c3e50;
  }
  h2 {
    color: #34495e;
    border-bottom: 2px solid #3498db;
    padding-bottom: 10px;
  }
  strong {
    color: #e74c3c;
  }
  p, li {
    font-size: 1.1em;
    line-height: 1.5;
  }
---

# 📢 JAHR Engine
## Public Signed Data
**Verifiable Plaintext for the Zero-Trust Era**

---

## 🎯 The Concept

**JAHR** is the SYCORE Framework's cryptographic pattern for **Authenticated Public Data**.

Unlike HOSN or SAMAM which hide data from the server, JAHR assumes the data *should* be readable (e.g., public profiles, open forum posts, system logs). 

**The Challenge:** How do we prove the data is authentic if the server is considered "dumb" or potentially untrusted?
**The Solution:** Cryptographic Digital Signatures handled entirely by the Smart SDK.

---

## 🔑 How it Works: Ed25519 Signatures

Instead of encryption, JAHR relies on asymmetric signing using `Ed25519` keys.

- **Data is PLAIN:** The payload remains in readable JSON format.
- **The Signature:** The SDK generates a mathematical proof (signature) that only the true owner of the Private Key could create.
- **The Guarantee:** If the server or an attacker modifies even a single character of the JSON data, the signature instantly becomes invalid, alerting the receiving client to the tampering.

---

## 🔄 Data Flow: Signing & Verifying

**📤 Creating Data (The Author):**
1. The user's SDK structures the data payload (JSON).
2. The SDK hashes the payload and signs the hash using the user's **Ed25519 Private Key**.
3. The SDK sends the Server the **Plaintext Data + The Signature**.

**📥 Reading Data (The Public or System):**
1. A client fetches the Plaintext Data from the server.
2. The client SDK retrieves the author's **Public Key**.
3. The SDK automatically verifies the Signature against the Data.
4. If valid, the UI trusts it. If invalid, the UI rejects it as tampered.

---

## 🗄️ Server Capabilities (PLAIN Clearance)

Because JAHR data is submitted under the `PLAIN` security clearance, the Zero-Trust Server is allowed to process it:

- **Searchability:** The server stores the payload as `JSONB`, allowing efficient querying, filtering, and indexing directly in PostgreSQL.
- **Immutability Enforcement:** The Policy Immutability Gate (TOFU) locks JAHR domains to `PLAIN`. Any attempt to mix encrypted `E2EE` data into an established JAHR domain is rejected.

---

## ✅ Summary

**JAHR** brings strict mathematical authenticity to open data. It provides the performance benefits of a traditional backend (searchable data and sorting) while retaining the absolute integrity and tamper-evidence guarantees of the **SY-2139 Protocol**.
