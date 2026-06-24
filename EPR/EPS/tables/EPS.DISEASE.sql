-- =====================================================================
-- SCHEMA CONVERSION: EPS.DISEASE (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.DISEASE
-- Target: Azure SQL Table [EPS].[DISEASE]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.DISEASE
- Columns: 15 (disease diagnosis information)
- Size: 1,929 lines
- Partitioning: LIST by CHAIN_ID (8 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 3 DEFERRABLE FKs
- Supplemental Logging: ALL COLUMNS, PRIMARY KEY, UNIQUE INDEX, FOREIGN KEY
- Tablespace: USERS, EPS_D (data partitions)

CONVERSION STRATEGY:
- All 15 columns converted with precision mapping
- LIST partitioning removed → Non-partitioned table
- Storage parameters removed (Azure-managed)
- 3 FK constraints converted (NOTE: deferrability behavior changed)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, DURATION, ICD9_TYPE, CONVERTED)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME (LAST, LAST_UPDATED, STOP)

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: 3 constraints marked DEFERRABLE INITIALLY DEFERRED
     * DISEASE_FK_ESCHAIN
     * DISEASE_FK_ESSTORE
     * DISEASE_FK_PATIENT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Impact: Application code must ensure FK validity before INSERT/UPDATE
   - Action: Review and test transaction logic with FK dependencies

2. PARTITIONING SIMPLIFIED
   - Oracle: LIST by CHAIN_ID with 8 partitions
   - Azure: Non-partitioned
   - Impact: Partition elimination no longer available for CHAIN_ID filters
   - Action: Create nonclustered index on CHAIN_ID for similar effect

POST-DEPLOYMENT ACTIONS:
1. Test FK constraint behavior with application team
2. Create nonclustered indexes on CHAIN_ID, ID_PATIENT
3. Validate transaction logic handles immediate FK constraints
4. Consider filtered index on (CHAIN_ID) WHERE DELETED IS NULL

================================================================================
*/

CREATE TABLE [EPS].[DISEASE] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST] DATETIME,
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [DS_CODE] VARCHAR(30),
    [DURATION] CHAR(1),
    [ICD9] VARCHAR(10),
    [ICD9_TYPE] CHAR(1),
    [STOP] DATETIME,
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [DIAGNOSIS_QUALIFIER] VARCHAR(2),
    [CONVERTED] VARCHAR(1),
    CONSTRAINT [FK_DISEASE_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_DISEASE_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_DISEASE_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_DISEASE_CHAIN_ID] ON [EPS].[DISEASE]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_DISEASE_PATIENT] ON [EPS].[DISEASE]([CHAIN_ID], [ID_PATIENT]);
CREATE NONCLUSTERED INDEX [IDX_DISEASE_NHIN_ID] ON [EPS].[DISEASE]([CHAIN_ID], [NHIN_ID]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[DISEASE] WITH (DATA_COMPRESSION = PAGE);

GO
