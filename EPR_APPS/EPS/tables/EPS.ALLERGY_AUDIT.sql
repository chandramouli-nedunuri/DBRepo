-- =====================================================================
-- SCHEMA CONVERSION: EPS.ALLERGY_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ALLERGY_AUDIT
-- Target: Azure SQL Table [EPS].[ALLERGY_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ALLERGY_AUDIT
- Columns: 19 (audit trail table)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP by month)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 19 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6) for precision
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_PATIENT, ID_AAL, ID_AUDIT)
- Oracle CHAR(1) → Azure CHAR(1) (symptom flags)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) for audit trail precision

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by month) removed
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for millisecond precision

POST-DEPLOYMENT ACTIONS:
1. Enable Change Tracking if replication needed
2. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
3. Create nonclustered index on CHAIN_ID for partition elimination effect
4. Consider table partitioning by AUDIT_TIMESTAMP for large-scale deployments
5. Set up retention policies if this is high-volume audit data

RETENTION RECOMMENDATION:
- Consider implementing a monthly archive strategy for ALLERGY_AUDIT data
- Create partitioned table by month to manage performance and storage

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) with 100+ partition values +
--       SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month
--       This has been converted to a non-partitioned table in Azure SQL
--       Recommendation: Implement monthly partitioning strategy for large deployments

CREATE TABLE [EPS].[ALLERGY_AUDIT] (
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
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [CONVERTED] VARCHAR(1)
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_AUDIT_CHAIN_ID] ON [EPS].[ALLERGY_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_AUDIT_TIMESTAMP] ON [EPS].[ALLERGY_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_ALLERGY_AUDIT_PATIENT] ON [EPS].[ALLERGY_AUDIT]([ID_PATIENT]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ALLERGY_AUDIT] WITH (DATA_COMPRESSION = PAGE);

-- Enable Change Tracking for audit trail if needed
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[ALLERGY_AUDIT] ENABLE CHANGE_TRACKING;

-- Optional: Implement table partitioning by month for large-scale deployments
-- ALTER TABLE [EPS].[ALLERGY_AUDIT] REBUILD RETENTION POLICY
-- CREATE PARTITION FUNCTION pf_audit_timestamp (DATETIME2(6)) AS RANGE LEFT FOR VALUES (
--    '2026-06-01', '2026-07-01', '2026-08-01'
-- );

GO
