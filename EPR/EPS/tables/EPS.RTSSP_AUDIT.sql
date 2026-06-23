-- =====================================================================
-- CONVERTED: EPS.RTSSP_AUDIT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 111

-- Audit trail for real-time structured signature provider records

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RTSSP_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RTSSP_AUDIT]
GO

CREATE TABLE [EPS].[RTSSP_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [PROVIDER_ID] BIGINT NOT NULL,
    [PROVIDER_NAME] VARCHAR(200) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [RTSSP_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- INDEX RECOMMENDATION:
CREATE NONCLUSTERED INDEX [IX_RTSSP_AUDIT_CHAIN_TS]
ON [EPS].[RTSSP_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
GO

-- =====================================================================
