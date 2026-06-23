-- =====================================================================
-- CONVERTED: EPS.PURGE_RECORDS
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 106

-- Work queue table for records pending purge

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_RECORDS]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_RECORDS]
GO

CREATE TABLE [EPS].[PURGE_RECORDS] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TABLE_NAME] VARCHAR(100) NOT NULL,
    [RECORD_ID] BIGINT NULL,
    [PURGE_DATE] DATETIME2(6) NULL,
    [STATUS] VARCHAR(20) NULL,
    CONSTRAINT [PURGE_RECORDS_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)
--       Typically purged after processing completes

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for work queue filtering:
CREATE NONCLUSTERED INDEX [IX_PURGE_RECORDS_STATUS]
ON [EPS].[PURGE_RECORDS] ([STATUS])
GO

-- =====================================================================
