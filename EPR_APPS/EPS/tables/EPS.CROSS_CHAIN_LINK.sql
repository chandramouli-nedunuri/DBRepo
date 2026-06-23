-- =====================================================================
-- SCHEMA CONVERSION: EPS.CROSS_CHAIN_LINK (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.CROSS_CHAIN_LINK
-- Target: Azure SQL Table [EPS].[CROSS_CHAIN_LINK]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.CROSS_CHAIN_LINK
- Columns: 8 (cross-chain record linking)
- Partitioning: None (non-partitioned)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: UNIQUE on (CHAIN_ID, ID_PATIENT, EHR_ID), PK on ID, 3 DEFERRABLE FKs
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS
- Special Features: SEGMENT CREATION IMMEDIATE, ROW MOVEMENT ENABLE

CONVERSION STRATEGY:
- All 8 columns converted with precision mapping
- No partitioning to handle
- PK preserved on ID (BIGINT)
- UNIQUE constraint preserved
- 3 FK constraints converted (NOTE: deferrability behavior changed)
- Storage parameters removed (Azure-managed)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER(22,0) → Azure BIGINT (ID, EHR_ID, CHAIN_ID, ID_PATIENT, NHIN_ID)
- Oracle VARCHAR2(1) → Azure VARCHAR(1) (DELETED)
- Oracle DATE → Azure DATETIME (LAST_UPDATED)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (LAST_RX_UPDATE_DATE)

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: 3 constraints marked DEFERRABLE INITIALLY DEFERRED
     * CROSS_CHAIN_LINK_FK_ESCHAIN
     * CROSS_CHAIN_LINK_FK_ESSTORE
     * CROSS_CHAIN_LINK_FK_PATIENT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Impact: Application code must ensure FK validity before INSERT/UPDATE
   - Action: Review and test transaction logic with FK dependencies

POST-DEPLOYMENT ACTIONS:
1. Test FK constraint behavior with application team
2. Create indexes on EHR_ID, ID_PATIENT for cross-chain lookups
3. Validate transaction logic handles immediate FK constraints
4. Verify UNIQUE constraint on (CHAIN_ID, ID_PATIENT, EHR_ID)

================================================================================
*/

CREATE TABLE [EPS].[CROSS_CHAIN_LINK] (
    [ID] BIGINT,
    [EHR_ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [LAST_RX_UPDATE_DATE] DATETIME2(6),
    [DELETED] VARCHAR(1),
    CONSTRAINT [UQ_CROSS_CHAIN_LINK] UNIQUE ([CHAIN_ID], [ID_PATIENT], [EHR_ID]),
    CONSTRAINT [PK_CROSS_CHAIN_LINK] PRIMARY KEY ([ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_CROSS_CHAIN_LINK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LINK_EHR_ID] ON [EPS].[CROSS_CHAIN_LINK]([EHR_ID]);
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LINK_PATIENT] ON [EPS].[CROSS_CHAIN_LINK]([CHAIN_ID], [ID_PATIENT]);
CREATE NONCLUSTERED INDEX [IDX_CROSS_CHAIN_LINK_NHIN_ID] ON [EPS].[CROSS_CHAIN_LINK]([NHIN_ID]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[CROSS_CHAIN_LINK] WITH (DATA_COMPRESSION = PAGE);

GO
