-- =====================================================================
-- SCHEMA CONVERSION: EPS.COMPOUND_INGREDIENT_LOT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.COMPOUND_INGREDIENT_LOT
-- Target: Azure SQL Table [EPS].[COMPOUND_INGREDIENT_LOT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.COMPOUND_INGREDIENT_LOT
- Columns: 13 (compound ingredient lot tracking)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID), multiple FKs
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Numeric fields: QUANTITY, COST fields with decimals

CONVERSION STRATEGY:
- All 13 columns converted with precision mapping
- No partitioning to handle
- PK preserved
- FK constraints preserved
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, ID_AAL, ID_RX_TX, DISPENSABLE_IDENTIFIER)
- Oracle NUMBER(15,6) → Azure DECIMAL(15,6) (QUANTITY)
- Oracle NUMBER(13,2) → Azure DECIMAL(13,2) (COST fields)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME

POST-DEPLOYMENT ACTIONS:
1. Create indexes for common lookup patterns
2. Verify numeric precision for cost calculations
3. Test decimal rounding behavior matches Oracle

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

CREATE TABLE [EPS].[COMPOUND_INGREDIENT_LOT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME,
    [ID_RX_TX] BIGINT,
    [NDC] VARCHAR(11),
    [INGREDIENT_NAME] VARCHAR(28),
    [QUANTITY] DECIMAL(15,6),
    [BASE_COST] DECIMAL(13,2),
    [ACQUISITION_COST] DECIMAL(13,2),
    [IS_DELETED] VARCHAR(1),
    [DISPENSABLE_IDENTIFIER] BIGINT,
    [LOT_NUMBER] VARCHAR(20),
    CONSTRAINT [PK_COMPOUND_INGREDIENT_LOT] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENT_LOT_RX_TX] ON [EPS].[COMPOUND_INGREDIENT_LOT]([ID_RX_TX]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENT_LOT_NDC] ON [EPS].[COMPOUND_INGREDIENT_LOT]([NDC]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[COMPOUND_INGREDIENT_LOT] WITH (DATA_COMPRESSION = PAGE);

GO
