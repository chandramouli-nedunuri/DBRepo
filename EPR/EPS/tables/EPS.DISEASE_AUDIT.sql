-- =====================================================================
-- SCHEMA CONVERSION: EPS.DISEASE_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.DISEASE_AUDIT
-- Target: Azure SQL Table [EPS].[DISEASE_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.DISEASE_AUDIT
- Columns: 17 (disease diagnosis audit)
- Size: 3,286 lines
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP by month)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS, AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 17 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for precision
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL, ID_AUDIT)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED, DURATION, ICD9_TYPE, CONVERTED)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME (LAST, LAST_UPDATED, STOP)
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) (AUDIT_TIMESTAMP)

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

CREATE TABLE [EPS].[DISEASE_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [DIAGNOSIS_QUALIFIER] VARCHAR(2),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [CONVERTED] VARCHAR(1)
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_DISEASE_AUDIT_TIMESTAMP] ON [EPS].[DISEASE_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_DISEASE_AUDIT_CHAIN_ID] ON [EPS].[DISEASE_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_DISEASE_AUDIT_PATIENT] ON [EPS].[DISEASE_AUDIT]([ID_PATIENT], [AUDIT_TIMESTAMP]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[DISEASE_AUDIT] WITH (DATA_COMPRESSION = PAGE);

GO
