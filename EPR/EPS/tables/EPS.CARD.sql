-- =====================================================================
-- SCHEMA CONVERSION: EPS.CARD (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CARD
-- Target: Azure SQL Table [EPS].[CARD]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CARD
- Columns: 24 (insurance card information)
- Size: 2,812 lines
- Partitioning: LIST by CHAIN_ID (100+ partitions)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 2 Foreign Keys (DEFERRABLE INITIALLY DEFERRED)
- Supplemental Logging: ALL COLUMNS, PRIMARY KEY, UNIQUE INDEX, FOREIGN KEY
- Tablespace: USERS (base), EPS_D (data partitions), EPS_X (index partitions)

CONVERSION STRATEGY:
- All 24 columns converted with precision mapping
- Partitioning (LIST by CHAIN_ID) REMOVED → Non-partitioned table
- Foreign key constraints replicated (note: deferrability behavior changed)
- Storage parameters removed (Azure-managed)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_AAL)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, ELIGIBLE, WORKMANS_COMP_FLAG)
- Oracle VARCHAR2(n) → Azure VARCHAR(n) (dates, IDs, names, codes, numbers)
- Oracle DATE → Azure DATETIME (coverage dates, plan date)

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
2. Create nonclustered indexes on CHAIN_ID, CARRIER_ID for query optimization
3. Verify transaction logic handles immediate FK constraints
4. Consider filtered index on DELETED for active cards queries

PERFORMANCE RECOMMENDATIONS:
- Create index on (CHAIN_ID, NHIN_ID) for multi-tenant queries
- Create index on CARD_NUMBER for card lookup
- Consider filtered index on (CHAIN_ID) WHERE DELETED IS NULL

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle LIST partitioning:
--       CHAIN_ID values (100+ partitions: GEAGLE=102, ECOM=99, HANNAF=88, MEIJER=128, etc.)
--       This has been converted to a non-partitioned table in Azure SQL.

CREATE TABLE [EPS].[CARD] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [BEGINNING_COVERAGE_DATE] DATETIME,
    [BENEFIT] VARCHAR(5),
    [CARD_NUMBER] VARCHAR(20),
    [CARD_NUMBER_QUALIFIER] VARCHAR(2),
    [COVERAGE_CODE] VARCHAR(6),
    [ELIGIBLE] CHAR(1),
    [ENDING_COVERAGE_DATE] DATETIME,
    [FIRST_NAME] VARCHAR(20),
    [LAST_NAME] VARCHAR(25),
    [MIDDLE_NAME] VARCHAR(20),
    [WORKMANS_COMP_FLAG] CHAR(1),
    [CARRIER_ID] VARCHAR(10),
    [PLAN_DATE] DATETIME,
    [PLAN_NUMBER] VARCHAR(15),
    [GROUP_NUMBER] VARCHAR(15),
    [CARD_HOLDER_NAME] VARCHAR(47),
    [ALT_CARD] VARCHAR(20),
    [ID_AAL] BIGINT,
    [CONTRACT_IDENTIFIER] VARCHAR(10),
    CONSTRAINT [PK_CARD] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_CARD_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CARD_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_CARD_CHAIN_ID] ON [EPS].[CARD]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CARD_NHIN_ID] ON [EPS].[CARD]([CHAIN_ID], [NHIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CARD_CARD_NUMBER] ON [EPS].[CARD]([CARD_NUMBER]);
CREATE NONCLUSTERED INDEX [IDX_CARD_PATIENT] ON [EPS].[CARD]([CHAIN_ID], [LAST_NAME], [FIRST_NAME]) WHERE [DELETED] IS NULL;

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CARD] WITH (DATA_COMPRESSION = PAGE);

GO
