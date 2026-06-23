-- =====================================================================
-- TABLE: EPS.FOLLOW_UP_PRESCRIBER
-- =====================================================================
-- Conversion: Oracle → Azure SQL Server
-- Source: EPS.FOLLOW_UP_PRESCRIBER.sql (1,942 lines)
-- 
-- CONVERSION NOTES:
-- ├─ LIST partitioning by CHAIN_ID removed (13 named partitions)
-- ├─ Created nonclustered indexes on CHAIN_ID, NPI_NUM, and name lookups
-- ├─ Oracle storage parameters removed (PCTFREE, INITRANS, TABLESPACE, etc.)
-- ├─ Data type mappings: NUMBER→BIGINT, TIMESTAMP(6)→DATETIME2(6), VARCHAR2→VARCHAR
-- ├─ Mixed LOGGING/NOLOGGING removed (Azure SQL manages all logging)
-- └─ No DEFERRABLE foreign keys detected
--
-- PARTITIONING STRATEGY REMOVED:
--   Previous: LIST (CHAIN_ID) with 13 partitions (GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, 
--            SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ)
--            with mixed STORAGE clauses (INITIAL 65536 NEXT 1048576 for MEIJER/RXCOM)
--   Replacement: Nonclustered indexes for partition elimination
--   Note: Prescriber reference table - consider SCD Type 2 tracking
-- =====================================================================

CREATE TABLE [EPS].[FOLLOW_UP_PRESCRIBER] (
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
    CONSTRAINT [PK_FOLLOW_UP_PRESCRIBER] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for partition key and prescriber lookup patterns
CREATE NONCLUSTERED INDEX [IDX_FOLLOW_UP_PRESCRIBER_CHAIN_ID] 
    ON [EPS].[FOLLOW_UP_PRESCRIBER]([CHAIN_ID])
    INCLUDE ([ID], [NPI_NUM], [LAST_NAME], [FIRST_NAME])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FOLLOW_UP_PRESCRIBER_NPI] 
    ON [EPS].[FOLLOW_UP_PRESCRIBER]([NPI_NUM])
    INCLUDE ([CHAIN_ID], [ID], [LAST_NAME])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_FOLLOW_UP_PRESCRIBER_NAME] 
    ON [EPS].[FOLLOW_UP_PRESCRIBER]([LAST_NAME], [FIRST_NAME])
    INCLUDE ([CHAIN_ID], [DEA], [NPI_NUM])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression (PAGE for reference data with moderate volume)
ALTER TABLE [EPS].[FOLLOW_UP_PRESCRIBER] 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- Post-deployment actions:
-- 1. Create filtered index for active prescribers: WHERE [DELETED] IS NULL
-- 2. Validate [NPI_NUM] format compliance (must be valid NPI)
-- 3. Verify DEA certification references
-- 4. Monitor (LAST_NAME, FIRST_NAME) query performance
-- 5. Establish data governance for DELETED flag vs record archival
-- 6. Validate [ARCHIVE_DATE] usage patterns and retention policy
