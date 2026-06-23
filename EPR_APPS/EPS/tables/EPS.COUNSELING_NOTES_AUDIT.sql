-- =====================================================================
-- SCHEMA CONVERSION: EPS.COUNSELING_NOTES_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.COUNSELING_NOTES_AUDIT
-- Target: Azure SQL Table [EPS].[COUNSELING_NOTES_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.COUNSELING_NOTES_AUDIT
- Columns: 11 (counseling notes audit)
- Size: 3,285 lines
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP by month)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: PK on ID
- Supplemental Logging: None mentioned
- Tablespace: EPS_D (audit partitions), EPS_X (index)

CONVERSION STRATEGY:
- All 11 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- PK preserved on ID
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for precision

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (ID, CHAIN_ID, ID_AAL, NHIN_ID, RX_TX_ID, ID_AUDIT)
- Oracle NUMBER(38,0) → Azure BIGINT (ID)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (STORE_NOTE_CREATED_DATE, LAST_UPDATED, AUDIT_TIMESTAMP)

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by month) removed
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for millisecond precision

POST-DEPLOYMENT ACTIONS:
1. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
2. Create nonclustered index on CHAIN_ID for partition elimination effect
3. Set up retention policy for audit data (recommend 1-2 years)
4. Consider monthly archival strategy for large production datasets

================================================================================
*/

CREATE TABLE [EPS].[COUNSELING_NOTES_AUDIT] (
    [ID] BIGINT,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_AAL] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NOT NULL,
    [STORE_NOTE_CREATED_DATE] DATETIME2(6) NOT NULL,
    [CREATED_BY_USER_IDENTIFIER] VARCHAR(255) NOT NULL,
    [NOTE] VARCHAR(2000),
    [LAST_UPDATED] DATETIME2(6),
    [RX_TX_ID] BIGINT NOT NULL,
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [PK_COUNSELING_NOTES_AUDIT] PRIMARY KEY ([ID])
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_COUNSELING_NOTES_AUDIT_TIMESTAMP] ON [EPS].[COUNSELING_NOTES_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_COUNSELING_NOTES_AUDIT_CHAIN_ID] ON [EPS].[COUNSELING_NOTES_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_COUNSELING_NOTES_AUDIT_RX_TX] ON [EPS].[COUNSELING_NOTES_AUDIT]([RX_TX_ID], [AUDIT_TIMESTAMP]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[COUNSELING_NOTES_AUDIT] WITH (DATA_COMPRESSION = PAGE);

GO
