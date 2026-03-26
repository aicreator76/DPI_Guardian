# CRITICITA_NOTE — Issue and Risk Tracking

This document tracks known issues, risks, and open items for DPI_Guardian.

---

## Active Issues

| ID | Severity | Component | Description | Status | Owner |
|---|---|---|---|---|---|
| — | — | — | No active issues | — | — |

---

## Known Risks

| ID | Risk | Impact | Likelihood | Mitigation | Status |
|---|---|---|---|---|---|
| R01 | Demo data not updated before presentation | Dashboard shows stale data | Medium | Verify `01_DEMO_DATI/` before each run | Open |
| R02 | PowerShell execution policy blocks script | Demo launcher fails | Low | Run `Set-ExecutionPolicy RemoteSigned` if needed | Open |
| R03 | Browser compatibility issue with dashboard | UI broken or unreadable | Low | Test on Chrome or Edge before presentation | Open |

---

## Resolved Issues

| ID | Severity | Component | Description | Resolution | Date |
|---|---|---|---|---|---|
| — | — | — | No resolved issues yet | — | — |

---

## Notes

- Update this file whenever a new issue is discovered or resolved.
- Severity levels: `Critical` / `High` / `Medium` / `Low`
- Status values: `Open` / `In Progress` / `Resolved` / `Closed`
