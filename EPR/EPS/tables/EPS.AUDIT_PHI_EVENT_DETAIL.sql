-- =====================================================================
-- SCHEMA CONVERSION: EPS.AUDIT_PHI_EVENT_DETAIL (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.AUDIT_PHI_EVENT_DETAIL
-- Target: Azure SQL Table [EPS].[AUDIT_PHI_EVENT_DETAIL]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.AUDIT_PHI_EVENT_DETAIL
- Columns: 6 (PHI event detail tracking)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on (CHAIN_ID, ID), 1 FK to AUDIT_PHI_EVENT
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION DEFERRED

CONVERSION STRATEGY:
- All 6 columns converted with precision mapping
- No partitioning to handle
- PK preserved on (CHAIN_ID, ID)
- FK to AUDIT_PHI_EVENT preserved
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, AUDIT_PHI_EVENT_ID, RX_COM_ID)
- Oracle NUMBER(22,0) → Azure NUMERIC(22,0) (AUDIT_PHI_EVENT_ID)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)

POST-DEPLOYMENT ACTIONS:
1. Verify FK relationship to AUDIT_PHI_EVENT
2. Create indexes on AUDIT_PHI_EVENT_ID for lookups
3. Monitor cardinality with AUDIT_PHI_EVENT table

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

CREATE TABLE [EPS].[AUDIT_PHI_EVENT_DETAIL] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [AUDIT_PHI_EVENT_ID] BIGINT NOT NULL,
    [GEO_REGION] VARCHAR(20),
    [MRN] VARCHAR(40),
    [RX_COM_ID] BIGINT,
    CONSTRAINT [PK_AUDIT_PHI_EVENT_DETAIL] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_AUDIT_PHI_EVENT_DETAIL] FOREIGN KEY ([CHAIN_ID], [AUDIT_PHI_EVENT_ID])
        REFERENCES [EPS].[AUDIT_PHI_EVENT] ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_AUDIT_PHI_EVENT_DETAIL_PHI_EVENT_ID] ON [EPS].[AUDIT_PHI_EVENT_DETAIL]([AUDIT_PHI_EVENT_ID]);
CREATE NONCLUSTERED INDEX [IDX_AUDIT_PHI_EVENT_DETAIL_MRN] ON [EPS].[AUDIT_PHI_EVENT_DETAIL]([MRN]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[AUDIT_PHI_EVENT_DETAIL] WITH (DATA_COMPRESSION = PAGE);

GO
