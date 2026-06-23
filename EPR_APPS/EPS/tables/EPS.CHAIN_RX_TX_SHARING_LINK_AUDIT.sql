-- =====================================================================
-- SCHEMA CONVERSION: EPS.CHAIN_RX_TX_SHARING_LINK_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CHAIN_RX_TX_SHARING_LINK_AUDIT
-- Target: Azure SQL Table [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CHAIN_RX_TX_SHARING_LINK_AUDIT
- Columns: 9 (chain RX/TX sharing audit)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS, AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 9 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6)
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6)

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
2. Create nonclustered index on CHAIN_ID for partition elimination effect
3. Set up retention policy for audit data

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) + SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month
--       This has been converted to a non-partitioned table in Azure SQL.

CREATE TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [ADDED] DATETIME,
    [LAST_UPDATED] DATETIME,
    [LINKED_CHAIN_ID] BIGINT NOT NULL,
    [USER_CODE] VARCHAR(20),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_CHAIN_RX_TX_LINK_AUDIT_TIMESTAMP] ON [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_CHAIN_RX_TX_LINK_AUDIT_CHAIN_ID] ON [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CHAIN_RX_TX_LINK_AUDIT_LINKED] ON [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT]([LINKED_CHAIN_ID]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK_AUDIT] WITH (DATA_COMPRESSION = PAGE);

GO
