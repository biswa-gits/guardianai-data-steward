# 🛡️ GuardianAI: Autonomous Data Steward for Snowflake

> **CoCoQuest 2026 — Theme 1: Agentic Data Quality Guardian**
> An event-driven, multi-agent system that **detects, explains, remediates, and
> validates** data quality across five related tables in Snowflake — with
> volume-aware scoring, cross-table integrity checks, a human-in-the-loop
> approval gate, and a full governance audit trail.

**One-line pitch:** GuardianAI turns messy, growing data into *trusted* data —
autonomously, continuously, and safely — and proves it with a live data trust
score that recovers the moment a human approves a fix.

---

## 1. The Problem
Bad data silently breaks business decisions. Duplicate customers inflate reports,
orphan orders and payments corrupt revenue attribution, invalid emails waste
spend, and negative prices distort margins. Traditional tools **detect** issues
and stop there — a human still has to investigate, judge impact, write the fix,
and prove it worked. That doesn't scale, and it doesn't run continuously.

## 2. The Solution
GuardianAI is an **agentic, event-driven** system: a chain of specialized agents,
orchestrated by native Snowflake Tasks, that own the full data-quality lifecycle
autonomously — pausing only for human approval on risky fixes.

**The loop:** `Detect → Score → Rebuild Plan → Explain → Impact → Approve → Remediate → Validate → Govern`

## 3. Why "Agentic" (not just automation)
Each agent has a distinct role, reasons over the previous agent's output, and the
system decides its own next step — including **when to stop and ask a human**.
The Remediation Agent proposes; the Validation Agent independently re-checks its
own work; the pipeline even **rebuilds its own fix plan** when new issues appear
(self-healing). That self-verifying, self-updating loop is what makes it agentic
rather than a linear script.

## 4. Architecture
![GuardianAI Architecture](architecture.png)

- **Ingest:** Snowsight UI upload (or a landing stage with Snowpipe); **Streams**
  capture new rows (change-data-capture).
- **Data layer (5 tables):** CUSTOMERS, ORDERS, PRODUCTS, PAYMENTS, INVENTORY —
  with **cross-table** referential + business-logic checks.
- **Agent pipeline (Task DAG):** Observer → Score → **Rebuild Plan** → Diagnosis
  + Impact → Exec Summary, then the **human approval gate**, then Remediate →
  Validate → Govern.
- **Presentation:** Streamlit in Snowflake (5 pages).

## 5. The Agents

| # | Agent | Tech | Responsibility |
|---|-------|------|----------------|
| 1 | **Data Observer** | Deterministic SQL | 27 checks across 5 tables (incl. cross-table) → `DQ_ISSUES` |
| 2 | **Health Scorer** | SQL (volume-aware) | Severity × %-rows-affected → per-table + overall score |
| 3 | **Plan Builder** | SQL | Self-healing: rebuilds the fix plan for current issues |
| 4 | **Diagnosis** | Snowflake Cortex | Plain-English root cause per issue |
| 5 | **Business Impact** | Snowflake Cortex | Executive-language business impact |
| 6 | **Exec Summary** | Snowflake Cortex | One CDO-style headline paragraph |
| 7 | **Remediation** | SQL + Cortex | Fix SQL + confidence + risk + approval flag; AI narrates |
| 8 | **Validation** | Deterministic SQL | Re-detect + re-score, prove before→after |
| 9 | **Governance Recorder** | SQL | Immutable audit trail of every action + approval |

**Design principle:** *SQL detects and executes (auditable). AI only reasons,
explains, and narrates. A human approves anything risky.*

## 6. Volume-Aware Scoring (the intelligence upgrade)
Score isn't a flat penalty per issue type — it reflects **severity AND how
widespread** each issue is:

```
penalty_per_issue = PRESENCE(severity) + VOLUME_MULT(severity) × pct_rows_affected
table_health      = GREATEST(0, 100 − Σ penalties)
overall           = AVG(table scores)
```

| Severity | PRESENCE | VOLUME_MULT (per 1% rows) |
|----------|----------|----------------------------|
| CRITICAL | 8 | 1.5 |
| HIGH | 4 | 1.0 |
| MEDIUM | 2 | 0.7 |
| LOW | 1 | 0.3 |

This means a large, mostly-clean table is correctly rewarded, while a structural
breach (orphan/duplicate key) still hurts even at low volume — exactly how a real
CDO would reason.

## 7. Cross-Table Integrity (the differentiator)
Checks that are impossible looking at one table alone:
- **ORPHAN_PAYMENT** — a payment whose order doesn't exist
- **PAYMENT_AMOUNT_MISMATCH** — payment amount ≠ the matching order's amount
- **ORPHAN_INVENTORY** — stock for a product that doesn't exist
- **ORPHAN_ORDER** — an order whose customer doesn't exist

## 8. Event-Driven Orchestration (two loops)
**Loop A — Ingest → Detect (fully automatic):**
`File lands → Stream fires → Task DAG: Detect → Score → Rebuild Plan → Analyze → dashboard updates.`

**Loop B — Human action → Re-clean (human-gated):**
`User clicks Approve → Remediate (stream-safe) → Validate → Govern → dashboard updates.`

Loop B **never fires on its own** — only on explicit human approval. Responsible
AI is preserved *by design*.

## 9. Responsible AI
- **Human-in-the-loop approval** for every high-risk fix
- **Quarantine, never delete** — bad rows are preserved for review
- **Deterministic, auditable fix SQL** — no AI-generated code executes blindly
- **Stream-safe remediation** — dedup uses TRUNCATE+INSERT, never drops tables
- **Full governance log** — every agent action recorded with an actor

## 10. Dataset
Realistic retail data at scale (~1,000 customers, ~5,000 orders, ~500 products,
~4,500 payments, ~500 inventory) with a controlled, known set of injected issues
so results are reproducible.

## 11. Results (volume-aware, all 5 tables)

| Table | Before | After |
|-------|--------|-------|
| CUSTOMERS | 51 | 100 |
| INVENTORY | 55 | 100 |
| PAYMENTS | 64 | 100 |
| PRODUCTS | 68 | 100 |
| ORDERS | 72 | 100 |
| **OVERALL** | **62** | **~100** |

Bad rows are deduped or quarantined (never deleted); every table moves from HIGH
risk to LOW.

## 12. Setup & Run (first-time)

**Prereq:** Cortex enabled — verify with
`SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2','Say OK');`

```
-- Phase 1: schema + tables
01_create_schema
02_create_tables            -- all 5 data tables + support tables
-- → load the large CSVs via Snowsight UI  (or run 03_load_data)

-- Phase 2: detect + score
04_quality_checks           -- Observer: 27 checks → DQ_ISSUES
05_volume_aware_health_score -- overall ~62

-- Phase 3: AI intelligence
06_create_analysis_table
07_diagnosis_agent
08_business_impact_agent
09_executive_summary

-- Phase 4: remediation setup
10_create_remediation_table
11_remediation_agent        -- stream-safe fix plan (all 5 tables)
12_governance_recorder

-- Phase 5: orchestration
13_orchestration_setup       -- landing stage, streams
14_orchestration_procedures  -- SP_DETECT/SCORE/REBUILD_PLAN/etc.
15_orchestration_detection_dag -- Loop A + self-healing plan rebuild
16_orchestration_remediation_loop -- Loop B + executors (single source)
17_orchestration_controls    -- start/stop/monitor console

-- Phase 6: app
Deploy app/guardianai_app.py as a Streamlit-in-Snowflake app.
Click "Approve all & run remediation now" → OVERALL climbs to ~100.
```

Diagnostics (on-demand): `diagnostics/validation_agent.sql`, `diagnostics/testing.sql`.

## 13. Repository structure
```
guardianai-data-steward/
├── README.md
├── architecture.png
├── app/            guardianai_app.py  (Streamlit, 5 pages)
├── sql/            01 … 17  (clean run-order sequence)
├── diagnostics/    validation_agent.sql, testing.sql
├── data/           large CSVs
└── docs/           supporting notes
```

## 14. Cost & Safety Notes
- Orchestration tasks are gated on `SYSTEM$STREAM_HAS_DATA` (cheap no-op when
  idle) and can be **suspended** when not demoing to protect trial credits.
- Set warehouse `AUTO_SUSPEND` low; point the Streamlit app at `GUARDIANAI_WH`.

## 15. Future Roadmap
- Scheduled autonomous scans, Slack/Teams alerts on new criticals
- Learned severity weighting from historical approvals
- Data contracts + upstream prevention

---
*Built for CoCoQuest 2026 • Theme 1: Agentic Data Quality Guardian*
