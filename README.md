# StressLens: CCAR Wholesale Credit Stress Testing POC (Iris internal)

An internal Iris Software learning project. A Scrum team builds a simplified, end-to-end CCAR data and reporting lifecycle for a fictional bank:

```
Source data → Mapping & transformation → Data quality → Risk calculations (PD, LGD, EAD, stress loss, RWA)
→ PPNR & CET1 capital impact → Aggregation → Reconciliation → FR Y-14-style reports → Review & approval → Audit trail
```

> **Not a regulatory solution.** All data is synthetic, and the bank (Iris Demo Bancorp) is fictional.
> The formulas and the scenarios (Baseline, Moderate, Severe) are POC simplifications.
> The reports are *styled on* FR Y-14Q / FR Y-14A. They are not FR Y-14 submissions.
> The PRD labels every item as **[CCAR]** (a real concept), **[POC]** (a simplification) or **[ASSUMPTION]**.

## Repository layout

| Path | Contents |
| --- | --- |
| `docs/CCAR_POC_PRD.md` | Full PRD: concept, process, data model, mappings, calculations, scenarios, reporting, BRs, user stories, sprint plan, SQL, DQ and recon, controls, demo plan |
| `data/landing/2026-06-30/` | Raw source files (LOANSYS, COLLSYS, GL control, code map), with **12 seeded data-quality defects** |
| `data/fixes/2026-06-30/` | Corrected and supplementary records that resolve the defects (PRD §7.1) |
| `data/expected/` | QA oracle: 120 loan × scenario results plus a portfolio and capital summary |
| `scripts/generate_sample_data.py` | Regenerates all data and expected results (reference implementation of PRD §9) |
| `sql/01_create_schema.sql` | PostgreSQL schemas and tables: `stg`, `ref`, `cur`, `calc`, `rpt`, `ctl` |
| `sql/02_reference_data.sql` | Scenarios, risk parameters and the 15-rule DQ library |
| `sql/03_dq_recon_examples.sql` | SQL examples: joins, DQ checks, latest status, reconciliation, calculation validation |

## Quick start

```bash
# 1. Regenerate data and the expected results (Python 3.11+, standard library only)
python scripts/generate_sample_data.py

# 2. Create the database objects (PostgreSQL 16)
psql -d stresslens -f sql/01_create_schema.sql
psql -d stresslens -f sql/02_reference_data.sql
```

## Expected results (clean dataset, as of 2026-06-30)

| Measure | Baseline | Moderate | Severe |
| --- | --- | --- | --- |
| Total stress loss (9Q) | $6.52M | $11.86M | $24.18M |
| Ending CET1 ratio (start 11.99%) | 12.12% | 10.97% | 8.53% |

Reconciliation: the raw balance file ($279.7M, 41 rows) bridges to the curated book ($286.6M, 40 loans), which bridges to the GL ($289.0M, with an explained $2.4M break for LN1041).

## Team setup and workflow

About 40 people work in **5 squads of ~8** (squad lead, 3 developers, 2 data engineers, 2 QA). Each squad builds the full pipeline in parallel over 4 two-week sprints. **One BA** supports all squads (PRD §14.1).

- Each squad works only in its own folder: `squads/squad-1/` … `squads/squad-5/`.
- Name branches `squad-N/US-xx-short-name` (for example `squad-2/US-05-dq-rules`) and open a pull request into `main`.
- `docs/`, `data/`, `sql/` and `scripts/` are shared and changed only by the BA.
- Questions go through your squad lead to the BA's daily Q&A. Answers are posted once in the shared question log.
- Keep this repo synthetic-data only. Never commit client or production data.

## Stack

PostgreSQL 16 · Python 3.11 (pandas) · Streamlit · pytest · Git / Jira
