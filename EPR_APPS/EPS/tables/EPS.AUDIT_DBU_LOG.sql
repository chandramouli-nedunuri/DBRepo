-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_DBU_LOG (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_DBU_LOG
-- Target: Azure SQL Table [EPS].[AUDIT_DBU_LOG]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_DBU_LOG
- Columns: 8 (database batch utility audit logs)
- Partitioning: None (non-partitioned table)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on ID
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION IMMEDIATE (eager allocation)

CONVERSION STRATEGY:
- All 8 columns converted with precision mapping
- No partitioning to handle
- PK preserved on ID
- Storage parameters removed (Azure-managed)
- SEGMENT CREATION IMMEDIATE removed (not applicable in Azure SQL)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (ID, DBU_ROWS)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)

CONVERSION NOTES:
- Simple non-partitioned table - straightforward conversion
- SEGMENT CREATION IMMEDIATE removed (Oracle optimization, not needed in Azure SQL)
- PK on single ID column (simple BIGINT key)
- VARCHAR fields for SQL text and parameters (max 2000 chars)
- No foreign key constraints

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on EXEC_TIME_STAMP for query filtering
2. Create nonclustered index on DBU_TABLE for procedure/table lookup
3. Monitor table size and implement retention policy for old logs
4. Enable Change Tracking if auditability required

PERFORMANCE RECOMMENDATIONS:
- This is a high-volume log table (runs frequently during DBU operations)
- Implement monthly retention policy (keep 3-6 months of data)
- Archive old logs to separate archive table for compliance
- Create index on (DBU_TABLE, EXEC_TIME_STAMP) for common queries

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: SEGMENT CREATION IMMEDIATE removed
--       Azure SQL manages segment allocation automatically

CREATE TABLE [EPS].[AUDIT_DBU_LOG] (
    [ID] BIGINT NOT NULL,
    [EXEC_TIME_STAMP] DATETIME2(6),
    [USER_ID] VARCHAR(30),
    [DBU_TABLE] VARCHAR(30),
    [DBU_PARMS] VARCHAR(2000),
    [DBU_ROWS] BIGINT,
    [SQL_TEXT] VARCHAR(2000),
    [ERROR_TEXT] VARCHAR(2000),
    CONSTRAINT [PK_AUDIT_DBU_LOG] PRIMARY KEY ([ID])
);

-- Recommended indexes for audit log performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_DBU_LOG_TIMESTAMP] ON [EPS].[AUDIT_DBU_LOG]([EXEC_TIME_STAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_DBU_LOG_TABLE] ON [EPS].[AUDIT_DBU_LOG]([DBU_TABLE], [EXEC_TIME_STAMP]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[AUDIT_DBU_LOG] WITH (DATA_COMPRESSION = PAGE);

-- Enable Change Tracking if needed
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[AUDIT_DBU_LOG] ENABLE CHANGE_TRACKING;

GO
