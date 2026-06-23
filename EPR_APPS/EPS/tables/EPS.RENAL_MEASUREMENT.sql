-- =====================================================================
-- CONVERTED: EPS.RENAL_MEASUREMENT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 12, File 110

-- Master table for renal measurement records

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RENAL_MEASUREMENT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RENAL_MEASUREMENT]
GO

CREATE TABLE [EPS].[RENAL_MEASUREMENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [MEASUREMENT_DATE] DATETIME2(6) NOT NULL,
    [MEASUREMENT_TYPE] VARCHAR(50) NOT NULL,
    [MEASUREMENT_VALUE] DECIMAL(12,4) NOT NULL,
    [UNIT_OF_MEASURE] VARCHAR(20) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    CONSTRAINT [RENAL_MEASUREMENT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [RENAL_MEASUREMENT_FK_PATIENT] FOREIGN KEY ([CHAIN_ID])
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
CREATE NONCLUSTERED INDEX [IX_RENAL_MEASUREMENT_PATIENT]
ON [EPS].[RENAL_MEASUREMENT] ([ID_PATIENT], [MEASUREMENT_DATE])
GO

CREATE NONCLUSTERED INDEX [IX_RENAL_MEASUREMENT_DATE]
ON [EPS].[RENAL_MEASUREMENT] ([MEASUREMENT_DATE])
GO

-- =====================================================================
