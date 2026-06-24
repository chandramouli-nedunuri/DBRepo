-- =====================================================================
-- CONVERTED: EPS.PURGE_RUN_DETAILS
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 107

-- Metrics and details table for purge run operations

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_RUN_DETAILS]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_RUN_DETAILS]
GO

CREATE TABLE [EPS].[PURGE_RUN_DETAILS] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RUN_ID] BIGINT NULL,
    [STEP_NAME] VARCHAR(100) NULL,
    [STEP_SEQUENCE] BIGINT NULL,
    [START_TIME] DATETIME2(6) NULL,
    [END_TIME] DATETIME2(6) NULL,
    [DURATION_SECONDS] DECIMAL(10,2) NULL,
    [RECORDS_AFFECTED] BIGINT NULL,
    [STATUS] VARCHAR(20) NULL,
    CONSTRAINT [PURGE_RUN_DETAILS_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for metrics queries:
CREATE NONCLUSTERED INDEX [IX_PURGE_RUN_DETAILS_TIME]
ON [EPS].[PURGE_RUN_DETAILS] ([START_TIME])
GO

-- =====================================================================
