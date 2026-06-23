-- =====================================================================
-- CONVERTED: EPS.PURGE_ERROR_LOG
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 100

-- Utility work queue table for error logging during purge operations

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PURGE_ERROR_LOG]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PURGE_ERROR_LOG]
GO

CREATE TABLE [EPS].[PURGE_ERROR_LOG] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ERROR_CODE] VARCHAR(10) NULL,
    [ERROR_MESSAGE] VARCHAR(MAX) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    CONSTRAINT [PURGE_ERROR_LOG_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: This is a utility/work queue table for purge operation logging
--       Typically purged after processing completes
--       No dependency relationships

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: Small utility table with minimal changes from Oracle
--       Size: 458 bytes (typical schema definition only)

-- Simple index for CHAIN_ID filtering:
CREATE NONCLUSTERED INDEX [IX_PURGE_ERROR_LOG_CHAIN]
ON [EPS].[PURGE_ERROR_LOG] ([CHAIN_ID], [CREATED_DATE])
GO

-- =====================================================================
