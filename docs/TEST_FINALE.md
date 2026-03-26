# TEST_FINALE — Final Validation Checklist

Use this checklist before each release or demo presentation to confirm the product is fully operational.

---

## Pre-Launch Checks

- [ ] `demo/START_DEMO.bat` exists and is executable
- [ ] `demo/03_PRESENTAZIONE/console/index.html` exists and opens correctly in browser
- [ ] `demo/04_SCRIPT/DPI_GUARDIAN_RUN.ps1` exists and is syntactically valid
- [ ] At least one data file exists in `demo/01_DEMO_DATI/`
- [ ] `demo/02_OUTPUT/` directory exists (may be empty before first run)
- [ ] `demo/05_SUPPORTO/` directory exists with support materials

## Smoke Test

- [ ] `scripts/smoke_test.ps1` runs without errors
- [ ] All smoke test checks return `OK`

## Dashboard

- [ ] Dashboard (`index.html`) loads without errors in browser
- [ ] Dashboard displays expected DPI data or placeholder content
- [ ] No broken links or missing assets in the dashboard

## Script Execution

- [ ] `DPI_GUARDIAN_RUN.ps1` executes without fatal errors
- [ ] Output files are generated in `demo/02_OUTPUT/` after script run

## Documentation

- [ ] `README.md` is present and up to date
- [ ] `demo/README_DEMO.md` contains accurate launch instructions
- [ ] `docs/CRITICITA_NOTE.md` reflects current known issues

---

## Sign-Off

| Item | Status | Notes |
|---|---|---|
| Smoke test | ☐ Pass / ☐ Fail | |
| Dashboard | ☐ Pass / ☐ Fail | |
| Script execution | ☐ Pass / ☐ Fail | |
| Documentation | ☐ Pass / ☐ Fail | |

**Validated by:** ___________________  
**Date:** ___________________
