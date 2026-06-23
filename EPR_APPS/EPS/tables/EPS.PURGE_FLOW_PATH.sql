-- =====================================================================
-- CONVERTED: EPS.PURGE_FLOW_PATH
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 103

-- Utility table for purge flow path definitions

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_FLOW_PATH]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_FLOW_PATH]
GO

CREATE TABLE [EPS].[PURGE_FLOW_PATH] (
    [CHAIN_ID] BIGINT NOT NULL,
    [PATH_ID] BIGINT NOT NULL,
    [FLOW_ID] BIGINT NULL,
    [PATH_SEQUENCE] BIGINT NULL,
    [TABLE_NAME] VARCHAR(100) NULL,
    [DESCRIPTION] VARCHAR(500) NULL,
    CONSTRAINT [PURGE_FLOW_PATH_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [PATH_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for utility table:
CREATE NONCLUSTERED INDEX [IX_PURGE_FLOW_PATH_CHAIN]
ON [EPS].[PURGE_FLOW_PATH] ([CHAIN_ID])
GO

-- =====================================================================
