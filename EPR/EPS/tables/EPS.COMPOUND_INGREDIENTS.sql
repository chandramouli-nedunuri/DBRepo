-- =====================================================================
-- SCHEMA CONVERSION: EPS.COMPOUND_INGREDIENTS (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.COMPOUND_INGREDIENTS
-- Target: Azure SQL Table [EPS].[COMPOUND_INGREDIENTS]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.COMPOUND_INGREDIENTS
- Columns: 12 (compound ingredient information)
- Size: 2,790 lines
- Partitioning: LIST by CHAIN_ID (named partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 2, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID)
- Supplemental Logging: None mentioned
- Tablespace: EPS_X (index), PRIMARY (data)

CONVERSION STRATEGY:
- All 12 columns converted with precision mapping
- LIST partitioning removed → Non-partitioned table
- Storage parameters removed (Azure-managed)
- PK preserved on (CHAIN_ID, ID)
- Indexes created for partition elimination effect

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, ID_AAL, ID_RX_TX)
- Oracle NUMBER(10,0) → Azure BIGINT (DISPENSABLE_IDENTIFIER)
- Oracle NUMBER(15,6) → Azure DECIMAL(15,6) (QUANTITY)
- Oracle NUMBER(13,2) → Azure DECIMAL(13,2) (COST fields)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on CHAIN_ID for partition elimination effect
2. Create nonclustered index on ID_RX_TX for transaction lookup
3. Create nonclustered index on NDC for pharmaceutical code lookup

================================================================================
*/

CREATE TABLE [EPS].[COMPOUND_INGREDIENTS] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [NDC] VARCHAR(11) NOT NULL,
    [INGREDIENT_NAME] VARCHAR(28),
    [QUANTITY] DECIMAL(15,6),
    [BASE_COST] DECIMAL(13,2),
    [ACQUISITION_COST] DECIMAL(13,2),
    [IS_DELETED] VARCHAR(1),
    [DISPENSABLE_IDENTIFIER] BIGINT,
    CONSTRAINT [PK_COMPOUND_INGREDIENTS] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_CHAIN_ID] ON [EPS].[COMPOUND_INGREDIENTS]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_RX_TX] ON [EPS].[COMPOUND_INGREDIENTS]([ID_RX_TX]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_NDC] ON [EPS].[COMPOUND_INGREDIENTS]([NDC]);

-- ROW compression enabled for decimal column optimization
ALTER TABLE [EPS].[COMPOUND_INGREDIENTS] WITH (DATA_COMPRESSION = ROW);

GO
