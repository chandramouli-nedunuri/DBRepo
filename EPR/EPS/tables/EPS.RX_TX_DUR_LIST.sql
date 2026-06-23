-- =====================================================================
-- CONVERTED: EPS.RX_TX_DUR_LIST
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 116

-- Master table for drug utilization review (DUR) list entries

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RX_TX_DUR_LIST]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RX_TX_DUR_LIST]
GO

CREATE TABLE [EPS].[RX_TX_DUR_LIST] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [DUR_CODE] VARCHAR(20) NOT NULL,
    [DUR_DESCRIPTION] VARCHAR(200) NULL,
    [SEVERITY] VARCHAR(10) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    CONSTRAINT [RX_TX_DUR_LIST_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [RX_TX_DUR_LIST_FK_RX_TX] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- INDEX RECOMMENDATION:
CREATE NONCLUSTERED INDEX [IX_RX_TX_DUR_LIST_CHAIN]
ON [EPS].[RX_TX_DUR_LIST] ([CHAIN_ID], [ID_RX_TX])
GO

-- =====================================================================
