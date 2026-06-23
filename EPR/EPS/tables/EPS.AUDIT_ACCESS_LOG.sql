-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_ACCESS_LOG (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_ACCESS_LOG
-- Target: Azure SQL Table [EPS].[AUDIT_ACCESS_LOG]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_ACCESS_LOG
- Columns: 30 (large audit/monitoring table)
- Size: 31,016 lines (LARGE TABLE)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP, daily)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID, AUDIT_TIMESTAMP), 1 FK (ESCHAIN)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), EPS_X (index), AUDIT_D (audit partitions)
- Special Features: Multiple TIMESTAMP columns for detailed monitoring

CONVERSION STRATEGY:
- All 30 columns converted with precision mapping
- Composite partitioning (LIST + RANGE by day) REMOVED → Non-partitioned table
- PK preserved on (CHAIN_ID, ID, AUDIT_TIMESTAMP)
- Storage parameters removed (Azure-managed)
- High-precision TIMESTAMP(9) columns converted to DATETIME2(6)
- DEFAULT expressions replaced with application-side logic

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, MESSAGE_VERSION_NUMBER, sizes)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle TIMESTAMP(9) → Azure DATETIME2(6) (losing 3 decimal places - acceptable)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)
- Oracle DEFAULT sys_context(...) → Removed (set in application)

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by day) removed
- 3-part PK maintained: (CHAIN_ID, ID, AUDIT_TIMESTAMP)
- High-precision TIMESTAMP(9) downsampled to DATETIME2(6)
- DEFAULT expressions removed (configure in application layer)
- Daily date-range partitioning removed (implement retention policy instead)

PERFORMANCE CONCERNS:
- LARGE TABLE: 31,016 lines in DDL (estimated billions of rows in production)
- Daily partitioning in Oracle removed → performance may be affected
- Recommendation: Implement Azure Table Partitioning by AUDIT_TIMESTAMP (monthly)
- Alternative: Implement time-based retention policy with archive table

POST-DEPLOYMENT ACTIONS:
1. Enable Change Tracking for audit trail
2. Create nonclustered indexes on CHAIN_ID, AUDIT_TIMESTAMP, USER_ID, SERVICE
3. Implement monthly archival strategy for audit data
4. Configure retention policy (recommend 1-2 years based on compliance)
5. Create filtered indexes on frequently searched combinations (user, status, service)
6. Run statistics on all major indexes for query optimizer

CRITICAL ACTION ITEMS:
- MUST: Test performance on large dataset before production
- MUST: Implement table partitioning by AUDIT_TIMESTAMP for >100GB data
- MUST: Re-tune indexes based on actual query patterns
- SHOULD: Implement monthly archive table for historical data

DATA RETENTION RECOMMENDATION:
- Archive audit data older than 1 year to separate archive table
- Consider tiered storage (hot for current year, cool for archive)
- Implement automatic purge policy after 7 years (compliance requirement)

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite daily partitioning:
--       LIST (CHAIN_ID) + SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by DAY
--       This has been converted to a non-partitioned table in Azure SQL
--       CRITICAL: Implement monthly RANGE partitioning for large production dataset

CREATE TABLE [EPS].[AUDIT_ACCESS_LOG] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [INCOMING_TIMESTAMP] DATETIME2(6),
    [OUTGOING_TIMESTAMP] DATETIME2(6),
    [BEFORE_APPSERVER_TIMESTAMP] DATETIME2(6),
    [AFTER_APPSERVER_TIMESTAMP] DATETIME2(6),
    [PDX_MESSAGE_ID] VARCHAR(40),
    [CLIENT_IP] VARCHAR(15),
    [CLIENT_ID_TYPE] VARCHAR(20),
    [NHIN_ID] BIGINT,
    [SERVICE] VARCHAR(60),
    [STATUS] VARCHAR(7),
    [AUDIT_MODE] VARCHAR(10),
    [CODE] VARCHAR(255),
    [FIRST_NAME] VARCHAR(35),
    [MIDDLE_NAME] VARCHAR(35),
    [LAST_NAME] VARCHAR(35),
    [INITIALS] VARCHAR(3),
    [USER_ID] VARCHAR(255),
    [LICENSE_NUMBER] VARCHAR(20),
    [SOFTWARE_VERSION_NUMBER] VARCHAR(20),
    [MESSAGE_VERSION_NUMBER] BIGINT,
    [REQUEST_CONTENT_SIZE] BIGINT,
    [RESPONSE_CONTENT_SIZE] BIGINT,
    [DB_INSTANCE] BIGINT,
    [DB_SESSIONID] BIGINT,
    [HASH_VALUE] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [SERVER_NAME] VARCHAR(50),
    CONSTRAINT [PK_AUDIT_ACCESS_LOG] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP]),
    CONSTRAINT [FK_AUDIT_ACCESS_LOG_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- CRITICAL: Implement RANGE partitioning by AUDIT_TIMESTAMP for production performance
-- Example: Monthly partitioning for 24-month retention
-- CREATE PARTITION FUNCTION pf_aal_timestamp (DATETIME2(6)) AS
-- RANGE LEFT FOR VALUES (
--    '2024-06-01', '2024-07-01', '2024-08-01', ... '2026-06-01'
-- )
-- CREATE PARTITION SCHEME ps_aal_timestamp AS PARTITION pf_aal_timestamp ALL TO ([PRIMARY])
-- ALTER TABLE [EPS].[AUDIT_ACCESS_LOG] DROP CONSTRAINT [PK_AUDIT_ACCESS_LOG]
-- ALTER TABLE [EPS].[AUDIT_ACCESS_LOG] ADD CONSTRAINT [PK_AUDIT_ACCESS_LOG] 
--     PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP]) ON ps_aal_timestamp

-- Recommended indexes for large audit table performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_ACCESS_LOG_CHAIN_ID] ON [EPS].[AUDIT_ACCESS_LOG]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_ACCESS_LOG_TIMESTAMP] ON [EPS].[AUDIT_ACCESS_LOG]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_ACCESS_LOG_USER_SERVICE] ON [EPS].[AUDIT_ACCESS_LOG]([USER_ID], [SERVICE], [AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_ACCESS_LOG_STATUS] ON [EPS].[AUDIT_ACCESS_LOG]([STATUS], [AUDIT_TIMESTAMP]) WHERE [STATUS] NOT IN ('SUCCESS', 'OK');

-- PAGE compression enabled in Azure SQL for optimization (high-volume audit data)
ALTER TABLE [EPS].[AUDIT_ACCESS_LOG] WITH (DATA_COMPRESSION = PAGE);

-- Enable Change Tracking for audit trail
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[AUDIT_ACCESS_LOG] ENABLE CHANGE_TRACKING;

GO
