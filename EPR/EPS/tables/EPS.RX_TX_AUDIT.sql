-- =====================================================================
-- CONVERTED: EPS.RX_TX_AUDIT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 112

-- Audit trail for prescription transaction records

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RX_TX_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RX_TX_AUDIT]
GO

CREATE TABLE [EPS].[RX_TX_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [ID_PRESCRIPTION] BIGINT NULL,
    [RX_AMOUNT] DECIMAL(10,2) NULL,
    [RX_STATUS] VARCHAR(1) NULL,
    [VOID_DATE] DATETIME2(6) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [RX_TX_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- INDEX RECOMMENDATION:
-- For large RX audit tables, consider RANGE partitioning by AUDIT_TIMESTAMP:
CREATE NONCLUSTERED INDEX [IX_RX_TX_AUDIT_CHAIN_TS]
ON [EPS].[RX_TX_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
GO

-- =====================================================================
