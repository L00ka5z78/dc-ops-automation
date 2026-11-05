# Roadmapa

Plan: 4 tygodnie × 5 dni × ok. 3 h. Rytm dnia: ~2 h budowa, ~30 min test, ~30 min dokumentacja i screenshoty.

**Reguły:**

- Commit codziennie, mały i opisowy.
- Gdy plan się wydłuża, tnij opcjonalny WF-05 (AI) i WF-04, a nie testy i dokumentację.
- Workflow jest skończony dopiero po spełnieniu Definition of Done: przetestowany wyzwalacz, screenshoty, runbook, wpis `AUT-xxx`, wyeksportowany JSON.

## Dzień 0 — przygotowanie

- [ ] Wyłączone VM-ki, migawki `lab-v1-final` wszystkich czterech naraz (spójny stan replikacji PostgreSQL)
- [ ] Eksport OVF na zewnętrzny dysk
- [ ] Puste repo na GitHubie, pierwszy commit ze szkieletem

## Tydzień 1 — fundament

- [x] **D1** Szkielet repo, README, diagram docelowej architektury
- [x] **D2** `preflight-mon1.sh`, Docker na dc-monitor-01, n8n uruchomiony (`127.0.0.1:5678`), dostęp przez tunel SSH, konto właściciela
- [ ] **D3** Hardening: potwierdzenie, że port nie jest wystawiony (`ss -tlnp`), `iptables-save` z mon1 do dokumentacji, użytkownik `n8n-bot` + ograniczone sudo + klucz SSH, `AllowUsers`
- [ ] **D4** Monitoring samego n8n: job w Prometheusie, alert `n8nDown` omijający n8n, test awarii → **AUT-001**
- [ ] **D5** Workflow testowy (webhook z tokenem → Slack), pierwszy eksport workflowów, przegląd tygodnia

## Tydzień 2 — WF-01 alert → szkic incydentu

- [ ] **D6** Receiver webhook w Alertmanagerze (Slack zostaje), webhook w n8n z uwierzytelnieniem, zapis przykładowego payloadu
- [ ] **D7** Wzbogacanie: Prometheus API + logi z dc-srv-03
- [ ] **D8** Token GitHub (fine-grained, tylko Issues, jedno repo), tworzenie issue wg szablonu
- [ ] **D9** Obsługa `resolved`, deduplikacja po `fingerprint`
- [ ] **D10** Test end-to-end prawdziwym alertem, screenshoty → **AUT-002**

## Tydzień 3 — WF-02 i WF-03

- [ ] **D11** Porządek w crontab (zduplikowane i ucięte wpisy backupu w repo bazowym) → **AUT-003**
- [ ] **D12** WF-02: kontrola backupów, test przez `touch -d` / wyłączenie crona
- [ ] **D13–14** WF-03: wykrywanie niezdrowych kontenerów, zatwierdzenie, restart przez SSH, weryfikacja `/health`
- [ ] **D15** Test całego cyklu (zatrzymanie kontenera), screenshoty → **AUT-004**

## Tydzień 4 — raport, szlify, prezentacja

- [ ] **D16** WF-04: raport tygodniowy
- [ ] **D17** *(opcjonalnie)* WF-05: triage z LLM
- [ ] **D18** Przegląd bezpieczeństwa: skan sekretów w historii, workflowy bez credentials, uzupełnienie `docs/security.md`
- [ ] **D19** README końcowe, diagram przepływu, odtworzenie środowiska od zera według dokumentacji
- [ ] **D20** Wideo demo (2–3 min), link w README projektu bazowego, opis do CV/LinkedIn
