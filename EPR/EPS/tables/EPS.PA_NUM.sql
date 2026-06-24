-- ============================================================
-- Azure SQL Schema Conversion for EPS.PA_NUM
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PA_NUM
-- Type: Master Transaction Table with 3 DEFERRABLE Foreign Keys
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Prior authorization master records (active prescriptions)

CREATE TABLE [EPS].[PA_NUM] (
    [CHAIN_ID] [int] NULL,
    [ID] [int] NULL,
    [DELETED] [char](1) NULL,
    [LAST_UPDATED] [datetime] NULL,
    [NHIN_ID] [int] NULL,
    [COUNTER] [int] NULL,
    [DOLLAR_RX] [numeric](13, 4) NULL,
    [DOLLARS] [numeric](13, 4) NULL,
    [EFFECTIVE] [datetime] NULL,
    [EXPIRATION] [datetime] NULL,
    [FILLS] [int] NULL,
    [NUMBER_RX] [int] NULL,
    [PA_NUMBER] [varchar](28) NULL,
    [PROCESSED] [datetime] NULL,
    [QUANTITY] [int] NULL,
    [REPEAT] [int] NULL,
    [TOTAL_QUANTITY] [int] NULL,
    [TX_NUMBER] [int] NULL,
    [PA_NUM_TYPE] [varchar](1) NULL,
    [ID_TX_TP] [int] NULL,
    [ID_AAL] [int] NULL,
    
    -- FOREIGN KEY CONSTRAINTS
    -- ⚠️ [DEFERRABLE_FK] All 3 constraints are DEFERRABLE INITIALLY DEFERRED in Oracle
    CONSTRAINT [PA_NUM_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [PA_NUM_FK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [PA_NUM_FK_TX_TP] FOREIGN KEY ([CHAIN_ID], [ID_TX_TP])
        REFERENCES [EPS].[TX_TP] ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- PA Number Lookup (insurance authorization lookup by approval code)
CREATE NONCLUSTERED INDEX [IX_PA_NUM_PANUMBER] 
ON [EPS].[PA_NUM] ([PA_NUMBER], [CHAIN_ID])
INCLUDE ([ID], [EFFECTIVE], [EXPIRATION], [DOLLAR_RX], [DOLLARS])
WHERE [PA_NUMBER] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-Store Composite
CREATE NONCLUSTERED INDEX [IX_PA_NUM_CHAIN_STORE] 
ON [EPS].[PA_NUM] ([CHAIN_ID], [NHIN_ID])
INCLUDE ([ID], [PA_NUMBER], [EFFECTIVE], [EXPIRATION])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Transaction Type Reference
CREATE NONCLUSTERED INDEX [IX_PA_NUM_TX_TP] 
ON [EPS].[PA_NUM] ([CHAIN_ID], [ID_TX_TP])
INCLUDE ([ID], [PA_NUMBER], [PROCESSED])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for transactional table
ALTER TABLE [EPS].[PA_NUM] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[DEFERRABLE_FK_WARNING] This table contains 3 DEFERRABLE INITIALLY DEFERRED foreign keys:
  
  1. PA_NUM_FK_ESCHAIN → SEC_ADMIN.EPS_SEC_CHAIN (CHAIN_NHIN_ID)
     Chain reference (customer identifier)
     
  2. PA_NUM_FK_ESSTORE → SEC_ADMIN.EPS_SEC_STORE (CHAIN_NHIN_ID, STORE_NHIN_ID)
     Composite FK enforcing PA created at valid chain + store location
     
  3. PA_NUM_FK_TX_TP → EPS.TX_TP (CHAIN_ID, ID)
     Composite FK linking PA to transaction type (fill/refund/adjustment/reversal)
  
  Azure SQL behavior: Constraints are IMMEDIATE (not deferrable)
  
  IMPACT: Application or ETL script creating PAs must:
    BEGIN TRANSACTION;
    -- 1. Ensure CHAIN exists in EPS_SEC_CHAIN
    -- 2. Ensure STORE exists in EPS_SEC_STORE
    -- 3. Ensure TX_TYPE exists in TX_TP
    INSERT INTO [EPS].[PA_NUM] (...) VALUES (...);
    COMMIT;
  
  RISK: Out-of-order inserts or bulk loads will fail with FK violation
  ACTION REQUIRED: SEE BATCH8-SCRIPT 1 for comprehensive validation

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (13 partitions) removed
  Replaced with nonclustered index on (CHAIN_ID, NHIN_ID)

[PA_NUMBER_LIFECYCLE]
  EFFECTIVE date: Insurance pre-approval issued
  PROCESSED date: Pharmacy submitted prescription under PA
  EXPIRATION date: Authorization expires (fills exhausted or date-limited)
  FILLS/REPEAT: Track authorization utilization
  
  Typical flow:
  1. Prescriber requests PA → PA_NUM created with EFFECTIVE date
  2. Insurance approves → PROCESSED date set
  3. Pharmacy fills Rx multiple times within REPEAT limit
  4. PA expires after FILLS exhausted or EXPIRATION date reached

[DOLLAR_RECONCILIATION] Two currency fields:
  [DOLLAR_RX]: Ingredient cost (from pharmacy provider)
  [DOLLARS]: Approved amount (what insurance authorizes)
  
  Validate: DOLLARS <= DOLLAR_RX (insurance doesn't overpay ingredient cost)
  
[SIZE_ESTIMATE] ~200-300 MB (active prior authorizations, high churn rate)

[COMPLIANCE] Insurance pre-approval documentation critical for:
  - Claims payment substantiation
  - Insurance denials appeals
  - Pharmacy compliance audits
  
  No sensitive card data (unlike PATIENT_CREDIT_CARD), standard PII protection applies
*/
