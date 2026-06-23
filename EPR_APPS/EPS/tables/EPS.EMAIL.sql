-- =====================================================================
-- SCHEMA CONVERSION: EPS.EMAIL (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.EMAIL
-- Target: Azure SQL Table [EPS].[EMAIL]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.EMAIL
- Columns: 14 (email address information)
- Size: 1,932 lines
- Partitioning: LIST by CHAIN_ID (named partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: 3 DEFERRABLE FKs
- Supplemental Logging: ALL COLUMNS, PRIMARY KEY, UNIQUE INDEX, FOREIGN KEY
- Tablespace: USERS, EPS_D (data partitions)

CONVERSION STRATEGY:
- All 14 columns converted with precision mapping
- LIST partitioning removed → Non-partitioned table
- Storage parameters removed (Azure-managed)
- 3 FK constraints converted (NOTE: deferrability behavior changed)
- Supplemental logging removed (Change Tracking alternative available)

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL)
- Oracle NUMBER(3,0) → Azure NUMERIC(3,0) (SERVICE_VENDOR)
- Oracle NUMBER(5,0) → Azure NUMERIC(5,0) (AUTH_CODE)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, IN_ACTIVE, LOCATION_TYPE)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME (LAST_UPDATED, LAST_UPDATE)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (TERMS_OF_SERVICE_DATE)

CRITICAL ISSUES IDENTIFIED:
1. FOREIGN KEY DEFERRABILITY
   - Oracle: 3 constraints marked DEFERRABLE INITIALLY DEFERRED
     * EMAIL_FK_ESCHAIN
     * EMAIL_FK_ESSTORE
     * EMAIL_FK_PATIENT
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
2. Create nonclustered indexes on CHAIN_ID, ID_PATIENT, EMAIL_ADDRESS
3. Validate transaction logic handles immediate FK constraints
4. Consider filtered index on (CHAIN_ID) WHERE DELETED IS NULL

PERFORMANCE RECOMMENDATIONS:
- EMAIL_ADDRESS is likely used for lookups; index should be unique if applicable
- IN_ACTIVE flag suggests active/inactive filtering; filtered index recommended

================================================================================
*/

CREATE TABLE [EPS].[EMAIL] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [LAST_UPDATE] DATETIME,
    [NHIN_ID] BIGINT,
    [EMAIL_ADDRESS] VARCHAR(120),
    [IN_ACTIVE] CHAR(1),
    [LOCATION_TYPE] CHAR(1),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [SERVICE_VENDOR] NUMERIC(3,0),
    [AUTH_CODE] NUMERIC(5,0),
    [TERMS_OF_SERVICE_DATE] DATETIME2(6),
    CONSTRAINT [FK_EMAIL_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [FK_EMAIL_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [FK_EMAIL_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID])
);

-- Recommended indexes for query performance and partition elimination effect
CREATE NONCLUSTERED INDEX [IDX_EMAIL_CHAIN_ID] ON [EPS].[EMAIL]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_PATIENT] ON [EPS].[EMAIL]([CHAIN_ID], [ID_PATIENT]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_ADDRESS] ON [EPS].[EMAIL]([EMAIL_ADDRESS]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_NHIN_ID] ON [EPS].[EMAIL]([CHAIN_ID], [NHIN_ID]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[EMAIL] WITH (DATA_COMPRESSION = PAGE);

GO
