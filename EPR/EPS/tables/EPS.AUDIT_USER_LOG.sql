-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_USER_LOG (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_USER_LOG
-- Target: Azure SQL Table [EPS].[AUDIT_USER_LOG]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_USER_LOG
- Columns: 7 (user activity audit logging)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on ID
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS

CONVERSION STRATEGY:
- All 7 columns converted with precision mapping
- No partitioning to handle
- Single-column PK on ID (BIGINT)
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (ID)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (EXEC_TIME_STAMP)

POST-DEPLOYMENT ACTIONS:
1. Create index on USER_ID for user lookup
2. Create index on EXEC_TIME_STAMP for time-range queries
3. Set up retention policy (high-volume audit table)

PERFORMANCE RECOMMENDATIONS:
- This is a high-volume audit log table
- Recommend monthly archival strategy
- Consider partitioning if growth exceeds 1GB/month

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

CREATE TABLE [EPS].[AUDIT_USER_LOG] (
    [ID] BIGINT NOT NULL,
    [EXEC_TIME_STAMP] DATETIME2(6),
    [USER_ID] VARCHAR(30),
    [ACTION] VARCHAR(30),
    [TABLE_NAME] VARCHAR(30),
    [DESCRIPTION] VARCHAR(255),
    [DB_USER] VARCHAR(30),
    CONSTRAINT [PK_AUDIT_USER_LOG] PRIMARY KEY ([ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_USER_LOG_TIMESTAMP] ON [EPS].[AUDIT_USER_LOG]([EXEC_TIME_STAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_USER_LOG_USER_ID] ON [EPS].[AUDIT_USER_LOG]([USER_ID], [EXEC_TIME_STAMP]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_USER_LOG_ACTION] ON [EPS].[AUDIT_USER_LOG]([ACTION], [EXEC_TIME_STAMP]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[AUDIT_USER_LOG] WITH (DATA_COMPRESSION = PAGE);

GO
