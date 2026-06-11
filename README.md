# AeroTrack — Blockchain-Based Aviation Spare Parts Tracking

> A blockchain lab project implementing on-chain provenance, ownership, and maintenance tracking for aviation spare parts using **Ethereum (Solidity)** and **Hyperledger Fabric (Go + Node.js)**.

---

## 📁 Repository Structure

```
aerotrack-blockchain/
├── implementation_plan.md      ← Architecture & design plan
├── task.md                     ← Progress checklist
├── decrypted_needs.md          ← Full requirements specification
├── README.md                   ← This file
├── .gitignore
│
├── ethereum/
│   ├── AeroTrack.sol           ← Basic Ethereum contract (open manufacturing)
│   └── AeroTrackPlus.sol       ← Extended contract (certified manufacturers only)
│
├── fabric/
│   ├── chaincode/
│   │   ├── go.mod              ← Go module definition
│   │   └── smartcontract.go    ← Go chaincode (all exercises implemented)
│   └── application/
│       ├── package.json        ← Node.js dependencies (includes qrcode)
│       ├── app.js              ← Express REST API (all exercises)
│       └── addToWallet.js      ← Fabric identity enrollment script
│
└── docs/
    └── report.tex              ← Full LaTeX report (English)
```

---

## Part 1 — Ethereum Smart Contracts

### Quick Start (Remix IDE)

1. Open [Remix IDE](https://remix.ethereum.org) in your browser.
2. Create a new file and paste the content of `ethereum/AeroTrack.sol`.
3. Go to **Solidity Compiler** → Select `0.8.0+` → Click **Compile**.
4. Go to **Deploy & Run Transactions** → Select **Remix VM (Osaka)** → Click **Deploy**.
5. Interact using the low-level interaction panel.

### AeroTrack.sol — Contract Functions

| Function | Description |
|---|---|
| `manufacturePart(uint256, string)` | Register a new part (anyone) |
| `transferPart(uint256, address)` | Transfer ownership (current owner only) |
| `logMaintenance(uint256, string)` | Append maintenance note (owner or manufacturer) |
| `retirePart(uint256)` | Mark part as Retired |
| `getPart(uint256)` | Read full part data |
| `getMaintenanceLogs(uint256)` | Read all maintenance notes |

### AeroTrackPlus.sol — Additional Functions

| Function | Access | Description |
|---|---|---|
| `approveManufacturer(address, string)` | Owner only | Add to certified whitelist |
| `revokeManufacturer(address)` | Owner only | Remove from whitelist |
| `isManufacturerCertified(address)` | Anyone | Returns `(bool, string)` |
| `manufacturePart(uint256, string)` | Certified only | Restricted registration |

### Test Scenario (AeroTrackPlus)

```
Account 1 (Owner): Deploy contract
Account 2:         manufacturePart(999, "Boeing 737 Landing Gear") → REVERT
Account 1:         approveManufacturer(Account2_addr, "Boeing")    → SUCCESS
                   isManufacturerCertified(Account2_addr)          → (true, "Boeing")
Account 2:         manufacturePart(999, "Boeing 737 Landing Gear") → SUCCESS
                   parts(999)                                       → full struct
Account 1:         revokeManufacturer(Account2_addr)               → SUCCESS
Account 2:         manufacturePart(...)                             → REVERT
```

---

## Part 2 — Hyperledger Fabric

### Prerequisites

- Docker & Docker Compose
- Node.js v14+ & npm
- Go v1.19+
- Hyperledger Fabric binaries + Docker images

### Setup Steps

```bash
# 1. Start the Fabric network
cd fabric/network
./start.sh

# 2. Deploy the chaincode
./deployChaincode.sh

# 3. Install Node.js dependencies
cd ../application
npm install

# 4. Enroll the app user identity
node addToWallet.js

# 5. Start the API server
node app.js
```

Server will be available at `http://localhost:3000`

### API Endpoints

| Method | Endpoint | Body / Params | Description |
|---|---|---|---|
| `POST` | `/parts` | `{id, name, manufacturer, owner, productionDate}` | Create part |
| `GET` | `/parts/:id` | — | Read part + QR code |
| `PUT` | `/parts/:id/transfer` | `{newOwner}` | Transfer ownership |
| `DELETE` | `/parts/:id` | — | Delete part |
| `GET` | `/parts/:id/history` | — | Full transaction history |
| `POST` | `/parts/:id/maintenance` | `{message}` | Add maintenance log |

### Example cURL Commands

```bash
# Create a part
curl -X POST http://localhost:3000/parts \
     -H "Content-Type: application/json" \
     -d '{"id":"part-123","name":"Alternator","manufacturer":"Bosch","owner":"Factory","productionDate":"2024-01-15"}'

# Read a part (includes QR code)
curl http://localhost:3000/parts/part-123

# Transfer ownership
curl -X PUT http://localhost:3000/parts/part-123/transfer \
     -H "Content-Type: application/json" \
     -d '{"newOwner":"Dealer-A"}'

# Delete a part
curl -X DELETE http://localhost:3000/parts/part-123

# Get transaction history
curl http://localhost:3000/parts/part-123/history

# Add maintenance log
curl -X POST http://localhost:3000/parts/part-123/maintenance \
     -H "Content-Type: application/json" \
     -d '{"message":"10000h inspection — no fatigue detected"}'
```

---

## Report

The full project report is available as a LaTeX source in `docs/report.tex`.

To compile to PDF:

```bash
pdflatex docs/report.tex
pdflatex docs/report.tex  # Run twice for TOC
```

Or use Overleaf by uploading `report.tex`.

---

## Exercises Implemented

| # | Exercise | File |
|---|---|---|
| 1 | Add `productionDate` field | `smartcontract.go` |
| 2 | Implement `DeletePart` | `smartcontract.go` |
| 3 | Implement `GetPartHistory` | `smartcontract.go` |
| 4 | API: `DELETE /parts/:id` | `app.js` |
| 5 | API: `GET /parts/:id/history` | `app.js` |
| 6 | Request logging middleware | `app.js` |
| 7 | Transaction flow diagram | `docs/report.tex` |
| 8 | Network topology diagram | `docs/report.tex` |
| 9 | QR code generation | `app.js` |
| 10 | Maintenance log feature | `smartcontract.go` + `app.js` |
| 11 | MSP-based access control | `smartcontract.go` |

---

## License

MIT
