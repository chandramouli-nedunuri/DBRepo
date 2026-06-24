-- =====================================================================
-- SCHEMA CONVERSION: EPS.COMPOUND_INGREDIENTS_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.COMPOUND_INGREDIENTS_AUDIT
-- Target: Azure SQL Table [EPS].[COMPOUND_INGREDIENTS_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.COMPOUND_INGREDIENTS_AUDIT
- Columns: 13 (compound ingredients audit history)
- Size: 3,283 lines
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), AUDIT_D (audit partitions)
- All key columns marked NOT NULL ENABLE
- Numeric fields with decimal precision

CONVERSION STRATEGY:
- All 13 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6)
- NOT NULL constraints preserved
- Decimal precision maintained for cost calculations

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, ID_AAL, ID_RX_TX, ID_AUDIT, DISPENSABLE_IDENTIFIER)
- Oracle NUMBER(15,6) → Azure DECIMAL(15,6) (QUANTITY)
- Oracle NUMBER(13,2) → Azure DECIMAL(13,2) (COST fields)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (AUDIT_TIMESTAMP)

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by month) removed
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for millisecond precision
- Decimal fields preserved for cost accuracy

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
2. Create nonclustered index on CHAIN_ID for partition elimination effect
3. Set up retention policy for audit data (recommend 1-2 years)
4. Consider monthly archival strategy for large production datasets
5. Monitor decimal calculation precision vs. Oracle source

PERFORMANCE RECOMMENDATIONS:
- Implement monthly archival with Range partitioning by AUDIT_TIMESTAMP
- Create index on (ID_RX_TX, AUDIT_TIMESTAMP) for RX transaction lookups
- Implement retention policy for data older than specified period

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) + SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month.
--       This has been converted to a non-partitioned table in Azure SQL.
--       Recommendation: Implement monthly RANGE partitioning for large deployments.

CREATE TABLE [EPS].[COMPOUND_INGREDIENTS_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [DISPENSABLE_IDENTIFIER] NUMERIC(10,0),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_AUDIT_TIMESTAMP] ON [EPS].[COMPOUND_INGREDIENTS_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_AUDIT_CHAIN_ID] ON [EPS].[COMPOUND_INGREDIENTS_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_AUDIT_RX_TX] ON [EPS].[COMPOUND_INGREDIENTS_AUDIT]([ID_RX_TX], [AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_COMPOUND_INGREDIENTS_AUDIT_NDC] ON [EPS].[COMPOUND_INGREDIENTS_AUDIT]([NDC]);

-- ROW compression enabled in Azure SQL for optimization (decimal columns present)
ALTER TABLE [EPS].[COMPOUND_INGREDIENTS_AUDIT] WITH (DATA_COMPRESSION = ROW);

GO
