-- =============================================================================
-- StressLens CCAR POC - SQL examples for BAs and data engineers (PostgreSQL)
-- Source: docs/CCAR_POC_PRD.md, section 16. Run after 01 and 02 and a data load.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 16.1 JOIN — loan view with customer and balance
-- -----------------------------------------------------------------------------
SELECT l.loan_id, c.customer_name, c.obligor_rating, l.product_code,
       l.commitment_amt, b.outstanding_bal
FROM   cur.loan_master  l
JOIN   cur.customer     c ON c.customer_id = l.customer_id
LEFT JOIN cur.loan_balance b ON b.loan_id = l.loan_id
                            AND b.as_of_date = DATE '2026-06-30';

-- -----------------------------------------------------------------------------
-- 16.2 WHERE — large CRE exposures
-- -----------------------------------------------------------------------------
SELECT l.loan_id, l.product_code, b.outstanding_bal
FROM   cur.loan_master l
JOIN   cur.loan_balance b USING (loan_id)
WHERE  l.portfolio = 'CRE'
  AND  b.as_of_date = DATE '2026-06-30'
  AND  b.outstanding_bal > 10000000
ORDER BY b.outstanding_bal DESC;

-- -----------------------------------------------------------------------------
-- 16.3 GROUP BY and aggregations — portfolio summary
-- -----------------------------------------------------------------------------
SELECT l.portfolio, l.product_code,
       COUNT(*)                 AS loan_count,
       SUM(l.commitment_amt)    AS total_commitment,
       SUM(b.outstanding_bal)   AS total_outstanding,
       ROUND(AVG(l.interest_rate), 4) AS avg_rate
FROM   cur.loan_master l
JOIN   cur.loan_balance b USING (loan_id)
WHERE  b.as_of_date = DATE '2026-06-30'
GROUP BY ROLLUP (l.portfolio, l.product_code)
ORDER BY 1, 2;

-- -----------------------------------------------------------------------------
-- 16.4 CASE WHEN — portfolio and risk weight
-- -----------------------------------------------------------------------------
SELECT l.loan_id,
       CASE WHEN l.product_code LIKE 'CRE%' THEN 'CRE' ELSE 'CI' END AS portfolio,
       CASE WHEN l.hvcre_flag = 'Y'                           THEN 1.50
            WHEN s.status_code IN ('DPD90', 'NONACCRUAL')    THEN 1.50
            ELSE 1.00 END                                     AS risk_weight
FROM   cur.loan_master l
JOIN   cur.v_loan_current_status s USING (loan_id);

-- -----------------------------------------------------------------------------
-- 16.5 Duplicate detection (finds D04)
-- -----------------------------------------------------------------------------
SELECT loan_id, as_of_date, COUNT(*) AS row_count
FROM   stg.loan_balance
GROUP BY loan_id, as_of_date
HAVING COUNT(*) > 1;

-- -----------------------------------------------------------------------------
-- 16.6 NULL checks (finds D01, D02, D03)
-- -----------------------------------------------------------------------------
SELECT 'loan_master.interest_rate' AS field, loan_id AS record_key
FROM   cur.loan_master WHERE interest_rate IS NULL
UNION ALL
SELECT 'customer.obligor_rating', customer_id
FROM   cur.customer WHERE obligor_rating IS NULL
UNION ALL
SELECT 'customer.naics_code', customer_id
FROM   cur.customer WHERE naics_code IS NULL OR TRIM(naics_code) = '';

-- -----------------------------------------------------------------------------
-- 16.7 Missing records (finds D05, D06, D07)
-- -----------------------------------------------------------------------------
-- D05: loan with no balance for the as-of date
SELECT l.loan_id
FROM   cur.loan_master l
LEFT JOIN stg.loan_balance b ON b.loan_id = l.loan_id AND b.as_of_date = '2026-06-30'
WHERE  b.loan_id IS NULL;

-- D06: balance with no loan (orphan)
SELECT b.loan_id, b.outstanding_bal
FROM   stg.loan_balance b
WHERE  NOT EXISTS (SELECT 1 FROM stg.loan l WHERE l.loan_id = b.loan_id);

-- D07: loan pointing to a missing customer
SELECT l.loan_id, l.customer_id
FROM   stg.loan l
LEFT JOIN stg.customer c ON c.customer_id = l.customer_id
WHERE  c.customer_id IS NULL;

-- -----------------------------------------------------------------------------
-- 16.8 Latest status selection (handles D11)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW cur.v_loan_current_status AS
SELECT loan_id, status_code, effective_date
FROM (
  SELECT h.loan_id, h.status_code, h.effective_date,
         ROW_NUMBER() OVER (PARTITION BY h.loan_id
                            ORDER BY h.effective_date DESC, h.load_ts DESC) AS rn
  FROM   cur.loan_status_history h
  WHERE  h.effective_date <= DATE '2026-06-30'
) x
WHERE rn = 1;

-- Tie check: two records on the same effective date (warning DQ-U02)
SELECT loan_id, effective_date, COUNT(*)
FROM   cur.loan_status_history
GROUP BY loan_id, effective_date
HAVING COUNT(*) > 1;

-- -----------------------------------------------------------------------------
-- 16.9 Invalid code and incorrect mapping (finds D08, D09)
-- -----------------------------------------------------------------------------
-- D08: status codes with no mapping
SELECT s.loan_id, s.status_code
FROM   stg.loan_status s
LEFT JOIN ref.code_map m ON m.code_type = 'STATUS' AND m.source_code = s.status_code
WHERE  m.source_code IS NULL;

-- D09: C&I product secured by CRE collateral (cross-field check)
SELECT l.loan_id, l.product_code, c.collateral_type
FROM   cur.loan_master l
JOIN   cur.collateral c USING (loan_id)
WHERE  l.portfolio = 'CI' AND c.collateral_type LIKE 'CRE%';

-- -----------------------------------------------------------------------------
-- 16.10 Incorrect balance (finds D10)
-- -----------------------------------------------------------------------------
SELECT l.loan_id, l.commitment_amt, b.outstanding_bal,
       CASE WHEN b.outstanding_bal < 0               THEN 'NEGATIVE_BALANCE'
            WHEN b.outstanding_bal > l.commitment_amt THEN 'OVER_COMMITMENT' END AS issue
FROM   cur.loan_master l
JOIN   cur.loan_balance b USING (loan_id)
WHERE  b.outstanding_bal < 0 OR b.outstanding_bal > l.commitment_amt;

-- -----------------------------------------------------------------------------
-- 16.11 Source-to-target reconciliation
-- -----------------------------------------------------------------------------
SELECT 'SOURCE FILE' AS layer, row_count, amount FROM ctl.file_control
 WHERE file_name = 'loansys_balance.csv' AND as_of_date = '2026-06-30'
UNION ALL
SELECT 'STAGING', COUNT(*), SUM(outstanding_bal::numeric) FROM stg.loan_balance
UNION ALL
SELECT 'CURATED', COUNT(*), SUM(outstanding_bal) FROM cur.loan_balance
 WHERE as_of_date = '2026-06-30'
UNION ALL
SELECT 'REPORT R1', COUNT(*), SUM(utilized_exposure) FROM rpt.v_r1_extract
 WHERE reporting_date = '2026-06-30';
-- Expected: 41 / $279.7M, 41 / $279.7M, 40 / $286.6M, 40 / $286.6M

-- -----------------------------------------------------------------------------
-- 16.12 Curated vs GL by account
-- -----------------------------------------------------------------------------
SELECT g.gl_account, g.gl_balance,
       COALESCE(SUM(b.outstanding_bal), 0)                 AS curated_balance,
       g.gl_balance - COALESCE(SUM(b.outstanding_bal), 0)  AS difference
FROM   ctl.gl_control g
LEFT JOIN cur.loan_balance b ON b.gl_account = g.gl_account
                            AND b.as_of_date = g.as_of_date
WHERE  g.as_of_date = '2026-06-30'
GROUP BY g.gl_account, g.gl_balance;
-- Expected: 141000 difference 2,400,000 (LN1041 orphan); 142000 difference 0

-- -----------------------------------------------------------------------------
-- 16.13 Calculation validation — independent recompute
-- -----------------------------------------------------------------------------
SELECT r.loan_id, r.scenario_id, r.stress_loss,
       ROUND(r.cum_pd_9q * r.lgd * r.ead, 2)             AS recomputed,
       r.stress_loss - ROUND(r.cum_pd_9q * r.lgd * r.ead, 2) AS diff
FROM   calc.calc_result r
WHERE  r.run_id = 'R20260630-003'
  AND  ABS(r.stress_loss - ROUND(r.cum_pd_9q * r.lgd * r.ead, 2)) > 1;
-- Expected: no rows

-- -----------------------------------------------------------------------------
-- 16.14 Scenario comparison pivot
-- -----------------------------------------------------------------------------
SELECT l.product_code,
       SUM(r.stress_loss) FILTER (WHERE r.scenario_id = 'BASE') AS loss_base,
       SUM(r.stress_loss) FILTER (WHERE r.scenario_id = 'MOD')  AS loss_mod,
       SUM(r.stress_loss) FILTER (WHERE r.scenario_id = 'SEV')  AS loss_sev
FROM   calc.calc_result r
JOIN   cur.loan_master l USING (loan_id)
WHERE  r.run_id = 'R20260630-003'
GROUP BY ROLLUP (l.product_code);
