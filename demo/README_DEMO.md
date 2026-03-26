# DPI_Guardian — Avvio Demo

## Avvio rapido

```bat
demo\START_DEMO.bat
```

Oppure, dalla cartella `demo\`:

```bat
START_DEMO.bat
```

---

## Cosa fa la demo

1. Avvia lo script operativo `04_SCRIPT\DPI_GUARDIAN_RUN.ps1`
2. Apre la dashboard web `03_PRESENTAZIONE\console\index.html` nel browser predefinito
3. Carica i dati di esempio da `01_DEMO_DATI\`

---

## Requisiti

- Windows 10 / 11
- PowerShell 5.1+
- Browser moderno (Chrome, Edge, Firefox)

---

## Verifica preliminare

Prima della presentazione, eseguire lo smoke test:

```powershell
..\scripts\smoke_test.ps1
```

---

## Problemi comuni

| Problema | Soluzione |
|----------|-----------|
| La dashboard non si apre | Aprire manualmente `03_PRESENTAZIONE\console\index.html` nel browser |
| PowerShell blocca l'esecuzione | Eseguire `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
