# n8n — wdrożenie na dc-monitor-01

**Purpose:** Uruchomić n8n w Dockerze na dc-monitor-01 tak, aby nie był dostępny z sieci, a UI było osiągalne przez tunel SSH
**Use when:** Pierwsza instalacja, aktualizacja wersji, odtworzenie po awarii
**Prerequisites:** Dostęp SSH do dc-monitor-01 (`10.20.20.10`, port 2222), działające Prometheus i Alertmanager, migawki VM zrobione
**Severity:** P3 (automatyzacja nie jest ścieżką krytyczną — Slack działa niezależnie)
**Key commands:** `docker compose`, `curl /healthz`, `ss -tlnp`

---

## 1. Preflight

```bash
# Na dc-monitor-01 (jako root, żeby skrypt mógł potwierdzić dostęp do iptables)
sudo ./scripts/preflight-mon1.sh
```

Skrypt tylko czyta stan systemu. Oczekiwane: brak `[FAIL]`. Jeśli brakuje Dockera — krok 2. Zapisz wynik `iptables-save` (firewall mon1 nie jest opisany w repo bazowym):

```bash
sudo iptables-save | tee ~/mon1-iptables-$(date +%F).txt
```

## 2. Docker (jeśli brak)

Użyj skryptu `setup-docker.sh` z projektu bazowego (`infrastructure/srv3/scripts/docker/`).

> Członkostwo w grupie `docker` daje uprawnienia równoważne rootowi. W labie to akceptowalne dla konta administratora, ale **nie** nadawaj go kontom serwisowym.

## 3. Pliki wdrożeniowe

```bash
sudo mkdir -p /opt/n8n && sudo chown "$USER": /opt/n8n
cp n8n/docker/docker-compose.yml n8n/docker/.env.example /opt/n8n/
cd /opt/n8n
cp .env.example .env && chmod 600 .env
```

Uzupełnij `.env`:

```bash
# Klucz szyfrujący credentials
openssl rand -hex 32          # wynik wklej do N8N_ENCRYPTION_KEY

# N8N_VERSION: sprawdź aktualną stabilną wersję w release notes n8n
# oraz w GitHub Security Advisories (n8n-io/n8n). Nie używaj 'latest'.
```

**Zapisz kopię `N8N_ENCRYPTION_KEY` w menedżerze haseł.** Bez niego credentials w odtworzonej instancji będą nie do odczytania.

## 4. Start

```bash
cd /opt/n8n
docker compose --env-file .env config -q   # walidacja składni i zmiennych
docker compose --env-file .env up -d
docker compose ps
docker compose logs --tail=50 n8n
```

## 5. Weryfikacja

```bash
# Zdrowie aplikacji
curl -s http://127.0.0.1:5678/healthz

# Metryki dla Prometheusa
curl -s http://127.0.0.1:5678/metrics | head

# Port tylko na loopbacku — oczekiwane: 127.0.0.1:5678, NIE 0.0.0.0:5678
ss -tlnp | grep 5678

# Status healthchecka kontenera
docker inspect -f '{{.State.Health.Status}}' n8n
```

## 6. Dostęp do UI (tunel SSH)

Z laptopa (trasę dostosuj tak jak przy tunelu do Grafany):

```bash
ssh -p 2222 -L 5678:127.0.0.1:5678 dcadmin@10.20.20.10
```

Otwórz `http://localhost:5678`, utwórz konto właściciela (silne hasło, włącz 2FA w ustawieniach konta).

> Używaj `localhost`, nie adresu IP: przeglądarka akceptuje ciasteczka *secure* na `localhost` przez HTTP, a przez adres IP po HTTP n8n zwykle zgłasza błąd o secure cookie.

## 7. Dowody (screenshoty)

- Wynik `preflight-mon1.sh`
- `docker compose ps` + `ss -tlnp | grep 5678` (adres `127.0.0.1`)
- `/healthz` i UI n8n po zalogowaniu (bez danych wrażliwych)

## Aktualizacja

```bash
# 1. Eksport workflowów i backup wolumenu (patrz niżej)
./scripts/export-n8n-workflows.sh

# 2. Zmień N8N_VERSION w /opt/n8n/.env, następnie:
cd /opt/n8n
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose logs --tail=50 n8n
```

## Backup wolumenu

```bash
docker run --rm -v n8n_data:/data -v "$PWD":/backup alpine \
  tar czf "/backup/n8n_data-$(date +%F).tar.gz" -C /data .
```

Archiwum zawiera zaszyfrowane credentials i bazę wykonań — przechowuj poza repo (`*.tar.gz` jest w `.gitignore`).

## Rollback

```bash
cd /opt/n8n
docker compose down         # zatrzymuje kontener, DANE ZOSTAJĄ w wolumenie
# docker compose down -v    # UWAGA: usuwa wolumen n8n_data (workflowy, credentials, historię)
```

Powrót do poprzedniej wersji: przywróć poprzednią wartość `N8N_VERSION`, `up -d`. Jeśli nowa wersja zmigrowała bazę, wróć do backupu wolumenu.

## Troubleshooting

| Objaw | Prawdopodobna przyczyna | Co sprawdzić |
| ----- | ----------------------- | ------------ |
| `docker compose` kończy się błędem o `N8N_VERSION` / `N8N_ENCRYPTION_KEY` | Pusta zmienna w `.env` | `grep -E "N8N_(VERSION|ENCRYPTION_KEY)" .env` (bez wklejania wartości na screenshot) |
| Kontener restartuje się w pętli | Błąd konfiguracji, uprawnienia wolumenu | `docker compose logs n8n` |
| Status `unhealthy` | Aplikacja jeszcze startuje lub nie odpowiada | `docker compose logs n8n`, `curl http://127.0.0.1:5678/healthz` |
| Błąd o *secure cookie* w przeglądarce | Dostęp przez IP po HTTP | Użyj tunelu i `http://localhost:5678` |
| n8n nie łączy się z Prometheusem na hoście | Firewall mon1 blokuje ruch z podsieci Dockera (`172.30.0.0/24`) do `:9090` | `iptables-save`; ewentualna reguła INPUT dla `172.30.0.0/24` na port 9090 — zapisz zmianę w dokumentacji |
| Port 5678 widoczny na `0.0.0.0` | Zmieniony mapping portów | Przywróć `127.0.0.1:5678:5678` w `docker-compose.yml` |

## Notatki z pierwszego wdrożenia (2026-11-05)

- **Dysk:** wolumen `/` na mon1 miał 10 GB mimo 18 GB w VG (wolne 8,2 GB). Przed instalacją Dockera rozszerzony: `sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv`. Preflight wymaga ≥ 5 GB wolnego.
- **Docker:** `setup-docker.sh` z repo bazowego przerywał się na starcie (wywołanie niezdefiniowanej funkcji `log_info`), dlatego Docker zainstalowano ręcznie według oficjalnej procedury apt.
- **Pobieranie obrazu:** przy pierwszej próbie połączenie z rejestrem zerwało się (`failed to send write: EOF`); ponowienie dokończyło pobieranie (łącznie ok. 12 minut). Warstwy zostają w cache, więc `docker compose pull` można bezpiecznie powtarzać.
- **Wersja:** n8n 2.46.6, przypięta w `.env`.
- **Firewall:** zmiany po instalacji Dockera opisane w [mon1-firewall-baseline.md](../mon1-firewall-baseline.md).
