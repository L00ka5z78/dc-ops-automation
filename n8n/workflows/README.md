# Workflowy n8n

Wyeksportowane workflowy (JSON). **Bez sekretów** — credentials w n8n są przechowywane osobno (szyfrowane `N8N_ENCRYPTION_KEY`), a w JSON występują wyłącznie jako odwołania (id i nazwa).

## Konwencja nazw

`WF-<nr>-<opis>.json`, np. `wf-01-alert-to-incident.json` (nazwa pliku powstaje ze slugu nazwy workflowu w n8n — nazywaj workflowy `WF-01 alert to incident` itd.).

## Eksport

Z maszyny, na której działa kontener:

```bash
./scripts/export-n8n-workflows.sh
git diff --stat n8n/workflows
```

Skrypt:

- eksportuje wszystkie workflowy z kontenera (`n8n export:workflow`),
- usuwa `pinData` (przypięte dane testowe — mogą zawierać nazwy hostów i fragmenty logów) oraz `staticData` (stan runtime),
- **odmawia zapisu**, jeśli w pliku wykryje wzorce tokenów lub kluczy (np. token GitHub, token Slacka, nagłówek `Bearer`, klucz prywatny).

## Import

W UI n8n: *Workflows → Import from File*, albo w kontenerze:

```bash
docker cp n8n/workflows/wf-01-alert-to-incident.json n8n:/tmp/wf.json
docker exec n8n n8n import:workflow --input=/tmp/wf.json
```

Po imporcie przypisz credentials ręcznie (SSH, GitHub, Slack, Header Auth).

## Lista

| Plik | Workflow | Status |
| ---- | -------- | ------ |
| —    | WF-01 alert-to-incident     | 📋 planowany |
| —    | WF-02 backup-watchdog       | 📋 planowany |
| —    | WF-03 container-remediation | 📋 planowany |
| —    | WF-04 weekly-ops-report     | 📋 planowany |
