-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_08072015
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_08072015
-- Type: Reference/Archive Table (Data Snapshot)
-- Purpose: Patient data snapshot from 2015-08-07 (historical reference, non-partitioned)
-- Note: Likely backup/archive table or data quality snapshot for specific analysis date

CREATE TABLE [EPS].[PATIENT_08072015] (
    [ID] [int] NULL,
    [CHAIN_ID] [int] NULL,
    [RX_COM_ID] [int] NULL,
    [ALT_PATIENT_ID] [varchar](26) NULL,
    [ALT_PATIENT_ID_STATE] [varchar](6) NULL,
    [ALT_PATIENT_ID_TYPE] [numeric](5, 0) NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[TABLE_PURPOSE] Historical snapshot or archive table:
  - Not partitioned (single segment)
  - Minimal column set (core identifiers only)
  - Date in name suggests point-in-time snapshot (2015-08-07)
  
  Possible uses:
  a) Data quality baseline (compare current PATIENT table)
  b) Compliance snapshot (audit trail point)
  c) Historical archive for regulatory requirement
  d) Data migration audit (pre/post comparison)
  e) Patient merge/deduplication analysis

[COLUMN_INTERPRETATION]
  [ID]: Patient identifier (internal EPS ID)
  [CHAIN_ID]: Customer/chain reference
  [RX_COM_ID]: External system patient ID (RX_Com integration)
  [ALT_PATIENT_ID]: Alternate patient identifier (insurance member ID, SSN, etc.)
  [ALT_PATIENT_ID_STATE]: State code (if ALT_PATIENT_ID is state-specific)
  [ALT_PATIENT_ID_TYPE]: Code indicating type of ALT_PATIENT_ID (1=SSN, 2=Insurance, 3=DL, etc.)

[USAGE_QUERY] Find patients with ALT_ID assigned:
  SELECT COUNT(DISTINCT [ID]) as [PatientsWithAltID],
         [ALT_PATIENT_ID_TYPE], 
         COUNT([ALT_PATIENT_ID_TYPE]) as [TypeCount]
  FROM [EPS].[PATIENT_08072015]
  WHERE [ALT_PATIENT_ID] IS NOT NULL
  GROUP BY [ALT_PATIENT_ID_TYPE];

[NO_CONSTRAINTS] No primary keys, indexes, or foreign keys
  Indicates snapshot/archive table (no operational overhead)
  Data integrity assumptions different from production tables

[SIZE_ESTIMATE] Variable (depends on snapshot volume)
  Likely <100 MB (patient count from mid-2015, before significant growth)

[RETENTION_DECISION] Determine if table should be:
  a) Archived to cold storage (rarely accessed, compliance requirement)
  b) Deleted (if no regulatory requirement, data stale)
  c) Kept for reference (baseline comparisons)
  
  Recommend: Move to archive database if retained for compliance

[NULLABLE_COLUMNS] All columns nullable suggests:
  - Incomplete patient records at snapshot time
  - Some patients may not have alternate identifiers assigned
  - Data quality varies (investigate NULL patterns)

[NO_PERFORMANCE_TUNING] Archive tables typically receive no:
  - Indexes (no operational queries)
  - Compression (size not critical)
  - Partitioning (fixed snapshot)
  
  Migration strategy: Direct copy to target, minimal optimization

[DATA_INTEGRITY_CHECK] Validate snapshot completeness:
  SELECT COUNT(DISTINCT [CHAIN_ID]) as [ChainCount],
         COUNT(DISTINCT [ID]) as [PatientCount],
         COUNT(DISTINCT [RX_COM_ID]) as [RxComCount]
  FROM [EPS].[PATIENT_08072015];
  
  Compare against known patient counts from 2015-08-07 ledger
*/
