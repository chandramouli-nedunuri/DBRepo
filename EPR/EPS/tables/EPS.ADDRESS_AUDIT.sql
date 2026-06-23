-- =====================================================================
-- SCHEMA CONVERSION: EPS.ADDRESS_AUDIT (Oracle → Azure SQL)
-- Conversion Date: 2026-05-28
-- Source: Oracle Table EPS.ADDRESS_AUDIT
-- Target: Azure SQL Table [EPS].[ADDRESS_AUDIT]
-- Status: COMPLETE
-- =====================================================================

/*
CONVERSION NOTES:
================================================================================

SOURCE CHARACTERISTICS (Oracle):
- Table: EPS.ADDRESS_AUDIT
- Columns: 37 (audit trail table)
- Partitioning: Composite (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
- Storage: PCTFREE 10, PCTUSED 40, INITRANS 1, MAXTRANS 255, NO COMPRESSION
- Constraints: None (audit table)
- Supplemental Logging: ALL COLUMNS
- Tablespace: USERS (base), AUDIT_D (audit partitions)

CONVERSION STRATEGY:
- All 37 columns converted with precision mapping
- Composite partitioning (LIST + RANGE) REMOVED → Non-partitioned table
- Storage parameters removed (Azure-managed)
- Audit timestamp preserved as DATETIME2(6)
- No constraints in this table

CRITICAL CONVERSIONS:
- TIMESTAMP(6) → DATETIME2(6) for audit trail precision
- NUMBER → NUMERIC/BIGINT/INT as appropriate
- Composite partitioning on CHAIN_ID + AUDIT_TIMESTAMP removed

POST-DEPLOYMENT ACTIONS:
1. Enable Change Tracking if replication needed
2. Consider nonclustered index on AUDIT_TIMESTAMP for query performance
3. Consider nonclustered index on CHAIN_ID for partition elimination effect

================================================================================
*/

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically

-- NOTE: Original table used Oracle composite partitioning:
--       LIST (CHAIN_ID) records VALUES (102, 99, 88, 128, 119080, 180, ...)
--       SUBPARTITION BY RANGE (AUDIT_TIMESTAMP) by month
--       This has been converted to a non-partitioned table in Azure SQL

CREATE TABLE [EPS].[ADDRESS_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [DELETED] CHAR(1),
    [LAST_UPDATED] DATETIME,
    [ADDED] DATETIME,
    [UPDATED] DATETIME,
    [NHIN_ID] BIGINT,
    [ADDRESS_KEY] BIGINT,
    [ADDRESS_LINE1] VARCHAR(255),
    [ADDRESS_LINE2] VARCHAR(255),
    [ADDRESS_TYPE] BIGINT,
    [CITY] VARCHAR(35),
    [CLEAN] CHAR(1),
    [COUNTRY] VARCHAR(4),
    [DEACTIVATION_DATE] DATETIME,
    [ENDING_DATE] DATETIME,
    [VALID] CHAR(1),
    [NOTE1A] VARCHAR(35),
    [NOTE1B] VARCHAR(35),
    [PO_BOX] CHAR(1),
    [POSTAL_CODE] VARCHAR(15),
    [STARTING_DATE] DATETIME,
    [STATE] VARCHAR(2),
    [ID_PATIENT] BIGINT,
    [ID_AAL] BIGINT,
    [ID_AUDIT] BIGINT,
    [WORK_AREA_CODE] CHAR(3),
    [WORK_PHONE] VARCHAR(7),
    [HOME_AREA_CODE] CHAR(3),
    [HOME_PHONE] VARCHAR(7),
    [CARE_OF] VARCHAR(30),
    [COUNTY] VARCHAR(45),
    [MAIL_STOP] VARCHAR(25),
    [SHIPPING_ADDRESS] VARCHAR(1),
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [ADDRESS_IDENTIFIER] VARCHAR(10),
    [DEFAULT_DELIVERY_SITE] VARCHAR(4),
    [DEFAULT_ADDRESS] VARCHAR(1),
    [HOME_PHONE_UPDATED_DATE] DATETIME2(6),
    [WORK_PHONE_UPDATED_DATE] DATETIME2(6)
);

-- Recommended indexes for audit table performance
CREATE NONCLUSTERED INDEX [IDX_ADDRESS_AUDIT_CHAIN_ID] ON [EPS].[ADDRESS_AUDIT]([CHAIN_ID]);
CREATE NONCLUSTERED INDEX [IDX_ADDRESS_AUDIT_TIMESTAMP] ON [EPS].[ADDRESS_AUDIT]([AUDIT_TIMESTAMP]);

-- PAGE compression enabled in Azure SQL for optimization
ALTER TABLE [EPS].[ADDRESS_AUDIT] WITH (DATA_COMPRESSION = PAGE);

-- Enable Change Tracking for audit trail if needed
-- ALTER DATABASE [YOUR_DB] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
-- ALTER TABLE [EPS].[ADDRESS_AUDIT] ENABLE CHANGE_TRACKING;

GO
