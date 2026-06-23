-- =====================================================================
-- CONVERTED: EPS.QUEUECOMMAND
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 108

-- Queue/Messaging table for asynchronous command processing

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[QUEUECOMMAND]', 'U') IS NOT NULL
    DROP TABLE [EPS].[QUEUECOMMAND]
GO

CREATE TABLE [EPS].[QUEUECOMMAND] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [COMMAND_TYPE] VARCHAR(50) NOT NULL,
    [COMMAND_DATA] VARCHAR(MAX) NULL,
    [PRIORITY] INT NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [PROCESSED_DATE] DATETIME2(6) NULL,
    [STATUS] VARCHAR(20) NULL,
    [ERROR_MESSAGE] VARCHAR(MAX) NULL,
    CONSTRAINT [QUEUECOMMAND_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- INDEX RECOMMENDATION:
-- For queue processing performance:
CREATE NONCLUSTERED INDEX [IX_QUEUECOMMAND_STATUS]
ON [EPS].[QUEUECOMMAND] ([STATUS], [PRIORITY])
GO

CREATE NONCLUSTERED INDEX [IX_QUEUECOMMAND_CREATED]
ON [EPS].[QUEUECOMMAND] ([CREATED_DATE])
GO

-- =====================================================================
