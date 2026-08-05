# ✅ GuardianAI — Submission Checklist & Dry-Run

**Deadline:** Aug 10 (submit early!) • **Submission:** personalized GitHub link
via the CoCo Quest 2026 form.

## A. Repository content (push all of these)
- [ ] `README.md` (root) — with architecture image rendering
- [ ] `docs/architecture.png` — save the generated diagram here
- [ ] `docs/DEMO_SCRIPT.md`
- [ ] `docs/SUBMISSION_CHECKLIST.md`
- [ ] `sql/01` … `sql/15` (+ `sql/10_fallback_no_cortex.sql`)
- [ ] `data/customers_bad.csv`, `orders_bad.csv`, `products_bad.csv`
- [ ] `app/guardianai_app.py`
- [ ] `screenshots/` — see section C

## B. Full pipeline dry-run (do this once, end to end)
Run in a fresh worksheet, in order, confirming each result:
- [ ] `01`–`02` → tables created
- [ ] `03` → row counts ~15 each
- [ ] `04`–`05` → **OVERALL = 43**, 15 issues, 5 critical
- [ ] `06`–`08` → `DQ_ISSUE_ANALYSIS` has root cause + impact for all 15
- [ ] `09` → exec summary paragraph generated
- [ ] `11`–`13` → fixes approved + executed, quarantine populated
- [ ] `14` → **OVERALL = 97**, all tables LOW
- [ ] `15` → governance log populated
- [ ] App → all 5 pages load and match the numbers above

## C. Screenshots to capture (for README + submission)
- [ ] Page 1 — Overview showing 97/100 + before→after chart
- [ ] Page 1 — (optional) the 43/100 CRITICAL state *before* remediation
- [ ] Page 2 — Findings Explorer filtered to CRITICAL
- [ ] Page 3 — AI Investigation, ORPHAN_ORDER expanded (root cause + impact)
- [ ] Page 4 — Remediation Center showing a fix with confidence/risk + approval
- [ ] Page 5 — Governance Log audit trail

> Tip: capture the 43 "before" shot by screenshotting Page 1 after running 05,
> **before** running 13/14. Or re-run the pipeline to reset.

## D. README polish
- [ ] Architecture image renders (path `docs/architecture.png`)
- [ ] Results table shows 43 → 97
- [ ] Setup steps run cleanly on a fresh account
- [ ] No secrets/credentials committed
- [ ] Repo is accessible via your personalized GitHub link

## E. Optional but high-value
- [ ] 5–6 min demo video (use `DEMO_SCRIPT.md`), link in README
- [ ] A short "Responsible AI" callout box in the README (already included)
- [ ] Pin the repo / clean commit history

## F. Final submission steps
- [ ] Confirm the personalized GitHub link opens for a logged-out viewer (or per rules)
- [ ] Submit the link through the CoCo Quest 2026 form
- [ ] Submit **before** Aug 10 — don't wait for the deadline
- [ ] Screenshot the submission confirmation

## Scoring self-check (map your repo to the weights)
- [ ] **Agentic AI (35%)** — 6-agent loop + self-validation clearly shown
- [ ] **Business value (25%)** — 43→97 + exec-language impact
- [ ] **Snowflake/CoCo (20%)** — Cortex + Streamlit + procs + SQL analytics
- [ ] **Responsible AI (15%)** — approval gate + quarantine + audit log
- [ ] **UI polish (5%)** — clean 5-page app, color-coded scores

---
*You're on track. Submit early, then relax. 🛡️*
