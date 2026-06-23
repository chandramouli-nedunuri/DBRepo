-- =====================================================================
-- SCHEMA CONVERSION: EPS.ADMIN_UNLOCK_LOG (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ADMIN_UNLOCK_LOG
-- Target: Azure SQL Table [EPS].[ADMIN_UNLOCK_LOG]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ADMIN_UNLOCK_LOG
- Columns: 5 (simple transaction table)
- Partitioning: LIST by CHAIN_ID (6 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 2 Foreign Keys (DEFERRABLE - see notes)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), EPS_D (data partitions)

CONVERSION STRATEGY:
- All 5 columns converted with precision mapping
- Partitioning (LIST by CHAIN_ID) REMOVED → Non-partitioned table
- Foreign key constraints replicated (note: deferrability behavior changed)
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, ID_PATIENT)
- Oracle NUMBER(22,0) → Azure NUMERIC(22,0)
- Oracle VARCHAR2(30) → Azure VARCHAR(30)
- Oracle DATE → Azure DATETIME

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: FK constraints can be deferred until COMMIT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Action: Review application code for transaction logic

2. PARTITIONING SIMPLIFIED
   - Oracle: LIST partitions by CHAIN_ID (GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO)
   - Azure: Non-partitioned
   - Action: Create nonclustered index on CHAIN_ID for same effect

POST-DEPLOYMENT ACTIONS:
1. Verify FK constraint behavior with application team
2. Create nonclustered index on CHAIN_ID for query optimization
3. Create nonclustered index on ID_PATIENT for audit queries

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle LIST partitioning:
--       CHAIN_ID values (102, 99, 88, 128, 119080, 180)
--       This has been converted to a non-partitioned table in Azure SQL

CREATE TABLE [EPS].[ADMIN_UNLOCK_LOG] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [REQUESTED] DATETIME,
    [USER_ID] VARCHAR(30),
    [ID_PATIENT] BIGINT,
    CONSTRAINT [PK_ADMIN_UNLOCK_LOG] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_ADMIN_UNLOCK_LOG_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_ADMIN_UNLOCK_LOG_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- Recommended indexes for query performance and query elimination
CREATE NONCLUSTERED INDEX [IDX_ADMIN_UNLOCK_LOG_CHAIN_ID] ON [EPS].[ADMIN_UNLOCK_LOG]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ADMIN_UNLOCK_LOG_PATIENT] ON [EPS].[ADMIN_UNLOCK_LOG]([ID_PATIENT]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ADMIN_UNLOCK_LOG] WITH (DATA_COMPRESSION = PAGE);

GO
