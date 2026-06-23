-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_PHI_EVENT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_PHI_EVENT
-- Target: Azure SQL Table [EPS].[AUDIT_PHI_EVENT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_PHI_EVENT
- Columns: 7 (PHI event audit tracking)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- All columns marked NOT NULL (strict schema)

CONVERSION STRATEGY:
- All 7 columns converted with precision mapping
- No partitioning to handle
- PK preserved on (CHAIN_ID, ID)
- NOT NULL constraints preserved on all columns except those defaulted
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (SCREEN_ENTER_DATE)

POST-DEPLOYMENT ACTIONS:
1. Create index on SCREEN_ENTER_DATE for time-based queries
2. Monitor SCREEN_NAME and USERNAME columns for uniqueness
3. Set up retention policy if needed (audit data growth)

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

CREATE TABLE [EPS].[AUDIT_PHI_EVENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [USERNAME] VARCHAR(255) NOT NULL,
    [SCREEN_NAME] VARCHAR(255) NOT NULL,
    [SCREEN_ENTER_DATE] DATETIME2(6) NOT NULL,
    [APPLICATION] VARCHAR(255) NOT NULL,
    [STATION_LABEL] VARCHAR(50) NOT NULL,
    CONSTRAINT [PK_AUDIT_PHI_EVENT] PRIMARY KEY ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_PHI_EVENT_SCREEN_DATE] ON [EPS].[AUDIT_PHI_EVENT]([SCREEN_ENTER_DATE])
    INCLUDE ([USERNAME], [SCREEN_NAME]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_PHI_EVENT_USERNAME] ON [EPS].[AUDIT_PHI_EVENT]([USERNAME]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_PHI_EVENT_APPLICATION] ON [EPS].[AUDIT_PHI_EVENT]([APPLICATION]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[AUDIT_PHI_EVENT] WITH (DATA_COMPRESSION = PAGE);

GO
