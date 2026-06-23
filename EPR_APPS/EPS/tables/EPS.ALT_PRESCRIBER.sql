-- =====================================================================
-- SCHEMA CONVERSION: EPS.ALT_PRESCRIBER (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ALT_PRESCRIBER
-- Target: Azure SQL Table [EPS].[ALT_PRESCRIBER]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ALT_PRESCRIBER
- Columns: 28
- Partitioning: LIST by CHAIN_ID (100+ partitions)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 2 Foreign Keys (DEFERRABLE)
- Supplemental Logging: ALL COLUMNS, PRIMARY KEY, UNIQUE INDEX, FOREIGN KEY
- Tablespace: USERS (base), EPS_D (data partitions), EPS_X (index partitions)

CONVERSION STRATEGY:
- All 28 columns converted with precision mapping
- Partitioning (LIST by CHAIN_ID) REMOVED → Non-partitioned table
- Foreign key constraints replicated (note: deferrability behavior changed)
- Storage parameters removed (Azure-managed)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_AAL)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED flag)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: Constraints can be deferred until COMMIT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Impact: Application code must ensure FK validity before INSERT/UPDATE
   - Action: Review and test transaction logic with FK dependencies

2. PARTITIONING SIMPLIFIED
   - Oracle: 100+ LIST partitions by CHAIN_ID
   - Azure: Non-partitioned
   - Impact: Partition elimination no longer available for CHAIN_ID filters
   - Action: Create nonclustered index on CHAIN_ID for similar effect

POST-DEPLOYMENT ACTIONS:
1. Test FK constraint behavior with application team
2. Create nonclustered indexes on CHAIN_ID, NPI_NUM for query optimization
3. Consider implementing filtered index on NPI_NUM for performance
4. Enable Change Tracking if audit trail required

PERFORMANCE RECOMMENDATIONS:
- Create nonclustered index on (NPI_NUM, LAST_NAME, FIRST_NAME) for provider lookup
- Create filtered index on (CHAIN_ID, LAST_NAME) WHERE DELETED IS NULL

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle LIST partitioning:
--       CHAIN_ID values (100+ partitions: GEAGLE=102, ECOM=99, HANNAF=88, MEIJER=128, etc.)
--       This has been converted to a non-partitioned table in Azure SQL

CREATE TABLE [EPS].[ALT_PRESCRIBER] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ADDRESS] VARCHAR(255),
    [ADDRESS1] VARCHAR(255),
    [AREA_CODE] VARCHAR(3),
    [CITY] VARCHAR(35),
    [COUNTRY] VARCHAR(4),
    [DEA] VARCHAR(35),
    [FAX_AREA_CODE] VARCHAR(15),
    [FAX_PHONE] VARCHAR(7),
    [FIRST_NAME] VARCHAR(20),
    [LAST_NAME] VARCHAR(25),
    [MIDDLE_NAME] VARCHAR(20),
    [NAME] VARCHAR(28),
    [PHONE] VARCHAR(7),
    [STATE] VARCHAR(2),
    [STATE_ID] VARCHAR(15),
    [ZIP] VARCHAR(15),
    [ID_AAL] BIGINT,
    [ARCHIVE_DATE] DATETIME,
    [NPI_NUM] VARCHAR(10),
    [HCID] VARCHAR(10),
    [HMS_IDENTIFIER] VARCHAR(10),
    [CPM_IDENTIFIER] VARCHAR(7),
    [LAST_UPDATE_TIMESTAMP] DATETIME2(6),
    CONSTRAINT [PK_ALT_PRESCRIBER] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_ALT_PRESCRIBER_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_ALT_PRESCRIBER_STORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_CHAIN_ID] ON [EPS].[ALT_PRESCRIBER]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_NPI_NAME] ON [EPS].[ALT_PRESCRIBER]([NPI_NUM], [LAST_NAME], [FIRST_NAME]);
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_ACTIVE] ON [EPS].[ALT_PRESCRIBER]([CHAIN_ID], [LAST_NAME]) WHERE [DELETED] IS NULL;

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ALT_PRESCRIBER] WITH (DATA_COMPRESSION = PAGE);

GO
