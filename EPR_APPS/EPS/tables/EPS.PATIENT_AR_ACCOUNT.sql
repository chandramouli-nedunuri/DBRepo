-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_AR_ACCOUNT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_AR_ACCOUNT
-- Type: Master Transaction Table (Accounts Receivable)
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Active patient AR accounts (current billing relationships)

CREATE TABLE [EPS].[PATIENT_AR_ACCOUNT] (
    [CHAIN_ID] [int] NULL,
    [ID] [int] NULL,
    [ID_AAL] [int] NOT NULL,
    [LAST_UPDATED] [datetime] NULL,
    [NHIN_ID] [int] NULL,
    [ACCOUNT_TYPE] [numeric](2, 0) NOT NULL,
    [ACCOUNT_NUMBER] [varchar](33) NOT NULL,
    [MASTER_ACCOUNT_NUMBER] [varchar](33) NULL,
    [ACCOUNT_OPEN_DATE] [datetime2](6) NOT NULL,
    [ACCOUNT_CLOSE_DATE] [datetime2](6) NULL,
    [ID_PATIENT] [int] NOT NULL,
    [ORIGINATING_NHIN_STORE_ID] [int] NOT NULL,
    [ORIGINAL_PATIENT_CODE] [varchar](8) NOT NULL,
    [DELETED] [varchar](1) NULL,
    [NOTE] [varchar](2000) NULL,
    
    CONSTRAINT [PATIENT_AR_ACCOUNT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient Account Lookup (billing/collections)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_PATIENT] 
ON [EPS].[PATIENT_AR_ACCOUNT] ([ID_PATIENT], [CHAIN_ID])
INCLUDE ([ID], [ACCOUNT_NUMBER], [ACCOUNT_TYPE], [ACCOUNT_OPEN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Account Number Reference (collections inquiry)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_ACCTNUM] 
ON [EPS].[PATIENT_AR_ACCOUNT] ([ACCOUNT_NUMBER], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [ACCOUNT_TYPE], [ACCOUNT_OPEN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Master Account Hierarchy (consolidated billing)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_MASTER] 
ON [EPS].[PATIENT_AR_ACCOUNT] ([MASTER_ACCOUNT_NUMBER], [CHAIN_ID])
INCLUDE ([ID], [ACCOUNT_NUMBER], [ID_PATIENT])
WHERE [MASTER_ACCOUNT_NUMBER] IS NOT NULL
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- ROW compression for AR transaction table
ALTER TABLE [EPS].[PATIENT_AR_ACCOUNT] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, ID)
  Ensures one unique AR account per chain per ID

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID (13 partitions) removed
  Replaced with clustered PK on (CHAIN_ID, ID)

[AR_ACCOUNT_LIFECYCLE]
  1. Patient applies for credit or purchases on payment plan
  2. AR account created, ACCOUNT_OPEN_DATE recorded
  3. All Rx purchases charged to account (deferred payment)
  4. Monthly statements sent, payments collected
  5. Account may close if:
     - Patient pays in full (ACCOUNT_CLOSE_DATE set)
     - Debt written off (DELETED flag, collections abandoned)
     - Account merged/consolidated to MASTER_ACCOUNT
  6. Can reopen if customer purchases again

[ACTIVE_AR_CALCULATION]
  SELECT 
    [CHAIN_ID],
    [ACCOUNT_NUMBER],
    COUNT(DISTINCT [ID_PATIENT]) as [PatientCount],
    COUNT(DISTINCT CASE WHEN [ACCOUNT_CLOSE_DATE] IS NULL THEN [ID] END) as [OpenAccounts],
    COUNT(DISTINCT CASE WHEN [DELETED] = 'Y' THEN [ID] END) as [WrittenOff]
  FROM [EPS].[PATIENT_AR_ACCOUNT]
  GROUP BY [CHAIN_ID], [ACCOUNT_NUMBER];

[ORIGINATING_STORE_TRACKING] ORIGINATING_NHIN_STORE_ID:
  Records which pharmacy location opened the credit account
  May differ from patient's primary pharmacy (consolidation benefits)
  
  Track store-level AR origination volume:
  SELECT [ORIGINATING_NHIN_STORE_ID], COUNT(*) as [AccountsOpened]
  FROM [EPS].[PATIENT_AR_ACCOUNT]
  GROUP BY [ORIGINATING_NHIN_STORE_ID]
  ORDER BY COUNT(*) DESC;

[ACCOUNT_HIERARCHY] MASTER_ACCOUNT_NUMBER enables:
  Household consolidated billing - one master account for family (parent guarantor)
  
  Example structure:
  Account 001 (MASTER) parent
  ├─ Account 101 (child 1) - MASTER_ACCOUNT_NUMBER = '001'
  ├─ Account 102 (child 2) - MASTER_ACCOUNT_NUMBER = '001'
  └─ Account 103 (child 3) - MASTER_ACCOUNT_NUMBER = '001'
  
  Billing consolidation: One invoice for all children, paid to master account
  
  Query family accounts:
  SELECT [ACCOUNT_NUMBER], [ID_PATIENT], [ACCOUNT_TYPE]
  FROM [EPS].[PATIENT_AR_ACCOUNT]
  WHERE [MASTER_ACCOUNT_NUMBER] = '001';

[ACCOUNT_TYPE_SOFT_DELETE] Soft-delete (DELETED flag) for AR accounts:
  Indicates:
  - Account written off (uncollectible debt)
  - Fraud case (closed for security)
  - Duplicate account (consolidated to another)
  
  Preserved in audit table for compliance

[SIZE_ESTIMATE] ~150-250 MB (active accounts, much smaller than audit table)

[DAILY_OPERATIONS]
  Collections/billing staff queries:
  - Find all open accounts for patient (SELECT ... WHERE ID_PATIENT = @pid AND ACCOUNT_CLOSE_DATE IS NULL)
  - Household consolidated billing (SELECT ... WHERE MASTER_ACCOUNT_NUMBER = '001')
  - Account aging (DATEDIFF(DAY, ACCOUNT_OPEN_DATE, GETDATE()))
  - AR aging report (30/60/90+ day buckets by ACCOUNT_OPEN_DATE)

[ORPHANED_RECORD_VALIDATION]
  SELECT COUNT(*) as [OrphanAccounts]
  FROM [EPS].[PATIENT_AR_ACCOUNT] P
  LEFT JOIN [EPS].[PATIENT] PATIENT ON P.[ID_PATIENT] = PATIENT.[ID]
  WHERE PATIENT.[ID] IS NULL;  -- Should return 0

[SYNC_WITH_AUDIT] Verify master/audit table consistency:
  SELECT COUNT(DISTINCT [ID])
  FROM [EPS].[PATIENT_AR_ACCOUNT_AUDIT]
  MINUS
  SELECT COUNT(DISTINCT [ID])
  FROM [EPS].[PATIENT_AR_ACCOUNT];
  
  Audit should have >=  master row counts (adds historical changes)
*/
