-- ============================================================
-- Azure SQL Schema Conversion for EPS.PA_NUM_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.PA_NUM_AUDIT
-- Type: Composite Partitioned Audit Table (Prior Authorization Numbers)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for prescription prior authorization (PA) numbers

CREATE TABLE [EPS].[PA_NUM_AUDIT] (
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
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range Query
CREATE NONCLUSTERED INDEX [IX_PA_NUM_AUDIT_TIMESTAMP] 
ON [EPS].[PA_NUM_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [PA_NUMBER], [ID_AUDIT])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- PA Number Reference (lookup by prior auth number)
CREATE NONCLUSTERED INDEX [IX_PA_NUM_AUDIT_PANUMBER] 
ON [EPS].[PA_NUM_AUDIT] ([PA_NUMBER], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [EFFECTIVE], [EXPIRATION], [ID_TX_TP])
WHERE [PA_NUMBER] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Transaction Reference (RX/TX lookup)
CREATE NONCLUSTERED INDEX [IX_PA_NUM_AUDIT_TXTYPE] 
ON [EPS].[PA_NUM_AUDIT] ([ID_TX_TP], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [PA_NUMBER], [TX_NUMBER], [EFFECTIVE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-Date Composite (chain-level PA analysis)
CREATE NONCLUSTERED INDEX [IX_PA_NUM_AUDIT_CHAIN] 
ON [EPS].[PA_NUM_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [PA_NUMBER], [PROCESSED], [FILLED])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table 
ALTER TABLE [EPS].[PA_NUM_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID (13 chains) + RANGE by AUDIT_TIMESTAMP (3-month rolling)
  
  RECOMMENDATION: Post-migration monthly RANGE partitioning by AUDIT_TIMESTAMP:
  
  CREATE PARTITION FUNCTION [PF_PA_NUM_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');
  
  Enables: Fast quarterly PA compliance reports, archive old authorization records

[PRIOR_AUTHORIZATION_WORKFLOW] PA processing represents insurance pre-approval:
  1. Prescriber submits request (EFFECTIVE = request timestamp)
  2. Insurance reviews (PROCESSED = approval date)
  3. Authorization valid until EXPIRATION
  4. Patient fills prescription (multiple fills allowed if REPEAT > 0)
  
  FILLS tracking:
  - FILLS: Number of fills authorized under this PA
  - REPEAT: Number of additional fills allowed
  - TOTAL_QUANTITY: Aggregate quantity across all fills
  
  Reconciliation logic:
  SELECT [ID], [FILLS], [REPEAT], [TOTAL_QUANTITY]
  FROM [EPS].[PA_NUM_AUDIT]
  WHERE [REPEAT] > 0 AND [FILLS] >= [REPEAT];  -- Potential over-fills

[PA_NUMBER_FORMAT] VARCHAR(28) - Prior auth identifier:
  Formats vary by insurance:
  - Numeric: 13-digit reference numbers
  - Alphanumeric: Carrier codes + transaction reference
  - Some carriers: Multiple PA numbers per claim (co-pay/benefit tier auth)
  
  Sample validation:
  SELECT DISTINCT LENGTH([PA_NUMBER]), [PA_NUMBER]
  FROM [EPS].[PA_NUM_AUDIT]
  WHERE [PA_NUMBER] IS NOT NULL
  ORDER BY LENGTH([PA_NUMBER]), [PA_NUMBER];

[DOLLAR_AMOUNTS] Two currency fields:
  - [DOLLAR_RX]: Rx cost (ingredient cost from provider)
  - [DOLLARS]: Approved amount (what insurance will pay)
  
  Validation: Ensure [DOLLARS] <= [DOLLAR_RX] (insurance pays less/equal):
  SELECT COUNT(*) as [OverpaymentRecords]
  FROM [EPS].[PA_NUM_AUDIT]
  WHERE [DOLLARS] > [DOLLAR_RX] AND [DOLLARS] IS NOT NULL;

[PA_NUM_TYPE] Single-character classification (VARCHAR(1)):
  Expected values (hypothesis):
  - 'R' = Routine/standard PA
  - 'U' = Urgent PA
  - 'E' = Emergency PA
  - 'D' = Denials override
  
  Validate values:
  SELECT DISTINCT [PA_NUM_TYPE], COUNT(*)
  FROM [EPS].[PA_NUM_AUDIT]
  GROUP BY [PA_NUM_TYPE]
  ORDER BY [PA_NUM_TYPE];

[ID_TX_TP] Transaction type reference:
  Foreign key relationship (likely):
  - Links to transaction type master table
  - Indicates if PA is for fill, refund, adjustment, etc.
  
  Consider adding reference constraint if table exists:
  ALTER TABLE [EPS].[PA_NUM_AUDIT]
  ADD CONSTRAINT [FK_PA_NUM_TX_TYPE] FOREIGN KEY ([ID_TX_TP])
      REFERENCES [EPS].[TRANSACTION_TYPE] ([ID]);

[NULLABILITY] Many columns marked nullable despite domain significance:
  [CHAIN_ID], [ID] nullable in audit (unusual, normally identifies record)
  Likely audit table captures pre-delete states (DELETED flag present)
  
  Analyze NULL distribution:
  SELECT 
    SUM(CASE WHEN [CHAIN_ID] IS NULL THEN 1 ELSE 0 END) as [NullChain],
    SUM(CASE WHEN [ID] IS NULL THEN 1 ELSE 0 END) as [NullID],
    SUM(CASE WHEN [PA_NUMBER] IS NULL THEN 1 ELSE 0 END) as [NullPA]
  FROM [EPS].[PA_NUM_AUDIT];

[DELETED_FLAG] Soft-delete indicator (CHAR(1)):
  Values: '1' = deleted, NULL/other = active
  
  Typical PA audit delete reason:
  - PA auto-expired
  - Invalid PA (transmit error, denied by insurance)
  - Reversed authorization
  
  Count deletions by chain:
  SELECT [CHAIN_ID], COUNT(*) as [DeletedPAs]
  FROM [EPS].[PA_NUM_AUDIT]
  WHERE [DELETED] = '1'
  GROUP BY [CHAIN_ID];

[COUNTER_FIELD] Integer counter (unclear purpose):
  Could represent:
  - Retry counter (how many times PA was submitted)
  - Response counter (how many insurance responses received)
  - Sequence number for multi-part authorization
  
  Check distribution:
  SELECT [COUNTER], COUNT(*)
  FROM [EPS].[PA_NUM_AUDIT]
  WHERE [COUNTER] IS NOT NULL
  GROUP BY [COUNTER];

[SIZE_ESTIMATE] ~450-650 MB (13 chains × 3 months rolling, prior auths track multi-year history)

[INSURANCE_COMPLIANCE] PA audit critical for:
  - Insurance claim substantiation (proof of authorization)
  - Appeals/denials documentation
  - Pharmacy compliance audits (State Board of Pharmacy)
  - DEA controlled substance pre-authorizations
  
  Retention: 5-7 years minimum (match insurance appeal windows)

[EXPECTED_QUERIES]
  1. Active PAs expiring soon:
     SELECT [PA_NUMBER], [ID], [EXPIRATION]
     FROM [EPS].[PA_NUM_AUDIT]
     WHERE [EXPIRATION] BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE())
     ORDER BY [EXPIRATION];
  
  2. Over-utilized authorizations:
     SELECT [PA_NUMBER], [FILLS], [REPEAT], 
            ([FILLS] - [REPEAT]) as [OverageCount]
     FROM [EPS].[PA_NUM_AUDIT]
     WHERE [FILLS] > [REPEAT];
  
  3. Insurance PA request timeline:
     DATEDIFF(DAY, [EFFECTIVE], [PROCESSED]) as [ApprovalDays]
     FROM [EPS].[PA_NUM_AUDIT]
     WHERE [EFFECTIVE] IS NOT NULL AND [PROCESSED] IS NOT NULL;
*/
