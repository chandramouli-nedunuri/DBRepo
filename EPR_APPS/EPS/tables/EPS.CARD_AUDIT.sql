-- =====================================================================
-- SCHEMA CONVERSION: EPS.CARD_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CARD_AUDIT
-- Target: Azure SQL Table [EPS].[CARD_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CARD_AUDIT
- Columns: 27 (insurance card audit history)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS, AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 27 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6)
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_AAL, ID_AUDIT)
- Oracle NUMBER(10,0) → Azure BIGINT (DISPENSABLE_IDENTIFIER)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, ELIGIBLE, WORKMANS_COMP_FLAG)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by month) removed
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for audit trail precision

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
2. Create nonclustered index on CHAIN_ID for partition elimination effect
3. Set up retention policy for audit data (recommend 1-2 years)
4. Consider monthly archival strategy

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) + SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month.
--       This has been converted to a non-partitioned table in Azure SQL.

CREATE TABLE [EPS].[CARD_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [DISPENSABLE_IDENTIFIER] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [CONTRACT_IDENTIFIER] VARCHAR(10)
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_CARD_AUDIT_CHAIN_ID] ON [EPS].[CARD_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CARD_AUDIT_TIMESTAMP] ON [EPS].[CARD_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_CARD_AUDIT_LAST_NAME] ON [EPS].[CARD_AUDIT]([LAST_NAME], [FIRST_NAME]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CARD_AUDIT] WITH (DATA_COMPRESSION = PAGE);

GO
