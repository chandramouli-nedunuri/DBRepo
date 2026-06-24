-- ============================================================
-- Azure SQL Schema Conversion for EPS.PATIENT_EXTRACT
-- Source: Oracle EPS database
-- Target: Azure SQL Server 2019+
-- Conversion Date: 2026-05-28
-- ============================================================

-- TABLE: EPS.PATIENT_EXTRACT
-- Type: INDEX-ORGANIZED TABLE (IOT) - SPECIAL HANDLING
-- Oracle Partitions: None (IOT - primary key defines structure)
-- Purpose: Change data capture for patient data exports (extract tracking)

-- ⚠️ SPECIAL CONVERSION: Oracle IOT → Azure SQL Heap
-- Oracle IOT (Index-Organized Table): Data physically ordered by primary key
-- Azure SQL: No IOT equivalent - convert to heap with clustered index on PK

CREATE TABLE [EPS].[PATIENT_EXTRACT] (
    [CHAIN_ID] [int] NOT NULL,
    [ID] [int] NOT NULL,
    [LAST_CHANGE_TIME] [datetime2](6) NOT NULL,
    
    CONSTRAINT [PATIENT_EXTRACT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID], [LAST_CHANGE_TIME])
) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [PRIMARY];

-- ============================================================
-- POST-DEPLOYMENT ACTIONS
-- ============================================================
/*
[IOT_CONVERSION_EXPLANATION] - BATCH9-SCRIPT 1:
  Oracle IOT (Index-Organized Table):
    - Data physically stored in primary key order
    - No separate heap (data blocks ordered by PK)
    - Efficient range queries (PK-ordered retrieval)
    - Used for: Change data capture, audit logs, time-series data
  
  Azure SQL IOT Equivalent:
    Azure SQL does NOT support IOT (data structure not available)
    Conversion strategy: Use clustered index on PK (simulates ordering)
    
    CREATE TABLE [PATIENT_EXTRACT] (
      [CHAIN_ID] INT NOT NULL,
      [ID] INT NOT NULL,
      [LAST_CHANGE_TIME] DATETIME2(6) NOT NULL,
      CONSTRAINT [PK_PATIENT_EXTRACT] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID], [LAST_CHANGE_TIME])
    )
    
    Result: Data physically clustered by PK (achieves similar effect as IOT)
    Trade-off: Non-clustered indexes required for non-PK queries (no "secondary index" concept)

[CHANGE_DATA_CAPTURE_PURPOSE]
  PATIENT_EXTRACT tracks which patient records changed recently:
  - [CHAIN_ID]: Customer/chain identifier
  - [ID]: Patient record internal ID
  - [LAST_CHANGE_TIME]: When patient record last modified
  
  Used for:
    1. Nightly data export: Find all patients modified since last export
    2. Replication synchronization: Push changes to external systems
    3. Data warehouse ETL: Identify incremental dataset
    4. Compliance reporting: Track data modifications for audit
    
  Workflow:
    1. Application updates PATIENT record (INSERT/UPDATE/DELETE)
    2. Trigger or application code inserts into PATIENT_EXTRACT
    3. Nightly job queries: SELECT * FROM PATIENT_EXTRACT WHERE LAST_CHANGE_TIME >= @lastExportTime
    4. Exports changed records to DW or external system
    5. Cleanup: TRUNCATE PATIENT_EXTRACT (reset for next cycle)

[MINIMAL_COLUMNS]
  Design: Minimal column set (3 columns only)
    - Optimized for change tracking (not patient details)
    - PK covers all commonly-queried fields
    - No redundant data (details available in PATIENT master table)

[LAST_CHANGE_TIME_TRACKING]
  Precision: DATETIME2(6) microsecond granularity
  Purpose: Order changes chronologically (ensure re-play order in external systems)
  
  Range query pattern:
    SELECT * FROM [EPS].[PATIENT_EXTRACT]
    WHERE [LAST_CHANGE_TIME] >= @sinceTimestamp
    ORDER BY [LAST_CHANGE_TIME];
    
  Result: All changed patients in chronological order (supports replay)

[COMPOSITE_PRIMARY_KEY]
  Three-column key: (CHAIN_ID, ID, LAST_CHANGE_TIME)
  Implication: Same patient (CHAIN_ID + ID) can appear multiple times (different timestamps)
  
  Example:
    (Chain=1, PatientID=500, Time=2026-05-01 10:30:00.000000)
    (Chain=1, PatientID=500, Time=2026-05-02 14:15:00.000000)  ← Patient changed again next day
  
  Both rows preserved: Full change history captured

[SIZE_ESTIMATE] ~10-50 MB (lightweight change log, periodic cleanup)

[CLEANUP_STRATEGY] - Post-migration
  PATIENT_EXTRACT likely truncated nightly:
  
  Workflow:
    1. Morning: TRUNCATE TABLE [EPS].[PATIENT_EXTRACT]
    2. Daily: Application inserts changed records during operating hours
    3. Evening: ETL job exports changes
    4. Repeat next day
  
  Retention: 1-7 days (rolling window, not permanent archive)

[ALTERNATIVE_CDC_APPROACH]
  Modern alternative: Azure SQL Change Data Capture (CDC):
    - Native SQL Server feature (tracks all DML changes)
    - Automatic change log (no application code needed)
    - Time-based or LSN-based queries (more flexible)
    - Built-in cleanup (retention policy automated)
  
  Migration opportunity:
    Consider replacing manual PATIENT_EXTRACT with CDC:
    - Eliminate manual trigger maintenance
    - Reduce data duplication
    - Simplify ETL logic
    - Improve data consistency

[DATA_QUALITY_VALIDATION]
  ✓ Unique rows: No duplicate (CHAIN_ID, ID, LAST_CHANGE_TIME) combinations
  ✓ LAST_CHANGE_TIME > TODAY() - 7 days (within retention window)
  ✓ CHAIN_ID references valid chain
  ✓ ID references valid PATIENT record
  ✓ Chronological ordering (no gaps or retroactive timestamps)

[PERFORMANCE_CONSIDERATIONS]
  Clustered index on (CHAIN_ID, ID, LAST_CHANGE_TIME):
    ✓ Efficient range queries by time (nightly export)
    ✓ Efficient by-chain queries (chain-specific extracts)
    ✓ No key lookup required (fully covering index)
  
  For non-PK queries: Add nonclustered indexes as needed
  Example: IF querying by LAST_CHANGE_TIME only:
    CREATE NONCLUSTERED INDEX [IX_PATIENT_EXTRACT_TIME]
    ON [EPS].[PATIENT_EXTRACT] ([LAST_CHANGE_TIME], [CHAIN_ID], [ID]);

[IOT_TO_CLUSTERED_MAPPING] - Azure SQL Strategy:
  Oracle IOT advantage: Physical ordering by PK (single I/O path)
  Azure SQL equivalent: Clustered index on PK (achieves similar result)
  
  Performance expectation: Similar (both achieve ordered storage)
  Query performance: Range scans on PK should match or exceed Oracle

[TRUNCATION_LOGGING]
  If manual TRUNCATE used nightly:
    Recommend: Add job logging
      INSERT INTO [Audit].[TableTruncations] VALUES ('PATIENT_EXTRACT', GETDATE());
      TRUNCATE TABLE [EPS].[PATIENT_EXTRACT];
    
    Benefits: Audit trail of cleanup operations
    Compliance: Demonstrate data hygiene (not delaying cleanup)
*/
