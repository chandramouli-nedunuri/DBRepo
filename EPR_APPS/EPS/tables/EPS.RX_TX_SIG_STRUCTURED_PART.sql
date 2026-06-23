-- =====================================================================
-- CONVERTED: EPS.RX_TX_SIG_STRUCTURED_PART
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 119

-- Master table for structured prescription signature parts

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RX_TX_SIG_STRUCTURED_PART]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RX_TX_SIG_STRUCTURED_PART]
GO

CREATE TABLE [EPS].[RX_TX_SIG_STRUCTURED_PART] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [PART_SEQUENCE] BIGINT NULL,
    [PART_TYPE] VARCHAR(50) NULL,
    [PART_VALUE] VARCHAR(MAX) NULL,
    [UNIT_CODE] VARCHAR(20) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    CONSTRAINT [RX_TX_SIG_STRUCTURED_PART_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [RX_TX_SIG_STRUCTURED_PART_FK_RX_TX] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: PART_VALUE uses VARCHAR(MAX) for structured instruction data
--       Converted from Oracle CLOB/VARCHAR2
--       Size consideration: Monitor column if instructions exceed 8KB per row

-- INDEX RECOMMENDATION:
CREATE NONCLUSTERED INDEX [IX_RX_TX_SIG_STRUCTURED_PART_RX_TX]
ON [EPS].[RX_TX_SIG_STRUCTURED_PART] ([CHAIN_ID], [ID_RX_TX], [PART_SEQUENCE])
GO

-- =====================================================================
