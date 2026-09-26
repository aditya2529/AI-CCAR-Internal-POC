-- =============================================================================
-- StressLens CCAR POC - database schema (PostgreSQL 16)
-- Source: docs/CCAR_POC_PRD.md, section 6 (Data Model) and section 18 (Controls)
-- Synthetic data only. Not a regulatory data model.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS stg;   -- source files, as received (all text)
CREATE SCHEMA IF NOT EXISTS ref;   -- mappings, scenarios, parameters
CREATE SCHEMA IF NOT EXISTS cur;   -- curated, typed, standardized
CREATE SCHEMA IF NOT EXISTS calc;  -- calculation results
CREATE SCHEMA IF NOT EXISTS rpt;   -- regulatory-style reports
CREATE SCHEMA IF NOT EXISTS ctl;   -- controls: runs, DQ, recon, audit

-- -----------------------------------------------------------------------------
-- Control: runs and file loads (created first; other tables reference them)
-- -----------------------------------------------------------------------------
CREATE TABLE ctl.calc_run (
    run_id              VARCHAR(20)  PRIMARY KEY,           -- e.g. R20260630-003
    as_of_date          DATE         NOT NULL,
    status              VARCHAR(20)  NOT NULL,              -- STARTED, DQ_BLOCKED, CALCULATED, READY_FOR_REVIEW, FAILED_INGESTION
    scenario_versions   VARCHAR(100),                       -- e.g. BASE:1,MOD:1,SEV:1
    param_version       SMALLINT,
    started_by          VARCHAR(30)  NOT NULL,
    started_ts          TIMESTAMP    NOT NULL DEFAULT now(),
    ended_ts            TIMESTAMP
);

CREATE TABLE ctl.file_control (
    batch_id            VARCHAR(20)  NOT NULL,
    file_name           VARCHAR(100) NOT NULL,
    as_of_date          DATE         NOT NULL,
    row_count           INTEGER      NOT NULL,
    amount              NUMERIC(18,2),                      -- control amount where the file has one
    loaded_ts           TIMESTAMP    NOT NULL DEFAULT now(),
    PRIMARY KEY (batch_id, file_name)
);

-- -----------------------------------------------------------------------------
-- Staging: mirrors the source files column for column, as text
-- -----------------------------------------------------------------------------
CREATE TABLE stg.customer (
    customer_id TEXT, customer_name TEXT, naics_code TEXT, state_code TEXT,
    obligor_rating TEXT, customer_since TEXT,
    batch_id VARCHAR(20) NOT NULL, load_ts TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE stg.loan (
    loan_id TEXT, customer_id TEXT, product_code TEXT, orig_date TEXT, maturity_date TEXT,
    commitment_amt TEXT, interest_rate TEXT, rate_type TEXT, hvcre_flag TEXT,
    batch_id VARCHAR(20) NOT NULL, load_ts TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE stg.loan_balance (
    loan_id TEXT, as_of_date TEXT, outstanding_bal TEXT, days_past_due TEXT, gl_account TEXT,
    batch_id VARCHAR(20) NOT NULL, load_ts TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE stg.loan_status (
    status_hist_id TEXT, loan_id TEXT, status_code TEXT, effective_date TEXT, load_ts_src TEXT,
    batch_id VARCHAR(20) NOT NULL, load_ts TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE stg.collateral (
    collateral_id TEXT, loan_id TEXT, collateral_type TEXT, collateral_value TEXT, valuation_date TEXT,
    batch_id VARCHAR(20) NOT NULL, load_ts TIMESTAMP NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- Reference data
-- -----------------------------------------------------------------------------
CREATE TABLE ref.code_map (
    code_type           VARCHAR(12)  NOT NULL,              -- PRODUCT, STATUS, COLLATERAL, NAICS2
    source_code         VARCHAR(10)  NOT NULL,
    version             SMALLINT     NOT NULL DEFAULT 1,
    target_code         VARCHAR(20)  NOT NULL,
    status              VARCHAR(8)   NOT NULL DEFAULT 'ACTIVE', -- DRAFT, ACTIVE, RETIRED
    approved_by         VARCHAR(30),
    PRIMARY KEY (code_type, source_code, version)
);

CREATE TABLE ref.field_mapping (                            -- mapping spec M01-M16 as data
    mapping_id          VARCHAR(5)   PRIMARY KEY,
    source_table        VARCHAR(60)  NOT NULL,
    source_field        VARCHAR(100) NOT NULL,
    business_rule       VARCHAR(300),
    transformation      VARCHAR(300),
    target_table        VARCHAR(60)  NOT NULL,
    target_field        VARCHAR(100) NOT NULL
);

CREATE TABLE ref.stress_scenario (
    scenario_id         VARCHAR(5)   NOT NULL,              -- BASE, MOD, SEV
    version             SMALLINT     NOT NULL,
    scenario_name       VARCHAR(40)  NOT NULL,
    unemployment_peak   NUMERIC(5,2),
    gdp_peak_to_trough  NUMERIC(5,2),
    cre_price_change    NUMERIC(5,2) NOT NULL,              -- percent, e.g. -40.00
    bbb_spread_peak     NUMERIC(5,2),
    pd_multiplier_ci    NUMERIC(5,2) NOT NULL,
    pd_multiplier_cre   NUMERIC(5,2) NOT NULL,
    other_coll_haircut  NUMERIC(5,4) NOT NULL,
    ppnr_factor         NUMERIC(5,2) NOT NULL,
    status              VARCHAR(8)   NOT NULL,              -- DRAFT, ACTIVE, RETIRED
    approved_by         VARCHAR(30),
    PRIMARY KEY (scenario_id, version)
);

CREATE TABLE ref.risk_parameter (
    param_id            INTEGER      PRIMARY KEY,
    param_type          VARCHAR(20)  NOT NULL,              -- BASE_PD, LGD_FLOOR, UNSECURED_LGD, CCF, RISK_WEIGHT, RECOVERY_COST
    param_key           VARCHAR(20)  NOT NULL,
    param_value         NUMERIC(9,6) NOT NULL,
    effective_from      DATE         NOT NULL,
    version             SMALLINT     NOT NULL
);

-- -----------------------------------------------------------------------------
-- Curated
-- -----------------------------------------------------------------------------
CREATE TABLE cur.customer (
    customer_id         VARCHAR(10)  PRIMARY KEY,
    customer_name       VARCHAR(100) NOT NULL,
    naics_code          CHAR(6),
    industry_segment    VARCHAR(40)  NOT NULL DEFAULT 'UNKNOWN',
    state_code          CHAR(2),
    obligor_rating      SMALLINT     CHECK (obligor_rating BETWEEN 1 AND 10),
    customer_since      DATE
);

CREATE TABLE cur.loan_master (
    loan_id             VARCHAR(10)  PRIMARY KEY,
    customer_id         VARCHAR(10)  NOT NULL REFERENCES cur.customer (customer_id),
    src_product_code    VARCHAR(10)  NOT NULL,
    product_code        VARCHAR(20)  NOT NULL,
    portfolio           VARCHAR(5)   NOT NULL CHECK (portfolio IN ('CI', 'CRE')),
    origination_date    DATE         NOT NULL,
    maturity_date       DATE,
    commitment_amt      NUMERIC(18,2) NOT NULL CHECK (commitment_amt > 0),
    interest_rate       NUMERIC(7,5),
    rate_type           VARCHAR(5),
    hvcre_flag          CHAR(1)      NOT NULL DEFAULT 'N',
    source_system       VARCHAR(10)  NOT NULL DEFAULT 'LOANSYS'
);

CREATE TABLE cur.loan_balance (
    loan_id             VARCHAR(10)  NOT NULL REFERENCES cur.loan_master (loan_id),
    as_of_date          DATE         NOT NULL,
    outstanding_bal     NUMERIC(18,2) NOT NULL,
    undrawn_amt         NUMERIC(18,2) NOT NULL,
    days_past_due       INTEGER      NOT NULL DEFAULT 0,
    gl_account          VARCHAR(10)  NOT NULL,
    PRIMARY KEY (loan_id, as_of_date)
);

CREATE TABLE cur.loan_status_history (
    status_hist_id      BIGINT       PRIMARY KEY,
    loan_id             VARCHAR(10)  NOT NULL REFERENCES cur.loan_master (loan_id),
    src_status_code     VARCHAR(5)   NOT NULL,
    status_code         VARCHAR(12)  NOT NULL,              -- CURRENT, DPD30, DPD60, DPD90, NONACCRUAL, PAIDOFF, UNMAPPED
    effective_date      DATE         NOT NULL,
    load_ts             TIMESTAMP    NOT NULL
);

CREATE TABLE cur.collateral (
    collateral_id       VARCHAR(10)  PRIMARY KEY,
    loan_id             VARCHAR(10)  NOT NULL REFERENCES cur.loan_master (loan_id),
    src_collateral_type VARCHAR(10)  NOT NULL,
    collateral_type     VARCHAR(12)  NOT NULL,
    collateral_value    NUMERIC(18,2) NOT NULL CHECK (collateral_value > 0),
    valuation_date      DATE         NOT NULL
);

-- Current status = latest record on or before the as-of date; ties -> latest load (PRD 16.8)
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

-- -----------------------------------------------------------------------------
-- Calculation
-- -----------------------------------------------------------------------------
CREATE TABLE calc.calc_result (
    run_id              VARCHAR(20)  NOT NULL REFERENCES ctl.calc_run (run_id),
    loan_id             VARCHAR(10)  NOT NULL REFERENCES cur.loan_master (loan_id),
    scenario_id         VARCHAR(5)   NOT NULL,
    scenario_version    SMALLINT     NOT NULL,
    base_pd             NUMERIC(9,6) NOT NULL CHECK (base_pd BETWEEN 0 AND 1),
    stressed_pd         NUMERIC(9,6) NOT NULL CHECK (stressed_pd BETWEEN 0 AND 1),
    cum_pd_9q           NUMERIC(9,6) NOT NULL CHECK (cum_pd_9q BETWEEN 0 AND 1),
    ead                 NUMERIC(18,2) NOT NULL CHECK (ead >= 0),
    lgd                 NUMERIC(9,6) NOT NULL CHECK (lgd BETWEEN 0 AND 1),
    stress_loss         NUMERIC(18,2) NOT NULL,
    risk_weight         NUMERIC(5,2) NOT NULL,
    rwa                 NUMERIC(18,2) NOT NULL,
    PRIMARY KEY (run_id, loan_id, scenario_id),
    FOREIGN KEY (scenario_id, scenario_version) REFERENCES ref.stress_scenario (scenario_id, version),
    CHECK (stress_loss <= ead)
);

-- -----------------------------------------------------------------------------
-- Reporting
-- -----------------------------------------------------------------------------
CREATE TABLE rpt.reg_report (
    report_id           VARCHAR(30)  PRIMARY KEY,           -- e.g. RPT-Y14Q-CORP-20260630-v2
    run_id              VARCHAR(20)  NOT NULL REFERENCES ctl.calc_run (run_id),
    report_type         VARCHAR(25)  NOT NULL,              -- Y14Q_STYLE_CORP, Y14Q_STYLE_CRE, Y14A_STYLE_CAPITAL
    version             SMALLINT     NOT NULL,
    status              VARCHAR(10)  NOT NULL,              -- DRAFT, IN_REVIEW, APPROVED, REJECTED
    prepared_by         VARCHAR(30)  NOT NULL,
    reviewed_by         VARCHAR(30),
    approved_by         VARCHAR(30),
    created_ts          TIMESTAMP    NOT NULL DEFAULT now(),
    CHECK (reviewed_by IS NULL OR reviewed_by <> prepared_by)  -- maker <> checker
);

CREATE TABLE rpt.reg_report_line (
    report_id           VARCHAR(30)  NOT NULL REFERENCES rpt.reg_report (report_id),
    line_no             INTEGER      NOT NULL,
    loan_id             VARCHAR(10),                        -- null for summary lines
    field_code          VARCHAR(40)  NOT NULL,
    field_value         VARCHAR(100),
    lineage_ref         VARCHAR(100),                       -- e.g. cur.loan_balance.outstanding_bal
    PRIMARY KEY (report_id, line_no)
);

-- -----------------------------------------------------------------------------
-- Controls: DQ, reconciliation, GL, audit
-- -----------------------------------------------------------------------------
CREATE TABLE ctl.dq_rule (
    rule_id             VARCHAR(8)   PRIMARY KEY,           -- DQ-C01 ...
    dimension           VARCHAR(25)  NOT NULL,
    description         VARCHAR(200) NOT NULL,
    rule_sql            TEXT         NOT NULL,              -- must return: record_key, field_name, observed_value
    severity            VARCHAR(8)   NOT NULL CHECK (severity IN ('Critical', 'Warning')),
    owner               VARCHAR(30),
    status              VARCHAR(8)   NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE ctl.dq_exception (
    exception_id        BIGSERIAL    PRIMARY KEY,
    run_id              VARCHAR(20)  NOT NULL REFERENCES ctl.calc_run (run_id),
    rule_id             VARCHAR(8)   NOT NULL REFERENCES ctl.dq_rule (rule_id),
    record_key          VARCHAR(40)  NOT NULL,
    field_name          VARCHAR(60),
    observed_value      VARCHAR(100),
    severity            VARCHAR(8)   NOT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'OPEN', -- OPEN, FIX_PROPOSED, OVERRIDE_PROPOSED, OVERRIDDEN, ACCEPTED, RESOLVED
    owner               VARCHAR(30),
    comment             VARCHAR(500),
    created_ts          TIMESTAMP    NOT NULL DEFAULT now(),
    updated_ts          TIMESTAMP
);

CREATE TABLE ctl.recon_result (
    recon_id            BIGSERIAL    PRIMARY KEY,
    run_id              VARCHAR(20)  NOT NULL REFERENCES ctl.calc_run (run_id),
    check_code          VARCHAR(8)   NOT NULL,              -- RC-01 ... RC-08, RR01 ... RR05
    left_value          NUMERIC(18,2),
    right_value         NUMERIC(18,2),
    difference          NUMERIC(18,2),
    tolerance           NUMERIC(18,2),
    outcome             VARCHAR(10)  NOT NULL,              -- PASS, BREAK, EXPLAINED
    comment             VARCHAR(500),
    created_ts          TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE ctl.gl_control (
    gl_account          VARCHAR(10)  NOT NULL,
    as_of_date          DATE         NOT NULL,
    gl_balance          NUMERIC(18,2) NOT NULL,
    PRIMARY KEY (gl_account, as_of_date)
);

CREATE TABLE ctl.audit_log (
    audit_id            BIGSERIAL    PRIMARY KEY,
    event_ts            TIMESTAMP    NOT NULL DEFAULT now(),
    user_id             VARCHAR(30)  NOT NULL,
    run_id              VARCHAR(20),
    event_type          VARCHAR(20)  NOT NULL,
    object_type         VARCHAR(30),
    object_key          VARCHAR(40),
    field_name          VARCHAR(60),
    old_value           VARCHAR(200),
    new_value           VARCHAR(200),
    reason              VARCHAR(500),
    related_user        VARCHAR(30)
);

-- Audit log is append-only (control CTL-12)
CREATE OR REPLACE FUNCTION ctl.fn_audit_log_block_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'ctl.audit_log is append-only: % is not allowed', TG_OP;
END;
$$;

CREATE TRIGGER trg_audit_log_append_only
BEFORE UPDATE OR DELETE ON ctl.audit_log
FOR EACH ROW EXECUTE FUNCTION ctl.fn_audit_log_block_change();
