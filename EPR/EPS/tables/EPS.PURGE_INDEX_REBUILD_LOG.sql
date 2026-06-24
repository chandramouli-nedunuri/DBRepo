-- =====================================================================
-- CONVERTED: EPS.PURGE_INDEX_REBUILD_LOG
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 104

-- Work log table for index rebuild operations

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_INDEX_REBUILD_LOG]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_INDEX_REBUILD_LOG]
GO

CREATE TABLE [EPS].[PURGE_INDEX_REBUILD_LOG] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TABLE_NAME] VARCHAR(100) NULL,
    [INDEX_NAME] VARCHAR(100) NULL,
    [REBUILD_DATE] DATETIME2(6) NULL,
    [STATUS] VARCHAR(20) NULL,
    [DURATION_MINUTES] DECIMAL(10,2) NULL,
    CONSTRAINT [PURGE_INDEX_REBUILD_LOG_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for work log:
CREATE NONCLUSTERED INDEX [IX_PURGE_INDEX_REBUILD_LOG_DATE]
ON [EPS].[PURGE_INDEX_REBUILD_LOG] ([REBUILD_DATE])
GO

-- =====================================================================
