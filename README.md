# 🤖 DC Ops Automation

**Automatyzacja operacji data center oparta o n8n: od alertu Prometheusa do udokumentowanego incydentu — z człowiekiem w pętli decyzyjnej.**

[![Lint](https://github.com/L00ka5z78/dc-ops-automation/actions/workflows/lint.yml/badge.svg)](https://github.com/L00ka5z78/dc-ops-automation/actions/workflows/lint.yml)
[![Base project](https://img.shields.io/badge/Baza-dc--operations--lab-blue)](https://github.com/L00ka5z78/dc-operations-lab)
[![n8n](https://img.shields.io/badge/Orkiestracja-n8n-EA4B71)](docs/architecture.md)
[![Status](https://img.shields.io/badge/Status-w%20trakcie-yellow)](docs/roadmap.md)

> **Kontekst:** projekt rozwija środowisko z [dc-operations-lab](https://github.com/L00ka5z78/dc-operations-lab) (4 VM, 3 VLAN, HA Keepalived, PostgreSQL, Prometheus + Alertmanager, backupy). Infrastruktura jest tam opisana w całości i **nie jest tu powielana** — to repozytorium dokumentuje wyłącznie warstwę automatyzacji.

---

## Problem

W bazowym labie monitoring działa, ale kończy się na powiadomieniu:

- Alertmanager wysyła wiadomość na Slacka i na tym koniec — reszta jest ręczna.
- Incydenty są dokumentowane ręcznie po fakcie (23 wpisy w repo bazowym).
- Skrypty analizy logów i kontroli kontenerów generują raporty, które nikt nie czyta.
- Poprawność backupów jest sprawdzana tylko wtedy, gdy ktoś o tym pamięta.

## Rozwiązanie

Warstwa automatyzacji na n8n, która domyka pętlę **wykrycie → kontekst → reakcja → dokumentacja**:

| ID    | Workflow                | Wyzwalacz                    | Efekt                                                                  | Status       |
| ----- | ----------------------- | ---------------------------- | ---------------------------------------------------------------------- | ------------ |
| WF-01 | `alert-to-incident`     | Webhook z Alertmanagera      | Szkic incydentu jako GitHub Issue (host, metryki, logi, link do runbooka), zamknięcie po `resolved` z czasem trwania | 📋 Planowany |
| WF-02 | `backup-watchdog`       | Harmonogram (codziennie)     | Alert, gdy backup jest za stary lub podejrzanie mały                   | 📋 Planowany |
| WF-03 | `container-remediation` | Harmonogram + SSH            | Restart niezdrowego kontenera **po zatwierdzeniu przez człowieka**     | 📋 Planowany |
| WF-04 | `weekly-ops-report`     | Harmonogram (poniedziałek)   | Tygodniowe podsumowanie: alerty, backupy, dostępność                   | 📋 Planowany |

Opcjonalnie (jeśli starczy czasu): triage alertu z użyciem LLM — streszczenie logów i sugestia runbooka.

## Architektura

```
  Prometheus ──► Alertmanager ──────────────► Slack          (ścieżka podstawowa — działa bez n8n)
                      │
                      └─ webhook + Bearer ─► n8n            (Docker, dc-monitor-01, tylko 127.0.0.1:5678)
                                              │
                                              ├─► Prometheus API   (kontekst: wartości metryk)
                                              ├─► SSH :2222        (konto n8n-bot, ograniczone sudo) ─► dc-srv-01/02/03
                                              ├─► GitHub Issues    (szkice incydentów)
                                              └─► Slack            (powiadomienia, linki zatwierdzające)
```

📖 Szczegóły i uzasadnienie decyzji: [docs/architecture.md](docs/architecture.md)

## Zasady projektowe

1. **Slack zostaje ścieżką podstawową.** n8n jest dodatkiem, nie zależnością krytyczną — awaria orkiestratora nie może wyciszyć alertowania (test: [AUT-001](incidents/AUT-001_n8n-failure-alert-bypass.md)).
2. **Człowiek w pętli** dla każdej akcji zmieniającej stan systemu.
3. **Least privilege:** dedykowany użytkownik SSH, sudo ograniczone do konkretnych poleceń, token GitHub tylko do jednego repo.
4. **Zero sekretów w repo:** workflowy eksportowane bez credentials i danych testowych, skan w CI.
5. **Definition of Done dla workflowu:** przetestowany wyzwalacz + screenshoty + runbook + wpis `AUT-xxx` + wyeksportowany JSON.

## Stack

| Warstwa           | Technologia                                   |
| ----------------- | --------------------------------------------- |
| Orkiestracja      | n8n (self-hosted, Docker Compose)             |
| Źródło zdarzeń    | Prometheus + Alertmanager (z projektu bazowego) |
| Dostęp do hostów  | SSH (port 2222, klucz, ograniczone sudo)      |
| Rejestr incydentów| GitHub Issues                                 |
| Powiadomienia     | Slack                                         |
| CI                | GitHub Actions (ShellCheck, walidacja YAML/JSON, skan sekretów) |

## Struktura repozytorium

```
dc-ops-automation/
├── .github/workflows/lint.yml     # CI: ShellCheck, walidacja, skan sekretów
├── configs/
│   ├── alertmanager/              # receiver webhook → n8n (+ Slack jako ścieżka podstawowa)
│   └── prometheus/                # job i alert dla samego n8n
├── docs/
│   ├── architecture.md            # architektura i decyzje projektowe
│   ├── roadmap.md                 # plan 4 tygodni z checklistą
│   ├── security.md                # model zagrożeń, inwentarz sekretów
│   └── runbooks/                  # procedury operacyjne
├── incidents/                     # incydenty i testy odporności (prefiks AUT-)
├── n8n/
│   ├── docker/                    # docker-compose.yml, .env.example
│   └── workflows/                 # wyeksportowane workflowy (JSON, bez sekretów)
├── scripts/                       # preflight, eksport workflowów
└── screenshots/                   # dowody działania
```

## Szybki start

1. Przygotuj środowisko bazowe ([dc-operations-lab](https://github.com/L00ka5z78/dc-operations-lab)) i zrób migawki VM.
2. Wykonaj preflight: `scripts/preflight-mon1.sh`
3. Wdróż n8n według runbooka: [docs/runbooks/n8n-deployment.md](docs/runbooks/n8n-deployment.md)

## Postęp

Aktualny plan i checklista: [docs/roadmap.md](docs/roadmap.md)

## Kontakt

**Autor:** Łukasz
**GitHub:** [github.com/L00ka5z78](https://github.com/L00ka5z78)
**LinkedIn:** [linkedin.com/in/łukasz-bolach](https://www.linkedin.com/in/%C5%82ukasz-bolach/?locale=en)

## Licencja

MIT — szczegóły w pliku [LICENSE](LICENSE).

---

**Status projektu:** 🟡 W trakcie — faza 1 (fundament)
**Ostatnia aktualizacja:** 2026-11-05
