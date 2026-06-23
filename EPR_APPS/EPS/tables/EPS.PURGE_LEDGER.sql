-- =====================================================================
-- CONVERTED: EPS.PURGE_LEDGER
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 105

-- Ledger table for purge operation tracking

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_LEDGER]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_LEDGER]
GO

CREATE TABLE [EPS].[PURGE_LEDGER] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TABLE_NAME] VARCHAR(100) NOT NULL,
    [RECORDS_DELETED] BIGINT NULL,
    [RECORDS_KEPT] BIGINT NULL,
    [PURGE_DATE] DATETIME2(6) NULL,
    [EXECUTED_BY] VARCHAR(50) NULL,
    CONSTRAINT [PURGE_LEDGER_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- Index for ledger queries:
CREATE NONCLUSTERED INDEX [IX_PURGE_LEDGER_DATE]
ON [EPS].[PURGE_LEDGER] ([PURGE_DATE])
GO

-- =====================================================================
