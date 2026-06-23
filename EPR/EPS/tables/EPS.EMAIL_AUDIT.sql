-- =====================================================================
-- SCHEMA CONVERSION: EPS.EMAIL_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.EMAIL_AUDIT
-- Target: Azure SQL Table [EPS].[EMAIL_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.EMAIL_AUDIT
- Columns: 15 (email address audit)
- Size: 3,285 lines
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP by month)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS, AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 15 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for precision
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL, ID_AUDIT)
- Oracle NUMBER(3,0) → Azure NUMERIC(3,0) (SERVICE_VENDOR)
- Oracle NUMBER(5,0) → Azure NUMERIC(5,0) (AUTH_CODE)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, IN_ACTIVE, LOCATION_TYPE)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME (LAST_UPDATED, LAST_UPDATE)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (TERMS_OF_SERVICE_DATE, AUDIT_TIMESTAMP)

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

CREATE TABLE [EPS].[EMAIL_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [SERVICE_VENDOR] NUMERIC(3,0),
    [AUTH_CODE] NUMERIC(5,0),
    [TERMS_OF_SERVICE_DATE] DATETIME2(6),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_EMAIL_AUDIT_TIMESTAMP] ON [EPS].[EMAIL_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_AUDIT_CHAIN_ID] ON [EPS].[EMAIL_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_AUDIT_patient] ON [EPS].[EMAIL_AUDIT]([ID_PATIENT], [AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_EMAIL_AUDIT_ADDRESS] ON [EPS].[EMAIL_AUDIT]([EMAIL_ADDRESS]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[EMAIL_AUDIT] WITH (DATA_COMPRESSION = PAGE);

GO
