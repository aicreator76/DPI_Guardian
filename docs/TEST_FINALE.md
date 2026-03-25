# TEST_FINALE — Checklist di Validazione Pre-Presentazione

**Progetto:** DPI_Guardian  
**Data compilazione:** ___________  
**Compilato da:** ___________

---

## 1. Struttura Repository

- [ ] `demo/START_DEMO.bat` presente e funzionante
- [ ] `demo/03_PRESENTAZIONE/console/index.html` presente e apribile da browser
- [ ] `demo/04_SCRIPT/DPI_GUARDIAN_RUN.ps1` presente ed eseguibile
- [ ] `demo/01_DEMO_DATI/` contiene almeno un file di dati
- [ ] `scripts/smoke_test.ps1` eseguito senza errori

---

## 2. Avvio Demo

- [ ] `START_DEMO.bat` avvia la dashboard senza errori
- [ ] La console web si apre correttamente nel browser
- [ ] I dati di esempio sono visibili nella dashboard

---

## 3. Script Operativi

- [ ] `DPI_GUARDIAN_RUN.ps1` si avvia senza errori di sintassi
- [ ] I log di esecuzione sono generati correttamente
- [ ] Nessun percorso assoluto hardcoded non portabile

---

## 4. Documentazione

- [ ] `README.md` completo e aggiornato
- [ ] `demo/README_DEMO.md` istruzioni chiare per l'avvio
- [ ] `docs/CRITICITA_NOTE.md` aggiornato con eventuali note aperte

---

## 5. Portabilità

- [ ] Repository clonato su macchina pulita
- [ ] Demo avviata senza installazioni aggiuntive non documentate
- [ ] Percorsi relativi funzionanti

---

## Esito Finale

| Stato | Descrizione |
|-------|-------------|
| ✅ APPROVATO | Tutti i controlli superati, demo pronta per presentazione |
| ⚠️ CONDIZIONALE | Criticità minori documentate, presentazione possibile con nota |
| ❌ NON APPROVATO | Criticità bloccanti, presentazione da rinviare |

**Esito:** ___________  
**Note:** ___________
