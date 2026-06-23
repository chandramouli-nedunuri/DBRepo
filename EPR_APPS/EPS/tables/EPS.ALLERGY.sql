-- =====================================================================
-- SCHEMA CONVERSION: EPS.ALLERGY (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ALLERGY
-- Target: Azure SQL Table [EPS].[ALLERGY]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ALLERGY
- Columns: 18
- Partitioning: LIST by CHAIN_ID (100+ partitions)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 3 Foreign Keys (DEFERRABLE - see notes)
- Supplemental Logging: ALL COLUMNS, PRIMARY KEY, UNIQUE INDEX, FOREIGN KEY
- Tablespace: USERS (base), EPS_D (data partitions), EPS_X (index partitions)

CONVERSION STRATEGY:
- All 18 columns converted with precision mapping
- Partitioning (LIST by CHAIN_ID) REMOVED → Non-partitioned table
- Foreign key constraints replicated (note: deferrability behavior changed)
- Storage parameters removed (Azure-managed)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL)
- Oracle CHAR(1) → Azure CHAR(1) (symptom flags: BLOOD, BREATH, GI_TRACT, RASH, SHOCK, UNSPEC, DELETED)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: Constraints can be deferred until COMMIT
   - Azure SQL: ALL FK constraints are enforced immediately
   - Impact: Application code must ensure FK validity before INSERT/UPDATE
   - Action: Review and test transaction logic with FK dependencies

2. PARTITIONING SIMPLIFIED
   - Oracle: 100+ LIST partitions by CHAIN_ID
   - Azure: Non-partitioned
   - Impact: Partition elimination no longer available for CHAIN_ID filters
   - Action: Create nonclustered index on CHAIN_ID for similar effect

3. SUPPLEMENTAL LOGGING REMOVED
   - Oracle: Used for replication and audit trails
   - Azure: Enable Change Tracking if needed
   - Action: Configure Change Tracking post-deployment if required

POST-DEPLOYMENT ACTIONS:
1. Test FK constraint behavior with application team
2. Create nonclustered indexes on CHAIN_ID, NHIN_ID, ID_PATIENT for query optimization
3. Enable Change Tracking if audit trail and replication required

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle LIST partitioning:
--       CHAIN_ID values (100+ partitions: GEAGLE=102, ECOM=99, HANNAF=88, MEIJER=128, etc.)
--       This has been converted to a non-partitioned table in Azure SQL

CREATE TABLE [EPS].[ALLERGY] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ADDED] DATETIME,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [BLOOD] CHAR(1),
    [BREATH] CHAR(1),
    [GI_TRACT] CHAR(1),
    [RASH] CHAR(1),
    [REPORT_BY] VARCHAR(2),
    [SHOCK] CHAR(1),
    [START_DATE] DATETIME,
    [UNSPEC] CHAR(1),
    [AC_CODE] VARCHAR(30),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [CONVERTED] VARCHAR(1),
    CONSTRAINT [PK_ALLERGY] PRIMARY KEY ([CHAIN_ID], [ID]),
    CONSTRAINT [FK_ALLERGY_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_ALLERGY_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_ALLERGY_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_CHAIN_ID] ON [EPS].[ALLERGY]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_NHIN_ID] ON [EPS].[ALLERGY]([NHIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_PATIENT] ON [EPS].[ALLERGY]([ID_PATIENT]);
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_START_DATE] ON [EPS].[ALLERGY]([START_DATE]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ALLERGY] WITH (DATA_COMPRESSION = PAGE);

GO
