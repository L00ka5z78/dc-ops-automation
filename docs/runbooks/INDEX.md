# 📚 Runbook Index

> Procedury operacyjne warstwy automatyzacji. Runbooki infrastruktury bazowej: [dc-operations-lab / runbooks](https://github.com/L00ka5z78/dc-operations-lab/blob/main/docs/runbooks/INDEX.md).

| Runbook | Cel | Kiedy | Status |
| ------- | --- | ----- | ------ |
| [n8n Deployment](n8n-deployment.md) | Wdrożenie, weryfikacja, aktualizacja i backup n8n na dc-monitor-01 | Instalacja, aktualizacja, awaria kontenera | 📝 Gotowy do wykonania (dzień 2) |
| n8n-bot (konto SSH) | Konto serwisowe z ograniczonym sudo na VM-kach | Dodanie nowego hosta / polecenia | 📋 Planowany (dzień 3) |
| Alertmanager → n8n | Receiver webhook, tokeny, test | Zmiana routingu alertów | 📋 Planowany (dzień 6) |
| WF-01 alert-to-incident | Działanie i diagnostyka workflowu | Brak issue po alercie, duplikaty | 📋 Planowany (dzień 10) |
| WF-02 backup-watchdog | Działanie i progi kontroli backupów | Fałszywe alarmy, zmiana harmonogramu backupów | 📋 Planowany (dzień 12) |
| WF-03 container-remediation | Zatwierdzanie i restart kontenerów | Brak odpowiedzi na zatwierdzenie, nieudany restart | 📋 Planowany (dzień 15) |
| WF-04 weekly-ops-report | Źródła danych raportu | Brakujące sekcje raportu | 📋 Planowany (dzień 16) |
