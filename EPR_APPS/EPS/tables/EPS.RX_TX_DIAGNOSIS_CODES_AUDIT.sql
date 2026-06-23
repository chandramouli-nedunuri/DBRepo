-- =====================================================================
-- CONVERTED: EPS.RX_TX_DIAGNOSIS_CODES_AUDIT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 113

-- Audit trail for prescription diagnosis codes

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RX_TX_DIAGNOSIS_CODES_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RX_TX_DIAGNOSIS_CODES_AUDIT]
GO

CREATE TABLE [EPS].[RX_TX_DIAGNOSIS_CODES_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_RX_TX] BIGINT NOT NULL,
    [DIAGNOSIS_CODE] VARCHAR(20) NULL,
    [DIAGNOSIS_DESC] VARCHAR(200) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [RX_TX_DIAGNOSIS_CODES_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- INDEX RECOMMENDATION:
CREATE NONCLUSTERED INDEX [IX_RX_TX_DIAGNOSIS_CODES_AUDIT_TS]
ON [EPS].[RX_TX_DIAGNOSIS_CODES_AUDIT] ([AUDIT_TIMESTAMP])
GO

-- =====================================================================
