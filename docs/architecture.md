# Architektura — warstwa automatyzacji

> Dokument opisuje tylko to, co dodaje ten projekt. Topologia sieci, HA, DNS, bazy danych i monitoring bazowy: [dc-operations-lab / architecture](https://github.com/L00ka5z78/dc-operations-lab/blob/main/docs/architecture.md).

## Komponenty

| Komponent        | Gdzie                          | Rola w automatyzacji                                              |
| ---------------- | ------------------------------ | ----------------------------------------------------------------- |
| n8n              | dc-monitor-01 (Docker)         | Orkiestrator workflowów                                           |
| Prometheus       | dc-monitor-01 `:9090`          | Źródło metryk (API zapytań) i reguł alertów                       |
| Alertmanager     | dc-monitor-01 `:9093`          | Źródło zdarzeń — receiver webhook do n8n                          |
| dc-srv-01/02/03  | VLAN 20, SSH `:2222`           | Cele poleceń wykonywanych przez konto `n8n-bot`                   |
| dc-srv-03        | `/backup/`, `/var/log/remote/` | Magazyn backupów i centralnych logów (źródło danych dla WF-02/04) |
| GitHub           | zewnętrzny                     | Rejestr szkiców incydentów (Issues)                               |
| Slack            | zewnętrzny                     | Powiadomienia i linki zatwierdzające                              |

## Przepływ danych

```
 node_exporter ──► Prometheus ──► Alertmanager ──┬─► Slack            (zawsze, bez n8n)
 (4 hosty)             ▲                         │
                       │ HTTP GET (kontekst)     └─► n8n  127.0.0.1:5678   (webhook + Bearer)
                       │                              │
                       └──────────────────────────────┤
                                                      ├─► SSH :2222 (n8n-bot) ─► dc-srv-01 / 02 / 03
                                                      ├─► GitHub Issues
                                                      └─► Slack (powiadomienia, linki zatwierdzające)
```

## Workflowy

### WF-01 — alert → szkic incydentu

1. Alertmanager wysyła POST (JSON, nagłówek `Authorization: Bearer …`) na webhook n8n.
2. n8n odrzuca żądania bez poprawnego tokenu.
3. Dla alertu `firing`: sprawdza, czy istnieje już otwarte issue z tym samym `fingerprint` (deduplikacja — Alertmanager powtarza powiadomienia co `repeat_interval`).
4. Wzbogaca dane: zapytanie do API Prometheusa (aktualna wartość metryki) i ostatnie linie logów z `dc-srv-03:/var/log/remote/` *(układ katalogów do potwierdzenia w tygodniu 2)*.
5. Tworzy GitHub Issue z etykietą `incident`, wypełnione według szablonu incydentu, z linkiem do właściwego runbooka.
6. Dla alertu `resolved`: dopisuje komentarz z czasem trwania i zamyka issue.

### WF-02 — kontrola backupów

- Harmonogram: codziennie rano, po oknie backupu konfiguracji (02:00) z [runbooka backupów](https://github.com/L00ka5z78/dc-operations-lab/blob/main/docs/runbooks/backup-restore.md).
- SSH → `dc-srv-03`: wiek i rozmiar najnowszego archiwum w `/backup/configs/`, tail logu `/var/log/dc-config-backup.log`.
- Warunki alarmu: archiwum starsze niż 25 h, rozmiar poniżej progu, błąd w logu. Dla backupu pełnego (niedziela 03:00) próg 8 dni.
- Dlaczego osobno od Prometheusa: metryki hosta nie powiedzą, że zadanie cron się nie wykonało.
- Ścieżki i nazwy plików pochodzą z dokumentacji repo bazowego — **do potwierdzenia na żywym środowisku** w dniu 12.

### WF-03 — restart kontenera z zatwierdzeniem

- Wyzwalacz: harmonogram (co kilka minut) + SSH `docker ps --filter health=unhealthy` na dc-srv-02/03. Baza nie ma exportera kontenerów (cAdvisor), więc nie ma metryki, na której można oprzeć alert Prometheusa.
- Węzeł *Send and Wait for Response* wysyła wiadomość z linkiem zatwierdzającym.
- Po zatwierdzeniu: SSH → `sudo docker restart <kontener>` → weryfikacja `/health` → wynik na Slacka.
- Brak odpowiedzi w limicie czasu = brak akcji + eskalacja.

### WF-04 — raport tygodniowy

- Harmonogram: poniedziałek rano.
- Zbiera: liczbę alertów z tygodnia (z GitHub Issues), status backupów, dostępność hostów (Prometheus), wynik skryptu `log-error-summary-report.sh`.
- Wysyła podsumowanie na Slacka.

## Decyzje projektowe

| #    | Decyzja                                                          | Uzasadnienie                                                                                         | Koszt / kompromis                                                        |
| ---- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| D-01 | n8n na **dc-monitor-01**                                         | Alertmanager jest lokalnie, więc webhook idzie po `127.0.0.1` — bez nowych reguł sieciowych.         | Trzeba doinstalować Dockera; maszyna ma ograniczone zasoby.              |
| D-02 | n8n nasłuchuje tylko na **127.0.0.1**, dostęp przez tunel SSH    | Zero ekspozycji sieciowej. Docker publikuje porty z pominięciem łańcucha `INPUT` iptables, więc reguły INPUT nie chroniłyby portu opublikowanego na interfejsie sieciowym. | Linki zatwierdzające działają tylko przy otwartym tunelu.                |
| D-03 | Slack jako ścieżka podstawowa, webhook do n8n jako dodatek       | Awaria orkiestratora nie może wyciszyć alertowania.                                                  | Duplikacja konfiguracji receivera.                                       |
| D-04 | Alerty o samym n8n omijają n8n                                   | Orkiestrator nie może być jedynym kanałem informującym o własnej awarii.                             | Osobna ścieżka routingu w Alertmanagerze.                                |
| D-05 | GitHub Issues jako rejestr szkiców incydentów                    | Brak dodatkowej infrastruktury, historia, etykiety, API.                                             | Szkic wymaga ręcznego uzupełnienia RCA i przeniesienia do `incidents/`.  |
| D-06 | Akcje zmieniające stan tylko po zatwierdzeniu                    | Automat nie może sam pogorszyć sytuacji (np. restartować w pętli).                                   | Wolniejsza reakcja niż w pełni automatycznej wersji.                     |
| D-07 | Sekrety poza repo i poza konfiguracją (`*_file`, `.env`, credentials n8n) | Placeholder w konfiguracji już raz spowodował cichą awarię alertowania (INC-014 w repo bazowym). | Pliki sekretów trzeba utrzymywać na hoście.                              |

## Do potwierdzenia na żywym środowisku

- Reguły firewalla na dc-monitor-01 (repo bazowe zawiera tylko reguły routera dc-srv-01) — zapisać wynik `iptables-save` w tygodniu 1.
- Układ katalogów w `/var/log/remote/` na dc-srv-03.
- Czy `sshd` na VM-kach ma `AllowUsers` — jeśli tak, dopisać `n8n-bot`.
