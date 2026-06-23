-- ============================================================
-- Azure SQL Schema Conversion for EPS.MRN_AUDIT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MRN_AUDIT
-- Type: Composite Partitioned Audit Table (Medical Record Numbers)
-- Oracle Partitions: LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP
-- Purpose: Tracks medical record number history, location references, HOME/BAD flags

CREATE TABLE [EPS].[MRN_AUDIT] (
    [CHAIN_ID] [int] NOT NULL,
    [LOCATION_CODE] [varchar](20) NOT NULL,
    [ID] [varchar](40) NOT NULL,
    [ID_PATIENT] [int] NULL,
    [ID_AAL] [int] NULL,
    [ROOT_ID] [int] NULL,
    [HOME] [char](1) NULL,
    [LAST_UPDATED] [datetime] NULL,
    [ID_AUDIT] [int] NULL,
    [BAD] [char](1) NULL,
    [AUDIT_TIMESTAMP] [datetime2](6) NOT NULL
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Purpose: Replicate Oracle composite LIST+RANGE partitioning effect

-- Timestamp-based Range Query (former subpartition key)
CREATE NONCLUSTERED INDEX [IX_MRN_AUDIT_TIMESTAMP] 
ON [EPS].[MRN_AUDIT] ([AUDIT_TIMESTAMP], [CHAIN_ID])
INCLUDE ([ID], [LOCATION_CODE], [ID_PATIENT], [HOME], [BAD])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-Location Composite (customer/facility-level queries)
CREATE NONCLUSTERED INDEX [IX_MRN_AUDIT_CHAIN_LOC] 
ON [EPS].[MRN_AUDIT] ([CHAIN_ID], [LOCATION_CODE], [AUDIT_TIMESTAMP])
INCLUDE ([ID], [ID_PATIENT], [HOME], [BAD])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Patient Lookup
CREATE NONCLUSTERED INDEX [IX_MRN_AUDIT_PATIENT] 
ON [EPS].[MRN_AUDIT] ([ID_PATIENT])
INCLUDE ([CHAIN_ID], [LOCATION_CODE], [ID], [HOME], [BAD])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- Audit tables support PAGE compression (high repetition of CHAIN_ID, LOCATION_CODE, AUDIT_TIMESTAMP)
ALTER TABLE [EPS].[MRN_AUDIT] 
SET (COMPRESSION = PAGE);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[COMPOSITE_PARTITIONING] Oracle structure: LIST by CHAIN_ID × RANGE by AUDIT_TIMESTAMP
  Subpartitions: GEAGLE202604-06, ECOM202604-06, HANNAF202604-06, MEIJER202604-06, etc.
  
  RECOMMENDATION: Post-migration monthly RANGE partitioning:
  
  CREATE PARTITION FUNCTION [PF_MRN_AUDIT_MONTHLY](datetime2) 
  AS RANGE RIGHT FOR VALUES (
      '2024-07-01', '2024-08-01', ... '2026-09-01'
  );
  
  Benefits: Faster quarterly/annual MRN history audits, optimized archive queries

[FLAGS_INTERPRETATION] 
  [HOME] flag: Indicates primary/default MRN at location
  [BAD] flag: Indicates flagged/problematic MRN (duplicate, invalid external reference)
  
  Consider filtered index for BAD='1' records if often queried for data quality checks:
  CREATE NONCLUSTERED INDEX [IX_MRN_AUDIT_BAD] 
  ON [EPS].[MRN_AUDIT] ([CHAIN_ID], [LOCATION_CODE], [BAD])
  WHERE [BAD] = '1';

[SIZE_ESTIMATE] ~400-600 MB (medical record number history, 13 chains × 3 months rolling)

[LOCATION_CODE_AUDIT] Verify LOCATION_CODE values (pharmacy location identifiers)
  Ensure all values match valid EPS_SEC_LOCATION table entries during migration

[DATA_QUALITY] BAD flag analysis before cutover:
  SELECT [BAD], COUNT(*) FROM [EPS].[MRN_AUDIT] GROUP BY [BAD]
  Investigate any unexpected BAD='1' records
*/
