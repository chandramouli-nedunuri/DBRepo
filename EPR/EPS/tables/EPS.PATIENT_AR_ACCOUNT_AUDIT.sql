-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_AR_ACCOUNT_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_AR_ACCOUNT_AUDIT
-- Type: Composite Partitioned Audit Table (Accounts Receivable)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Audit trail for patient AR (accounts receivable) accounts

CREATE TABLE [EPS].[PATIENT_AR_ACCOUNT_AUDIT] (
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
    [ID_AUDIT] [int] NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL,
    [NOTE] [varchar](2000) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Audit Timestamp Range (monthly AR aging analysis)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_AUDIT_TIMESTAMP] 
ON [EPS].[PATIENT_AR_ACCOUNT_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [ACCOUNT_NUMBER], [ACCOUNT_TYPE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Account History (patient's AR account evolution)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_AUDIT_PATIENT] 
ON [EPS].[PATIENT_AR_ACCOUNT_AUDIT] ([ID_PATIENT], [CHAIN_ID], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [ACCOUNT_NUMBER], [ACCOUNT_TYPE], [ACCOUNT_OPEN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Account Number Lookup (collections/billing inquiry)
CREATE NONCLUSTERED INDEX [IX_PATIENT_AR_ACCOUNT_AUDIT_ACCTNUM] 
ON [EPS].[PATIENT_AR_ACCOUNT_AUDIT] ([ACCOUNT_NUMBER], [CHAIN_ID])
INCLUDE ([ID], [ID_PATIENT], [ACCOUNT_TYPE], [ACCOUNT_OPEN_DATE])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- PAGE compression for audit table
ALTER TABLE [EPS].[PATIENT_AR_ACCOUNT_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
  
  RECOMMENDATION: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_PATIENT_AR_ACCOUNT_AUDIT_MONTHLY](datetime2)
  AS RANGE RIGHT FOR VALUES ('2024-07-01', '2024-08-01', ... '2026-09-01');
  
  Enables: Fast quarterly AR aging analysis, compliance reporting

[ACCOUNTS_RECEIVABLE_DOMAIN] Critical for pharmacy billing operations:
  Tracks patient or guarantor debt accounts (pharmacy customer financing)
  
  Key fields:
  - ACCOUNT_TYPE: Patient AR vs. Guarantor vs. Insurance (0=Patient, 1=Guarantor, 2=Insurance)
  - ACCOUNT_NUMBER: AR ledger account identifier (bill-to-account)
  - MASTER_ACCOUNT_NUMBER: Parent account (consolidated billing for household)
  - ACCOUNT_OPEN_DATE: Credit account established date
  - ACCOUNT_CLOSE_DATE: Account settled/closed date
  - ID_PATIENT: Link to patient master
  - ORIGINATING_NHIN_STORE_ID: Store that opened account
  - ORIGINAL_PATIENT_CODE: Legacy identifier (data migration reference)

[AR_WORKFLOW] Typical patient billing sequence:
  1. Patient approved for credit → AR account created
  2. Rx fills charged to AR account (ACCOUNT_OPEN_DATE set)
  3. Monthly statements generated, payments collected
  4. Account may be closed (ACCOUNT_CLOSE_DATE), reopened if needed
  5. Audit trail tracks all changes (DELETED flag for soft-deletes)

[ACCOUNT_TYPE_CODES] (hypothesis based on domain knowledge):
  0 = Patient account (patient liable, patient agrees to terms)
  1 = Guarantor/Responsible party (co-signer, usually household member)
  2 = Insurance account (insurance plan AR, claims-based billing)
  
  Validate with business rules:
  SELECT [ACCOUNT_TYPE], COUNT(*) as [AccountCount]
  FROM [EPS].[PATIENT_AR_ACCOUNT_AUDIT]
  GROUP BY [ACCOUNT_TYPE];

[MASTER_ACCOUNT_CONSOLIDATION] MASTER_ACCOUNT_NUMBER enables:
  - Household consolidated billing (one invoice for family)
  - Account hierarchy (parent/child relationships)
  - Eliminate duplicate billing across family accounts
  
  Example: 3 children (separate AR accounts) roll up to MASTER_ACCOUNT (parent guarantor)

[AR_AGING_ANALYSIS] Time-based queries on ACCOUNT_OPEN_DATE:
  SELECT 
    CASE 
      WHEN DATEDIFF(DAY, [ACCOUNT_OPEN_DATE], GETDATE()) <= 30 THEN '0-30 days'
      WHEN DATEDIFF(DAY, [ACCOUNT_OPEN_DATE], GETDATE()) <= 60 THEN '31-60 days'
      WHEN DATEDIFF(DAY, [ACCOUNT_OPEN_DATE], GETDATE()) <= 90 THEN '61-90 days'
      ELSE '90+ days' 
    END as [AgingBucket],
    COUNT(*) as [AccountCount],
    SUM([ACCOUNT_BALANCE]) as [TotalAR]
  FROM [EPS].[PATIENT_AR_ACCOUNT_AUDIT]
  WHERE [ACCOUNT_CLOSE_DATE] IS NULL
  GROUP BY CASE WHEN ... END;

[SIZE_ESTIMATE] ~600-900 MB (AR volume, 13 chains × 3 months rolling)

[DELETED_FLAG_ANALYSIS]
  [DELETED] = 'Y' indicates soft-deleted accounts (write-off, fraud, etc.)
  
  Audit trail preserved in AUDIT table:
  SELECT COUNT(*) as [DeletedAccounts]
  FROM [EPS].[PATIENT_AR_ACCOUNT_AUDIT]
  WHERE [DELETED] = 'Y';
  
  Investigate deleted accounts for write-off/collections metrics

[COMPLIANCE] AR audit essential for:
  - SOX compliance (revenue recognition, AR aging)
  - Fair Debt Collection Practice Act (FDCPA) audit trail
  - State healthcare billing regulations
  - Insurance claim substantiation

[ORPHANED_PATIENT_VALIDATION] Check for missing patient references:
  SELECT COUNT(*) as [OrphanAccounts]
  FROM [EPS].[PATIENT_AR_ACCOUNT_AUDIT] AR
  LEFT JOIN [EPS].[PATIENT] P ON AR.[ID_PATIENT] = P.[ID]
  WHERE P.[ID] IS NULL;
*/
