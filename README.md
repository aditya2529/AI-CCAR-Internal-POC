# StressLens: CCAR Stress Testing Practice Project (Iris internal)

An internal Iris Software learning project. About 40 people build a small, simplified version of the annual US bank stress test (CCAR) for a fictional bank, using made-up data.

```
Load data → Map & clean → Data quality → Calculate losses (3 scenarios) → Capital impact
→ Reconcile → FR Y-14-style reports → Review & approval → Audit trail
```

> **Not a regulatory solution.** All data is synthetic and the bank (Iris Demo Bancorp) is fictional.
> Formulas and scenarios are simplifications. The reports are *styled on* FR Y-14Q / FR Y-14A; they are not submissions.

## Start here

1. Read **[docs/CCAR_POC_PRD.docx](docs/CCAR_POC_PRD.docx)** (11 pages).
2. Open **[docs/CCAR_POC_Reference_Workbook.xlsx](docs/CCAR_POC_Reference_Workbook.xlsx)**. The Index tab lists everything: requirements, user stories, data dictionary, mappings, quality rules, test scenarios, sample data and the answer key.
3. Find your squad folder under `squads/` and read its README.

## Repository layout

| Path | Contents |
| --- | --- |
| `docs/CCAR_POC_PRD.docx` | Short PRD: what, why, process, numbers, team, plan, demo, risks |
| `docs/CCAR_POC_Reference_Workbook.xlsx` | Lookup tables and data (30 tabs, with index) |
| `docs/reference/` | The complete original 73-page PRD (only if you need every detail) |
| `data/landing/2026-06-30/` | Raw source files with **12 planted errors** |
| `data/fixes/2026-06-30/` | Corrected and supplementary records that resolve the errors |
| `data/curated/2026-06-30/` | Clean files: start point for squads B, C, D and the answer key for squad A |
| `data/expected/` | Answer key: 120 loan × scenario results plus portfolio and capital totals |
| `scripts/generate_sample_data.py` | Regenerates all data and the answer key |
| `sql/` | PostgreSQL tables, reference data with the 15 quality rules, SQL examples |
| `squads/` | One working folder per squad |

## Team setup

About 40 people in **4 squads of ~10**, each owning one layer, plus one shared BA:

| Squad | Owns |
| --- | --- |
| A. Data Foundation | Load, map, transform, one-command run |
| B. Quality & Reconciliation | Quality rules, override workflow, reconciliation, audit log |
| C. Risk & Capital | Scenarios, loss calculations, capital, dashboard |
| D. Reporting & Governance | Reports, approval workflow, lineage |

- Questions go through your squad lead to the BA's daily Q&A. Answers are posted once in the shared question log.
- Work on a branch named `squad-X/US-xx-short-name` (for example `squad-C/US-08-loss-calc`) and open a pull request into `main`.
- `docs/`, `data/`, `sql/` and `scripts/` are shared and changed only by the BA.
- Synthetic data only. Never commit client or production data.

## Quick start

```bash
python scripts/generate_sample_data.py          # regenerate data and answer key (Python 3.11+, no packages needed)
psql -d stresslens -f sql/01_create_schema.sql  # PostgreSQL 16
psql -d stresslens -f sql/02_reference_data.sql
```

## Expected results (clean data, 30 June 2026)

| | Baseline | Moderate | Severe |
| --- | --- | --- | --- |
| Total stress loss (9 quarters) | $6.52M | $11.86M | $24.18M |
| Ending CET1 ratio (start 11.99%) | 12.12% | 10.97% | 8.53% |
