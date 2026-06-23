-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_MESSAGE_CONTENT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_MESSAGE_CONTENT
-- Target: Azure SQL Table [EPS].[AUDIT_MESSAGE_CONTENT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_MESSAGE_CONTENT
- Columns: 6 (message content storage for audit trail)
- Size: 43,875 lines (VERY LARGE TABLE with LOB storage)
- Data Types: BLOB field for message_content
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP, daily)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID, AUDIT_TIMESTAMP), 1 FK (ESCHAIN)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), AUDIT_D (audit partitions)
- Special Features: LOB (Large Object) storage management

CONVERSION STRATEGY:
- All 6 columns converted with precision mapping
- Composite partitioning (LIST + RANGE by day) REMOVED → Non-partitioned table
- PK preserved on (CHAIN_ID, ID, AUDIT_TIMESTAMP)
- BLOB → VARBINARY(MAX) for Azure SQL compatibility
- LOB storage parameters and BASICFILE/SECUREFILE removed (Azure-managed)
- Storage parameters removed (Azure-managed)

CRITICAL CONVERSION: BLOB → VARBINARY(MAX)
- Oracle: LOB storage with BASICFILE, CHUNK 8192, RETENTION settings
- Azure SQL: VARBINARY(MAX) with automatic LOB management
- Impact: Performance characteristics may differ; use FileStream/FileTable for extreme sizes
- Action: Monitor actual message sizes in production before full migration

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, ID_AAL)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle BLOB → Azure VARBINARY(MAX)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by day) removed
- 3-part PK maintained: (CHAIN_ID, ID, AUDIT_TIMESTAMP)
- LOB storage with Oracle-specific settings removed
- BLOB field converted to VARBINARY(MAX) with automatic management
- Daily date-range partitioning removed (implement retention policy instead)

PERFORMANCE CONCERNS:
- VERY LARGE TABLE with LOB data: potential storage and I/O impact
- Daily partitioning in Oracle removed → performance may be affected
- LOB columns stored in separate LOB storage in Azure SQL
- Recommendation: Implement Azure Table Partitioning by AUDIT_TIMESTAMP (monthly)
- Alternative LOBS: If messages >2GB, consider FileStream or external storage

CRITICAL ACTION ITEMS:
- MUST: Analyze actual message sizes before deployment
- MUST: Test LOB performance on large dataset before production
- MUST: Implement monthly archival strategy for audit data
- MUST: Configure retention policy (recommend 1-2 years)
- SHOULD: Implement table partitioning by AUDIT_TIMESTAMP for >500GB tables
- SHOULD: Consider external storage option (Azure Blob) for very large messages

STORAGE ANALYSIS REQUIRED:
- Determine average MESSAGE_CONTENT size
- Estimate total table size at production scale
- Evaluate LOB performance requirements
- Consider FileStream for messages >2GB (complex migration)

DATA RETENTION RECOMMENDATION:
- Archive audit messages older than 1 year to separate archive table
- Consider tiered storage (hot for current year, cool for archive)
- Implement automatic purge policy after 7+ years (compliance)
- Monitor storage costs for VARBINARY(MAX) LOB data

LOB MANAGEMENT IN AZURE SQL:
- VARBINARY(MAX) automatically uses LOB storage when >8KB
- No explicit chunk size configuration (Azure optimizes automatically)
- Automatic allocation/deallocation of LOB storage pages
- Query performance typically good for up to 2GB BLOBs
- Consider external storage (Azure Blob Storage) for >2GB per row

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: LOB storage management removed
--       Azure SQL auto-manages VARBINARY(MAX) storage and allocation

-- NOTE: Original table used Oracle composite daily partitioning:
--       LIST (CHAIN_ID) + SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by DAY
--       This has been converted to a non-partitioned table in Azure SQL
--       CRITICAL: Implement monthly RANGE partitioning for large production dataset
--       CRITICAL: Monitor LOB performance with actual message sizes

CREATE TABLE [EPS].[AUDIT_MESSAGE_CONTENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [MESSAGE_CONTENT] VARBINARY(MAX),
    [TYPE] VARCHAR(8),
    [ID_AAL] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_AUDIT_MESSAGE_CONTENT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP]),
    CONSTRAINT [FK_AUDIT_MESSAGE_CONTENT_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- CRITICAL: Implement RANGE partitioning by AUDIT_TIMESTAMP for production performance
-- Example: Monthly partitioning for 24-month retention
-- CREATE PARTITION FUNCTION pf_amc_timestamp (DATETIME2(6)) AS
-- RANGE LEFT FOR VALUES (
--    '2024-06-01', '2024-07-01', '2024-08-01', ... '2026-06-01'
-- )
-- CREATE PARTITION SCHEME ps_amc_timestamp AS PARTITION pf_amc_timestamp ALL TO ([PRIMARY])
-- ALTER TABLE [EPS].[AUDIT_MESSAGE_CONTENT] DROP CONSTRAINT [PK_AUDIT_MESSAGE_CONTENT]
-- ALTER TABLE [EPS].[AUDIT_MESSAGE_CONTENT] ADD CONSTRAINT [PK_AUDIT_MESSAGE_CONTENT] 
--     PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP]) ON ps_amc_timestamp

-- Recommended indexes for LOB table performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_MESSAGE_CONTENT_CHAIN_ID] ON [EPS].[AUDIT_MESSAGE_CONTENT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_MESSAGE_CONTENT_TIMESTAMP] ON [EPS].[AUDIT_MESSAGE_CONTENT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_MESSAGE_CONTENT_TYPE] ON [EPS].[AUDIT_MESSAGE_CONTENT]([TYPE], [AUDIT_TIMESTAMP]);

-- ROW compression ONLY for LOB table (PAGE compression can impact LOB performance)
ALTER TABLE [EPS].[AUDIT_MESSAGE_CONTENT] WITH (DATA_COMPRESSION = ROW);

-- Enable Change Tracking for audit trail
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[AUDIT_MESSAGE_CONTENT] ENABLE CHANGE_TRACKING;

-- LOB Storage Recommendation Script for Monitoring:
-- SELECT 
--    SUM(DATALENGTH([MESSAGE_CONTENT])) / 1024 / 1024 AS [Total_MB],
--    AVG(DATALENGTH([MESSAGE_CONTENT])) AS [Avg_Size],
--    MAX(DATALENGTH([MESSAGE_CONTENT])) AS [Max_Size],
--    COUNT(*) AS [Row_Count]
-- FROM [EPS].[AUDIT_MESSAGE_CONTENT]
-- WHERE [AUDIT_TIMESTAMP] >= DATEADD(MONTH, -1, GETDATE());

-- If external storage required (messages > 2GB or storage costs high):
-- 1. Create Azure Blob Storage account
-- 2. Migrate MESSAGE_CONTENT to Blob Storage
-- 3. Replace VARBINARY(MAX) with URL reference to Blob
-- 4. Update application layer to read from Blob instead of database

GO
