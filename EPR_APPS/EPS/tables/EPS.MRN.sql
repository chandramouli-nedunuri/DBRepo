-- ============================================================
-- Azure SQL Schema Conversion for EPS.MRN
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-25
-- ============================================================

-- TABLE: EPS.MRN
-- Type: Master Transaction Table (Medical Record Numbers)
-- Oracle Partitions: LIST by CHAIN_ID (13 partitions)
-- Purpose: Current medical record number assignments, location-based, non-nullable key

CREATE TABLE [EPS].[MRN] (
    [CHAIN_ID] [int] NOT NULL,
    [LOCATION_CODE] [varchar](20) NOT NULL,
    [ID] [varchar](40) NOT NULL,
    [ID_PATIENT] [int] NULL,
    [ID_AAL] [int] NULL,
    [ROOT_ID] [int] NULL,
    [HOME] [char](1) NULL,
    [LAST_UPDATED] [datetime] NULL,
    [BAD] [char](1) NULL,
    
    CONSTRAINT [MRN_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [LOCATION_CODE], [ID])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- INDEXES
-- ============================================================
-- Patient ID Lookup (medical record number to patient resolution)
CREATE NONCLUSTERED INDEX [IX_MRN_PATIENT] 
ON [EPS].[MRN] ([ID_PATIENT])
INCLUDE ([CHAIN_ID], [LOCATION_CODE], [ID], [HOME], [BAD])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Root ID Hierarchy (navigate to canonical MRN)
CREATE NONCLUSTERED INDEX [IX_MRN_ROOT_ID] 
ON [EPS].[MRN] ([ROOT_ID], [CHAIN_ID])
INCLUDE ([LOCATION_CODE], [ID], [ID_PATIENT], [HOME])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- Chain-Location traversal (location-based MRN discovery)
CREATE NONCLUSTERED INDEX [IX_MRN_CHAIN_LOC] 
ON [EPS].[MRN] ([CHAIN_ID], [LOCATION_CODE])
INCLUDE ([ID], [ID_PATIENT], [HOME], [BAD])
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- COMPRESSION
-- ============================================================
-- Master table uses ROW compression (CHAIN_ID, LOCATION_CODE repetition)
ALTER TABLE [EPS].[MRN] 
SET (COMPRESSION = ROW);

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[PRIMARY_KEY] Composite key: (CHAIN_ID, LOCATION_CODE, ID)
  Ensures one MRN per location per chain (prevents duplicates)
  
  High cardinality expected for [ID] (medical record number format varies by vendor):
  - Internal numeric sequences
  - External system identifiers (HL7, NCPDP standards)
  - UPC/EAN formats
  
  Verify data distribution across 13 chains during migration:
  SELECT [CHAIN_ID], COUNT(*) as [RecordCount] 
  FROM [EPS].[MRN] GROUP BY [CHAIN_ID] ORDER BY [RecordCount] DESC;

[HOME_FLAG_OPTIMIZATION] If frequently filtering HOME='1':
  CREATE NONCLUSTERED INDEX [IX_MRN_HOME]
  ON [EPS].[MRN] ([CHAIN_ID], [LOCATION_CODE], [HOME])
  WHERE [HOME] = '1';
  
  This replaces Oracle partition-level filtering for "primary MRN" queries

[BAD_FLAG] Same as MRN_AUDIT - investigate records with BAD='1'

[SIZE_ESTIMATE] ~100-150 MB (current MRN assignments, much smaller than audit table)

[UNIQUE_CONSTRAINT] Consider adding unique index on [ID] + [LOCATION_CODE] if:
  Medical record numbers should be globally unique per location (not chain-specific)
  Verify business requirement with data steward

[PARTITIONING_REMOVED] Oracle LIST partitioning by CHAIN_ID removed
  Nonclustered index on CHAIN_ID_LOCATION_CODE compensates
  
  Post-migration, consider identity-based partitioning if >1GB and hotspot chain exists

[AUDIT_TABLE_SYNC] Pair with EPS.MRN_AUDIT for audit trail
  Ensure CDC or trigger-based auditing captures all MRN changes
*/
