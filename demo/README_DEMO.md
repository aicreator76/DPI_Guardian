# DPI_Guardian — Demo Launch Instructions

This document explains how to run the DPI_Guardian local demo.

---

## Requirements

- Windows OS
- PowerShell 5.1 or later
- A modern web browser (Chrome, Edge, or Firefox)

---

## How to Launch the Demo

1. Open the `demo/` folder in Windows Explorer
2. Double-click **`START_DEMO.bat`**
3. The dashboard will open automatically in your default browser

---

## Manual Launch (PowerShell)

If the batch launcher does not work, you can run the demo manually:

```powershell
# From the repo root
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser   # only needed once
.\demo\04_SCRIPT\DPI_GUARDIAN_RUN.ps1
```

Then open the dashboard in your browser:

```
demo/03_PRESENTAZIONE/console/index.html
```

---

## Demo Structure

| Folder / File | Description |
|---|---|
| `START_DEMO.bat` | Main launcher — double-click to start |
| `01_DEMO_DATI/` | Sample input data used by the demo |
| `02_OUTPUT/` | Output files generated after script execution |
| `03_PRESENTAZIONE/console/index.html` | Browser-based dashboard |
| `04_SCRIPT/DPI_GUARDIAN_RUN.ps1` | Core data processing script |
| `05_SUPPORTO/` | Support materials and reference files |

---

## Troubleshooting

**PowerShell execution is blocked**  
Run once in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy RemoteSigned
```

**Dashboard does not load**  
Open `demo/03_PRESENTAZIONE/console/index.html` directly in your browser.

**No output is generated**  
Ensure at least one data file exists in `demo/01_DEMO_DATI/` before running the script.

---

## Validation

To verify the demo structure is intact before presenting, run:

```powershell
.\scripts\smoke_test.ps1
```
