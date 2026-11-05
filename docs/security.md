# Bezpieczeństwo

n8n będzie miał klucze SSH do maszyn labu, token GitHub i dostęp do Slacka. To czyni go celem wartościowym, więc traktujemy go jak komponent uprzywilejowany.

> Status zabezpieczeń: **📋 planowane** — kolumna „Status" zmieniamy na ✅ dopiero po wdrożeniu i teście danej mitygacji.

## Model zagrożeń

| Zagrożenie                                                      | Skutek                                       | Mitygacja                                                                                                                  | Status |
| --------------------------------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------ |
| Podatność w n8n (w 2026 ogłoszono wiele krytycznych advisories) | Przejęcie orkiestratora i kluczy SSH         | Brak ekspozycji sieciowej (`127.0.0.1`), przypięta wersja (bez `latest`), regularne aktualizacje, ograniczone uprawnienia kont | 📋     |
| Nieuprawnione wywołanie webhooka                                | Fałszywe incydenty, spam, próby akcji        | Uwierzytelnienie nagłówkiem Bearer, token w pliku poza repo                                                                | 📋     |
| Przejęcie klucza SSH `n8n-bot`                                  | Wykonanie poleceń na VM-kach                 | Osobne konto, `from="10.20.20.10"` w `authorized_keys`, sudo tylko dla wymienionych poleceń, rotacja                       | 📋     |
| Wyciek sekretów do repozytorium                                 | Kompromitacja kont zewnętrznych              | `.gitignore`, eksport workflowów bez credentials i `pinData`, skan sekretów w CI                                           | 📋     |
| Automat pogarsza sytuację                                       | Pętla restartów, utrata danych               | Akcje tylko po zatwierdzeniu, limit czasu, brak akcji przy braku odpowiedzi                                                | 📋     |
| Awaria n8n wycisza alerty                                       | Brak informacji o incydentach                | Slack jako ścieżka podstawowa, alert `n8nDown` omijający n8n (test: AUT-001)                                               | 📋     |
| Utrata klucza szyfrującego n8n                                  | Credentials nie do odczytania po odtworzeniu | Kopia `N8N_ENCRYPTION_KEY` poza serwerem (menedżer haseł), backup wolumenu                                                 | 📋     |

## Zasady

1. **Brak ekspozycji sieciowej.** Port n8n opublikowany wyłącznie na `127.0.0.1`. Dostęp do UI przez tunel SSH.
2. **Przypięta wersja.** Nigdy `latest`. Aktualizacja świadoma: eksport workflowów, backup wolumenu, zmiana `N8N_VERSION`, `pull`, `up -d`.
3. **Sudo bez wildcardów.** Konto `n8n-bot` dostaje w `sudoers` dokładne polecenia (np. `/usr/bin/docker restart flask-app-01`), a nie `docker *` i nie członkostwo w grupie `docker` (ta jest równoważna uprawnieniom roota).
4. **Najmniejsze uprawnienia tokenów.** Token GitHub typu fine-grained, uprawnienie tylko do Issues, tylko to repo.
5. **Sekrety poza konfiguracją.** Slack: `slack_api_url_file`. Webhook: `credentials_file`. n8n: wbudowany magazyn credentials (szyfrowany `N8N_ENCRYPTION_KEY`).

## Inwentarz sekretów

| Sekret                      | Gdzie przechowywany                                                    | Kto używa          | Rotacja                                             |
| --------------------------- | ---------------------------------------------------------------------- | ------------------ | --------------------------------------------------- |
| Slack webhook URL           | `/etc/alertmanager/slack_webhook_url` (mon1, tylko do odczytu dla alertmanager) | Alertmanager | Przy podejrzeniu wycieku                            |
| Token webhooka n8n          | `/etc/alertmanager/n8n_webhook_token` (mon1) + credential w n8n         | Alertmanager, n8n  | Co kwartał                                          |
| Klucz SSH `n8n-bot`         | Credential w n8n (szyfrowany)                                          | n8n                | Co kwartał                                          |
| Token GitHub (fine-grained) | Credential w n8n (szyfrowany)                                          | n8n                | Wg daty wygaśnięcia tokenu                          |
| `N8N_ENCRYPTION_KEY`        | `/opt/n8n/.env` (chmod 600) + kopia w menedżerze haseł                 | Kontener n8n       | Rzadko (wymaga ponownego wprowadzenia credentials)  |

## Kontrola przed publikacją

- [ ] Przeszukanie historii gita pod kątem sekretów: `git log -p | grep -iE "hooks.slack|ghp_|github_pat_|xox[bp]-|PRIVATE KEY"` — brak trafień
- [ ] Pliki w `n8n/workflows/` nie zawierają tokenów ani danych testowych (`pinData`)
- [ ] CI (skan sekretów) zielone
- [ ] Zrzuty ekranu nie pokazują tokenów, adresów webhooków ani kluczy
