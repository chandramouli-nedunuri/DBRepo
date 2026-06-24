-- =====================================================================
-- CONVERTED: EPS.PURGE_FLOW_MAP_CR15426
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 101

-- Utility table for purge flow mapping (CR15426 variant)

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_FLOW_MAP_CR15426]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_FLOW_MAP_CR15426]
GO

CREATE TABLE [EPS].[PURGE_FLOW_MAP_CR15426] (
    [CHAIN_ID] BIGINT NOT NULL,
    [FLOW_ID] BIGINT NOT NULL,
    [FLOW_NAME] VARCHAR(100) NULL,
    [DESCRIPTION] VARCHAR(500) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [UPDATED_DATE] DATETIME2(6) NULL,
    CONSTRAINT [PURGE_FLOW_MAP_CR15426_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [FLOW_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for utility table:
CREATE NONCLUSTERED INDEX [IX_PURGE_FLOW_MAP_CR15426_CHAIN]
ON [EPS].[PURGE_FLOW_MAP_CR15426] ([CHAIN_ID])
GO

-- =====================================================================
