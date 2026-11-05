# AUT-001 — Awaria n8n nie może wyciszyć alertowania (test odporności)

| Pole              | Wartość                                              |
| :---------------- | :--------------------------------------------------- |
| Data              | _do uzupełnienia (dzień 4)_                          |
| Typ               | Test odporności (kontrolowane wstrzyknięcie awarii)  |
| Dotyczy           | n8n, Alertmanager (routing), Prometheus (alert `n8nDown`) |
| Severity          | Medium (test)                                        |
| Status            | **Planned**                                          |
| Powiązane         | [architecture.md — D-03, D-04](../docs/architecture.md), `configs/alertmanager/alertmanager.yml`, `configs/prometheus/rules/n8n-alerts.yml` |

> Ten wpis jest planem testu. Sekcje wyników zostają puste, dopóki test nie zostanie wykonany — nie uzupełniaj ich z założenia.

## Cel i hipotezy

Sprawdzić, czy orkiestrator nie jest pojedynczym punktem awarii dla alertowania.

- **H1:** Po zatrzymaniu kontenera n8n alert `n8nDown` dociera na Slacka w ok. 2 minuty, bez udziału n8n.
- **H2:** Alerty innych komponentów nadal docierają na Slacka, mimo że webhook do n8n zwraca błąd (Alertmanager obsługuje integracje jednego receivera niezależnie).
- **H3:** Po ponownym uruchomieniu n8n alert przechodzi w `resolved` i Slack dostaje powiadomienie o wygaśnięciu.

Oczekiwany czas wykrycia (H1): interwał scrape (15 s) + `for: 1m` + `group_wait` (30 s) ≈ 1 min 45 s.

## Plan testu

1. Zrzut stanu wyjściowego: `docker compose ps`, targety w Prometheusie (`n8n` = UP).
2. `docker compose stop n8n` — zapisz godzinę.
3. Obserwuj: Prometheus (`n8n` = DOWN, alert pending → firing), Alertmanager, Slack. Zapisz godziny.
4. W trakcie awarii wywołaj inny alert (np. zatrzymaj `node_exporter` na jednym hoście) i sprawdź, czy dociera na Slacka (H2). Przywróć `node_exporter`.
5. `docker compose start n8n` — sprawdź `resolved` (H3).
6. Sprawdź w logach Alertmanagera, jak wygląda nieudana próba webhooka.

## Kryteria sukcesu

- [ ] H1: alert na Slacku w ≤ 3 min od zatrzymania
- [ ] H2: alert z innego komponentu dociera na Slacka mimo niedostępnego n8n
- [ ] H3: wiadomość `resolved` po restarcie

## Wyniki

_Do uzupełnienia po teście._

## Oś czasu

| Czas | Zdarzenie |
| :--- | :-------- |
|      |           |

## Wnioski i działania zapobiegawcze

_Do uzupełnienia po teście._
