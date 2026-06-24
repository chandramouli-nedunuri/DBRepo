-- EPS.INTAKE_SOURCES.sql
-- Oracle EPS Database Schema Conversion to Azure SQL Server 2019+
-- Table: EPS.INTAKE_SOURCES
-- Source Lines: 1926 | Columns: 9 | Type: Master Data
-- Conversion Date: 2024 | Status: ✓ CONVERTED
--
-- CONVERSION NOTES:
-- 1. LIST partitioning by CHAIN_ID removed (13 partitions: GEAGLE, ECOM, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ)
-- 2. Created nonclustered index on CHAIN_ID for partition elimination performance
-- 3. REVERSE index removed (not applicable in Azure SQL)
-- 4. Compression applied (ROW for operational data)
-- 5. No FK constraints present
-- 6. Post-migration: Consider RANGE partitioning by ID for large dataset
-- ============================================================================

CREATE TABLE [EPS].[INTAKE_SOURCES] (
    [ID] BIGINT,
    [CHAIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [SOURCE_TYPE] VARCHAR(50),
    [SOURCE_FILE_NAME] VARCHAR(255),
    [SOURCE_EXECUTION_TIME] DATETIME2(6),
    [ACTION_TYPE] VARCHAR(50),
    [ID_AAL] BIGINT,
    [LAST_UPDATED] DATETIME2(6),
    CONSTRAINT [PK_INTAKE_SOURCES] PRIMARY KEY ([CHAIN_ID], [ID])
);
GO

-- Create indexes for query performance
CREATE NONCLUSTERED INDEX [IDX_INTAKE_SOURCES_CHAIN_ID]
    ON [EPS].[INTAKE_SOURCES]([CHAIN_ID])
    WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX [IDX_INTAKE_SOURCES_PATIENT_ID]
    ON [EPS].[INTAKE_SOURCES]([ID_PATIENT])
    WITH (FILLFACTOR = 90);
GO

-- Apply compression
ALTER TABLE [EPS].[INTAKE_SOURCES]
    WITH (DATA_COMPRESSION = ROW);
GO

-- Post-deployment actions:
-- 1. Verify data migration: SELECT COUNT(*) FROM [EPS].[INTAKE_SOURCES];
-- 2. Consider partitioning by SOURCE_EXECUTION_TIME (monthly RANGE) if table exceeds 1GB
-- 3. Update application connection strings to Azure SQL instance
-- 4. Run index maintenance: DBCC UPDATEUSAGE ([EPS].[INTAKE_SOURCES]);
