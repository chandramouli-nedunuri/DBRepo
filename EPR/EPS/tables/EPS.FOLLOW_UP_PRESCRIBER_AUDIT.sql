-- =====================================================================
-- TABLE: EPS.FOLLOW_UP_PRESCRIBER_AUDIT
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FOLLOW_UP_PRESCRIBER_AUDIT.sql (3,297 lines)
-- 
-- CONVERSION NOTES:
-- ├─ Composite partitioning removed (LIST by CHAIN_ID + RANGE by AUDIT_TIMESTAMP)
-- ├─ Created indexes on CHAIN_ID and AUDIT_TIMESTAMP for audit queries
-- ├─ Oracle storage parameters removed (PCTFREE, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, TIMESTAMP(6)→DATETIME2(6), VARCHAR2→VARCHAR
-- ├─ SUPPLEMENTAL LOG DATA clause removed (Oracle-specific)
-- └─ Post-deployment: Implement RANGE partitioning by AUDIT_TIMESTAMP for retention
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 4 partitions (GEAGLE, ECOM, HANNAF, MEIJER)
--            SUBPARTITION by RANGE (AUDIT_TIMESTAMP) - monthly boundaries
--   Replacement: Nonclustered indexes on (CHAIN_ID) and (AUDIT_TIMESTAMP)
--   Note: Large audit table (3,297 lines) - monthly partitioning strongly recommended
-- =====================================================================

CREATE TABLE [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT] (
    [CHAIN_ID] BIGINT,
    [ID] BIGINT,
    [ADDRESS] VARCHAR(255),
    [ADDRESS1] VARCHAR(255),
    [ARCHIVE_DATE] DATETIME2(6),
    [AREA_CODE] VARCHAR(3),
    [CITY] VARCHAR(35),
    [COUNTRY] VARCHAR(4),
    [CPM_IDENTIFIER] VARCHAR(7),
    [DEA] VARCHAR(35),
    [DELETED] VARCHAR(1),
    [FAX_AREA_CODE] VARCHAR(15),
    [FAX_PHONE] VARCHAR(7),
    [FIRST_NAME] VARCHAR(20),
    [HCID] VARCHAR(10),
    [HMS_IDENTIFIER] VARCHAR(10),
    [ID_AAL] BIGINT,
    [LAST_NAME] VARCHAR(25),
    [LAST_UPDATED] DATETIME2(6),
    [MIDDLE_NAME] VARCHAR(20),
    [NAME] VARCHAR(28),
    [NHIN_ID] BIGINT,
    [NPI_NUM] VARCHAR(10),
    [PHONE] VARCHAR(7),
    [STATE] VARCHAR(2),
    [STATE_IDENTIFIER] VARCHAR(25),
    [ZIP] VARCHAR(15),
    [ID_AUDIT] BIGINT,
    [AUDIT_TIMESTAMP] DATETIME2(6),
    CONSTRAINT [PK_FOLLOW_UP_PRESCRIBER_AUDIT] PRIMARY KEY ([CHAIN_ID], [ID], [AUDIT_TIMESTAMP])
);
GO

-- Create indexes for partition keys
CREATE NONCLUSTERED INDEX [IDX_FOLLOW_UP_PRESCRIBER_AUDIT_CHAIN_ID] 
    ON [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT]([CHAIN_ID])
    INCLUDE ([ID], [LAST_NAME], [FIRST_NAME])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FOLLOW_UP_PRESCRIBER_AUDIT_TIMESTAMP] 
    ON [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT]([AUDIT_TIMESTAMP])
    INCLUDE ([CHAIN_ID], [ID], [NPI_NUM])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for large prescriber audit volume)
ALTER TABLE [EPS].[FOLLOW_UP_PRESCRIBER_AUDIT] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Create RANGE partition function by AUDIT_TIMESTAMP (monthly, 24-month rolling)
-- 2. Establish archival jobs for expired partitions
-- 3. Monitor query performance against [LAST_NAME] + [FIRST_NAME] + [NPI_NUM] patterns
-- 4. Validate NPI_NUM format (should be 10-digit valid NPI)
-- 5. Consider indexed view for prescriber summary queries
