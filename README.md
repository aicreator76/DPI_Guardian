# DPI_Guardian

**Strumento operativo per il monitoraggio e la gestione dei Dispositivi di Protezione Individuale (DPI) in contesti aziendali e industriali.**

---

## Descrizione

DPI_Guardian è un sistema demo funzionante che automatizza la verifica, la tracciabilità e la reportistica dei DPI aziendali. Il progetto è strutturato per essere presentabile, portabile e facilmente validabile da qualsiasi cliente o revisore tecnico.

---

## Struttura del repository

```
DPI_Guardian/
├── demo/                        # Demo funzionante e pronta alla presentazione
│   ├── 01_DEMO_DATI/            # Dati di esempio per la demo
│   ├── 03_PRESENTAZIONE/        # Dashboard web di presentazione
│   │   └── console/
│   │       └── index.html
│   ├── 04_SCRIPT/               # Script operativi core
│   │   └── DPI_GUARDIAN_RUN.ps1
│   ├── START_DEMO.bat           # Avvio rapido della demo
│   └── README_DEMO.md           # Istruzioni sintetiche per la demo
├── docs/
│   ├── TEST_FINALE.md           # Checklist di validazione finale
│   └── CRITICITA_NOTE.md        # Registro criticità e rischi
├── scripts/
│   └── smoke_test.ps1           # Smoke test automatico della struttura
└── README.md                    # Questo file
```

---

## Prerequisiti

- Windows 10 / 11
- PowerShell 5.1 o superiore
- Browser moderno (Chrome, Edge, Firefox)

---

## Avvio rapido

```bat
demo\START_DEMO.bat
```

Per istruzioni dettagliate sulla demo, consultare [`demo/README_DEMO.md`](demo/README_DEMO.md).

---

## Validazione

Per verificare l'integrità della struttura del repository prima della presentazione:

```powershell
.\scripts\smoke_test.ps1
```

---

## Documentazione

| Documento | Descrizione |
|-----------|-------------|
| [`docs/TEST_FINALE.md`](docs/TEST_FINALE.md) | Checklist di test finale pre-presentazione |
| [`docs/CRITICITA_NOTE.md`](docs/CRITICITA_NOTE.md) | Registro criticità, rischi e note operative |

---

## Licenza

Uso interno riservato. Tutti i diritti riservati.
