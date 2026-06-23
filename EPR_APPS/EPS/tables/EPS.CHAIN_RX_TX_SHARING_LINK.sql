-- =====================================================================
-- SCHEMA CONVERSION: EPS.CHAIN_RX_TX_SHARING_LINK (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CHAIN_RX_TX_SHARING_LINK
-- Target: Azure SQL Table [EPS].[CHAIN_RX_TX_SHARING_LINK]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CHAIN_RX_TX_SHARING_LINK
- Columns: 7 (chain RX/TX sharing links)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID), 2 Foreign Keys (both to SEC_ADMIN.EPS_SEC_CHAIN)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION IMMEDIATE, self-referencing chain links

CONVERSION STRATEGY:
- All 7 columns converted with precision mapping
- No partitioning to handle
- PK preserved on (CHAIN_ID, ID)
- 2 FK constraints preserved (chain to linked chain relationship)
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, LINKED_CHAIN_ID)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME

CONVERSION NOTES:
- Table implements inter-chain relationships (CHAIN_ID → LINKED_CHAIN_ID)
- Both FKs reference SEC_ADMIN.EPS_SEC_CHAIN, creating a self-linking structure
- No deferrability issues (FKs not marked DEFERRABLE)

POST-DEPLOYMENT ACTIONS:
1. Create index on LINKED_CHAIN_ID for chain relationship lookup
2. Verify chain linking data integrity after migration
3. Test chain traversal queries for performance

PERFORMANCE RECOMMENDATIONS:
- Create index on (LINKED_CHAIN_ID, CHAIN_ID) for chain hierarchy queries
- Create filtered index on (CHAIN_ID) WHERE DELETED IS NULL for active links

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: SEGMENT CREATION IMMEDIATE removed - not applicable in Azure SQL

CREATE TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [ADDED] DATETIME,
    [LAST_UPDATED] DATETIME,
    [LINKED_CHAIN_ID] BIGINT NOT NULL,
    [USER_CODE] VARCHAR(20),
    CONSTRAINT [PK_CHAIN_RX_TX_SHARING_LINK] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_CHAIN_RX_TX_LINK_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CHAIN_RX_TX_LINK_LINKED] FOREIGN KEY ([LINKED_CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_CHAIN_RX_TX_LINK_LINKED_CHAIN] ON [EPS].[CHAIN_RX_TX_SHARING_LINK]([LINKED_CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CHAIN_RX_TX_LINK_ACTIVE] ON [EPS].[CHAIN_RX_TX_SHARING_LINK]([CHAIN_ID]) WHERE [DELETED] IS NULL;

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CHAIN_RX_TX_SHARING_LINK] WITH (DATA_COMPRESSION = PAGE);

GO
