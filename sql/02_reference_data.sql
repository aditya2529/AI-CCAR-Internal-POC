-- =============================================================================
-- StressLens CCAR POC - reference data: scenarios, risk parameters, DQ rules
-- Source: PRD sections 9.1, 10 and 17.2. Hypothetical values, not Federal Reserve scenarios.
-- Code mappings are loaded from data/landing/2026-06-30/ref_code_map.csv
-- (it contains seeded defect D09; the fix is in data/fixes/2026-06-30/fix_code_map.csv).
-- =============================================================================

-- Scenarios (PRD section 10)
INSERT INTO ref.stress_scenario
    (scenario_id, version, scenario_name, unemployment_peak, gdp_peak_to_trough, cre_price_change,
     bbb_spread_peak, pd_multiplier_ci, pd_multiplier_cre, other_coll_haircut, ppnr_factor, status, approved_by)
VALUES
    ('BASE', 1, 'Baseline',        4.30,  1.80,   0.00, 1.50, 1.00, 1.00, 0.0000, 1.00, 'ACTIVE', 'risk.lead'),
    ('MOD',  1, 'Moderate Stress', 7.00, -1.50, -20.00, 3.00, 1.80, 2.00, 0.1500, 0.85, 'ACTIVE', 'risk.lead'),
    ('SEV',  1, 'Severe Stress',  10.00, -4.00, -40.00, 5.00, 3.00, 3.50, 0.3000, 0.60, 'ACTIVE', 'risk.lead');

-- Risk parameters, version 1 (PRD section 9.1)
INSERT INTO ref.risk_parameter (param_id, param_type, param_key, param_value, effective_from, version) VALUES
    ( 1, 'BASE_PD',       '1',        0.000500, DATE '2026-01-01', 1),
    ( 2, 'BASE_PD',       '2',        0.001000, DATE '2026-01-01', 1),
    ( 3, 'BASE_PD',       '3',        0.003000, DATE '2026-01-01', 1),
    ( 4, 'BASE_PD',       '4',        0.008000, DATE '2026-01-01', 1),
    ( 5, 'BASE_PD',       '5',        0.020000, DATE '2026-01-01', 1),
    ( 6, 'BASE_PD',       '6',        0.040000, DATE '2026-01-01', 1),
    ( 7, 'BASE_PD',       '7',        0.080000, DATE '2026-01-01', 1),
    ( 8, 'BASE_PD',       '8',        0.150000, DATE '2026-01-01', 1),
    ( 9, 'BASE_PD',       '9',        0.300000, DATE '2026-01-01', 1),
    (10, 'BASE_PD',       '10',       1.000000, DATE '2026-01-01', 1),
    (11, 'DELINQ_PD_FLOOR','DPD30_60', 0.150000, DATE '2026-01-01', 1),
    (12, 'HORIZON_FACTOR','9Q',       2.250000, DATE '2026-01-01', 1),
    (13, 'CCF',           'ALL',      0.500000, DATE '2026-01-01', 1),
    (14, 'UNSECURED_LGD', 'ALL',      0.450000, DATE '2026-01-01', 1),
    (15, 'LGD_FLOOR',     'SECURED',  0.100000, DATE '2026-01-01', 1),
    (16, 'RECOVERY_COST', 'ALL',      0.100000, DATE '2026-01-01', 1),
    (17, 'RISK_WEIGHT',   'STANDARD', 1.000000, DATE '2026-01-01', 1),
    (18, 'RISK_WEIGHT',   'HVCRE_PASTDUE', 1.500000, DATE '2026-01-01', 1),
    (19, 'TAX_RATE',      'FEDERAL',  0.210000, DATE '2026-01-01', 1);

-- DQ rule library (PRD section 17.2). Each rule_sql returns record_key, field_name, observed_value.
INSERT INTO ctl.dq_rule (rule_id, dimension, description, rule_sql, severity, owner) VALUES
('DQ-C01', 'Completeness', 'Loan interest rate is populated',
 $q$SELECT loan_id, 'interest_rate', NULL FROM stg.loan WHERE NULLIF(TRIM(interest_rate), '') IS NULL$q$,
 'Critical', 'BA'),
('DQ-C02', 'Completeness', 'Obligor rating is populated',
 $q$SELECT customer_id, 'obligor_rating', NULL FROM stg.customer WHERE NULLIF(TRIM(obligor_rating), '') IS NULL$q$,
 'Critical', 'BA'),
('DQ-C03', 'Completeness', 'NAICS code is populated',
 $q$SELECT customer_id, 'naics_code', NULL FROM stg.customer WHERE NULLIF(TRIM(naics_code), '') IS NULL$q$,
 'Warning', 'BA'),
('DQ-C04', 'Completeness', 'Every loan has a balance row for the as-of date',
 $q$SELECT l.loan_id, 'loan_balance', 'missing' FROM stg.loan l
    WHERE NOT EXISTS (SELECT 1 FROM stg.loan_balance b WHERE b.loan_id = l.loan_id AND b.as_of_date = '2026-06-30')$q$,
 'Critical', 'Data Engineer'),
('DQ-V01', 'Validity', 'Obligor rating between 1 and 10',
 $q$SELECT customer_id, 'obligor_rating', obligor_rating FROM stg.customer
    WHERE NULLIF(TRIM(obligor_rating), '') IS NOT NULL AND obligor_rating::int NOT BETWEEN 1 AND 10$q$,
 'Critical', 'BA'),
('DQ-V02', 'Validity', 'Status code exists in code map',
 $q$SELECT s.loan_id, 'status_code', s.status_code FROM stg.loan_status s
    WHERE NOT EXISTS (SELECT 1 FROM ref.code_map m WHERE m.code_type = 'STATUS' AND m.source_code = s.status_code AND m.status = 'ACTIVE')$q$,
 'Critical', 'BA'),
('DQ-V03', 'Validity', 'Product code exists in code map',
 $q$SELECT l.loan_id, 'product_code', l.product_code FROM stg.loan l
    WHERE NOT EXISTS (SELECT 1 FROM ref.code_map m WHERE m.code_type = 'PRODUCT' AND m.source_code = l.product_code AND m.status = 'ACTIVE')$q$,
 'Critical', 'BA'),
('DQ-U01', 'Uniqueness', 'One balance row per loan and as-of date',
 $q$SELECT loan_id, 'loan_balance', COUNT(*)::text FROM stg.loan_balance GROUP BY loan_id, as_of_date HAVING COUNT(*) > 1$q$,
 'Critical', 'Data Engineer'),
('DQ-U02', 'Uniqueness', 'One status row per loan and effective date',
 $q$SELECT loan_id, 'effective_date', effective_date FROM stg.loan_status GROUP BY loan_id, effective_date HAVING COUNT(*) > 1$q$,
 'Warning', 'Data Engineer'),
('DQ-A01', 'Accuracy', 'Outstanding balance is not negative',
 $q$SELECT loan_id, 'outstanding_bal', outstanding_bal FROM stg.loan_balance WHERE outstanding_bal::numeric < 0$q$,
 'Critical', 'BA'),
('DQ-A02', 'Accuracy', 'Outstanding balance does not exceed commitment',
 $q$SELECT b.loan_id, 'outstanding_bal', b.outstanding_bal FROM stg.loan_balance b
    JOIN stg.loan l ON l.loan_id = b.loan_id
    WHERE b.outstanding_bal::numeric > l.commitment_amt::numeric$q$,
 'Critical', 'BA'),
('DQ-A03', 'Accuracy', 'C&I product must not have CRE collateral',
 $q$SELECT DISTINCT l.loan_id, 'product_code', l.product_code FROM cur.loan_master l
    JOIN cur.collateral c ON c.loan_id = l.loan_id
    WHERE l.portfolio = 'CI' AND c.collateral_type LIKE 'CRE%'$q$,
 'Critical', 'BA'),
('DQ-R01', 'Referential integrity', 'Balance loan exists in loan master',
 $q$SELECT b.loan_id, 'loan_id', b.outstanding_bal FROM stg.loan_balance b
    WHERE NOT EXISTS (SELECT 1 FROM stg.loan l WHERE l.loan_id = b.loan_id)$q$,
 'Critical', 'Data Engineer'),
('DQ-R02', 'Referential integrity', 'Loan customer exists in customer file',
 $q$SELECT l.loan_id, 'customer_id', l.customer_id FROM stg.loan l
    WHERE NOT EXISTS (SELECT 1 FROM stg.customer c WHERE c.customer_id = l.customer_id)$q$,
 'Critical', 'Data Engineer'),
('DQ-T01', 'Timeliness', 'Collateral appraisal no older than 24 months',
 $q$SELECT collateral_id, 'valuation_date', valuation_date FROM stg.collateral
    WHERE valuation_date::date < DATE '2026-06-30' - INTERVAL '24 months'$q$,
 'Warning', 'BA');
