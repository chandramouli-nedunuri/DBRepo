-- =====================================================================
-- SCHEMA CONVERSION: EPS.ALT_PRESCRIBER_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ALT_PRESCRIBER_AUDIT
-- Target: Azure SQL Table [EPS].[ALT_PRESCRIBER_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ALT_PRESCRIBER_AUDIT
- Columns: 29 (alternate prescriber audit/history table)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 29 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6) for precision
- No constraints in this table

KEY CONVERSION MAPPINGS:
- Oracle NUMBER → Azure BIGINT (CHAIN_ID, ID, NHIN_ID, ID_AAL, ID_AUDIT)
- Oracle CHAR(1) → Azure CHAR(1) (DELETED flag)
- Oracle VARCHAR2(n) → Azure VARCHAR(n)
- Oracle DATE → Azure DATETIME
- Oracle TIMESTAMP(6) → Azure DATETIME2(6) for audit trail precision

CRITICAL CONVERSIONS:
- Composite partitioning (LIST + RANGE by month) removed
- AUDIT_TIMESTAMP preserved as DATETIME2(6) for millisecond precision
- String fields for address/name info preserved as VARCHAR

POST-DEPLOYMENT ACTIONS:
1. Enable Change Tracking if replication needed
2. Create nonclustered index on AUDIT_TIMESTAMP for time-range queries
3. Create nonclustered index on CHAIN_ID for partition elimination effect
4. Consider monthly archival strategy for audit data retention
5. Implement retention policy based on business requirements

PERFORMANCE RECOMMENDATIONS:
- Large historical table: implement time-based retention policy
- Archive monthly partitions to cold storage quarterly
- Create filtered index on DELETED = 'N' for active prescriber queries

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) with 100+ partition values +
--       SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month
--       This has been converted to a non-partitioned table in Azure SQL
--       Recommendation: Implement monthly partitioning strategy for large deployments

CREATE TABLE [EPS].[ALT_PRESCRIBER_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ADDRESS] VARCHAR(255),
    [ADDRESS1] VARCHAR(255),
    [AREA_CODE] VARCHAR(3),
    [CITY] VARCHAR(35),
    [COUNTRY] VARCHAR(4),
    [DEA] VARCHAR(35),
    [FAX_AREA_CODE] VARCHAR(3),
    [FAX_PHONE] VARCHAR(7),
    [FIRST_NAME] VARCHAR(20),
    [LAST_NAME] VARCHAR(25),
    [MIDDLE_NAME] VARCHAR(20),
    [NAME] VARCHAR(28),
    [PHONE] VARCHAR(7),
    [STATE] VARCHAR(2),
    [STATE_ID] VARCHAR(15),
    [ZIP] VARCHAR(15),
    [ID_AAL] BIGINT,
    [ID_AUDIT] BIGINT,
    [ARCHIVE_DATE] DATETIME,
    [NPI_NUM] VARCHAR(10),
    [HCID] VARCHAR(10),
    [HMS_IDENTIFIER] VARCHAR(10),
    [CPM_IDENTIFIER] VARCHAR(7),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_AUDIT_CHAIN_ID] ON [EPS].[ALT_PRESCRIBER_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_AUDIT_TIMESTAMP] ON [EPS].[ALT_PRESCRIBER_AUDIT]([AUDIT_TIMESTAMP]);
CREATE NONCLUSTERED INDEX [IDX_ALT_PRESCRIBER_AUDIT_NPI] ON [EPS].[ALT_PRESCRIBER_AUDIT]([NPI_NUM]) WHERE [DELETED] IS NULL;

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ALT_PRESCRIBER_AUDIT] WITH (DATA_COMPRESSION = PAGE);

-- Enable Change Tracking for audit trail if needed
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[ALT_PRESCRIBER_AUDIT] ENABLE CHANGE_TRACKING;

GO
