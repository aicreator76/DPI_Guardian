# DPI_Guardian

**DPI_Guardian** is a local demo product for monitoring and managing Personal Protective Equipment (DPI — *Dispositivi di Protezione Individuale*) in workplace environments.

---

## Overview

DPI_Guardian provides:

- A browser-based dashboard for real-time DPI status monitoring
- Automated PowerShell scripts for data processing and reporting
- Structured demo data for presentation and validation
- A self-contained launcher (`START_DEMO.bat`) for immediate local execution

---

## Repository Structure

```
DPI_Guardian/
├── demo/
│   ├── START_DEMO.bat               # Main launcher
│   ├── README_DEMO.md               # Demo launch instructions
│   ├── 01_DEMO_DATI/                # Sample input data
│   ├── 02_OUTPUT/                   # Generated output files
│   ├── 03_PRESENTAZIONE/
│   │   └── console/
│   │       └── index.html           # Browser dashboard
│   ├── 04_SCRIPT/
│   │   └── DPI_GUARDIAN_RUN.ps1     # Core processing script
│   └── 05_SUPPORTO/                 # Support and reference files
├── docs/
│   ├── TEST_FINALE.md               # Final validation checklist
│   └── CRITICITA_NOTE.md            # Issue and risk tracking
└── scripts/
    └── smoke_test.ps1               # Automated smoke test
```

---

## Quick Start

1. Clone or download this repository
2. Navigate to the `demo/` folder
3. Double-click `START_DEMO.bat` to launch the demo
4. The dashboard will open in your default browser

For detailed instructions, see [`demo/README_DEMO.md`](demo/README_DEMO.md).

---

## Validation

Run the smoke test to verify the demo structure is intact:

```powershell
.\scripts\smoke_test.ps1
```

See [`docs/TEST_FINALE.md`](docs/TEST_FINALE.md) for the full validation checklist.

---

## Requirements

- Windows OS
- PowerShell 5.1 or later
- A modern web browser (Chrome, Edge, Firefox)

---

## Documentation

| File | Description |
|---|---|
| [`demo/README_DEMO.md`](demo/README_DEMO.md) | Demo launch instructions |
| [`docs/TEST_FINALE.md`](docs/TEST_FINALE.md) | Final validation checklist |
| [`docs/CRITICITA_NOTE.md`](docs/CRITICITA_NOTE.md) | Issue and risk tracking |
| [`scripts/smoke_test.ps1`](scripts/smoke_test.ps1) | Automated smoke test |

---

## License

Internal use only. All rights reserved.
