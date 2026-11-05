# Dowody działania

Konwencja nazw: `<obszar>/NN-krótki-opis.png`, np. `n8n-deployment/01-preflight-result.png`.

Przed dodaniem screenshota sprawdź, czy nie pokazuje: tokenów, adresów webhooków Slacka, kluczy SSH, wartości `N8N_ENCRYPTION_KEY`.

| Obszar | Zawartość | Status |
| ------ | --------- | ------ |
| `n8n-deployment/` | Preflight, `docker compose ps`, `ss -tlnp`, UI | 📋 |
| `monitoring-n8n/` | Job `n8n` w Prometheusie, alert `n8nDown` | 📋 |
| `wf-01-alert-to-incident/` | Alert, workflow, wygenerowane issue | 📋 |
| `wf-02-backup-watchdog/` | Test starego backupu, alert | 📋 |
| `wf-03-container-remediation/` | Zatwierdzenie, restart, weryfikacja | 📋 |
| `wf-04-weekly-ops-report/` | Raport na Slacku | 📋 |
