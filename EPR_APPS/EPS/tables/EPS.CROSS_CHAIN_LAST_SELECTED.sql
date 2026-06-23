-- =====================================================================
-- SCHEMA CONVERSION: EPS.CROSS_CHAIN_LAST_SELECTED (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CROSS_CHAIN_LAST_SELECTED
-- Target: Azure SQL Table [EPS].[CROSS_CHAIN_LAST_SELECTED]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CROSS_CHAIN_LAST_SELECTED
- Columns: 5 (cross-chain last store selection)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (ID, CHAIN_ID), 3 FKs (PATIENT, ESCHAIN, ESSTORE)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION IMMEDIATE

CONVERSION STRATEGY:
- All 5 columns converted with precision mapping
- No partitioning to handle
- PK preserved on (ID, CHAIN_ID)
- 3 FK constraints preserved (standard immediate enforcement, not DEFERRABLE)
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER(22,0) → Azure BIGINT (ID, CHAIN_ID, ID_PATIENT, NHIN_ID)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (LAST_SELECTED_DATE)

CONVERSION NOTES:
- 3 FK constraints: PATIENT, ESCHAIN, ESSTORE
- All FKs are NOT marked DEFERRABLE - standard immediate enforcement applies

POST-DEPLOYMENT ACTIONS:
1. Verify FK relationships to PATIENT, EPS_SEC_CHAIN, EPS_SEC_STORE
2. Create indexes on PATIENT and NHIN_ID for cross-chain lookups
3. Test FK constraint behavior

================================================================================
*/

CREATE TABLE [EPS].[CROSS_CHAIN_LAST_SELECTED] (
    [ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT,
    [LAST_SELECTED_DATE] DATETIME2(6),
    CONSTRAINT [PK_CROSS_CHAIN_LAST_SELECTED] PRIMARY KEY ([ID], [CHAIN_ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CCHN_LAST_SELECTED_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LAST_SELECTED_PATIENT] ON [EPS].[CROSS_CHAIN_LAST_SELECTED]([ID_PATIENT]);
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LAST_SELECTED_NHIN_ID] ON [EPS].[CROSS_CHAIN_LAST_SELECTED]([NHIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LAST_SELECTED_DATE] ON [EPS].[CROSS_CHAIN_LAST_SELECTED]([LAST_SELECTED_DATE]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CROSS_CHAIN_LAST_SELECTED] WITH (DATA_COMPRESSION = PAGE);

GO
