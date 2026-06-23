-- =====================================================================
-- CONVERTED: EPS.PRESCRIBER_AUDIT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 95

-- Audit trail for prescriber records

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PRESCRIBER_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PRESCRIBER_AUDIT]
GO

CREATE TABLE [EPS].[PRESCRIBER_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [PRESCRIBER_NUMBER] VARCHAR(20) NULL,
    [FIRST_NAME] VARCHAR(100) NULL,
    [LAST_NAME] VARCHAR(100) NULL,
    [SPECIALTY] VARCHAR(50) NULL,
    [PHONE] VARCHAR(20) NULL,
    [STATUS] VARCHAR(1) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PRESCRIBER_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- RECOMMENDATION: For large audit tables, consider:
-- - Partitioning by AUDIT_TIMESTAMP (RANGE)
-- - Clustered index on (AUDIT_TIMESTAMP, ID)

-- Index for filtering:
CREATE NONCLUSTERED INDEX [IX_PRESCRIBER_AUDIT_CHAIN_TS]
ON [EPS].[PRESCRIBER_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
GO

-- =====================================================================
