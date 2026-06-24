-- =====================================================================
-- CONVERTED: EPS.PRESCRIBER
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 96

-- Master registry for prescriber information

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PRESCRIBER]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PRESCRIBER]
GO

CREATE TABLE [EPS].[PRESCRIBER] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [PRESCRIBER_NUMBER] VARCHAR(20) NOT NULL,
    [FIRST_NAME] VARCHAR(100) NULL,
    [LAST_NAME] VARCHAR(100) NOT NULL,
    [SPECIALTY] VARCHAR(50) NULL,
    [PHONE] VARCHAR(20) NULL,
    [FAX] VARCHAR(20) NULL,
    [EMAIL] VARCHAR(100) NULL,
    [STATUS] VARCHAR(1) NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PRESCRIBER_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [PRESCRIBER_FK_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE INITIALLY DEFERRED FK constraints converted to standard FK
--       Azure doesn't support DEFERRED mode
--       Post-migration: Validate FK relationships

-- Index recommendations:
CREATE NONCLUSTERED INDEX [IX_PRESCRIBER_CHAIN_NUMBER]
ON [EPS].[PRESCRIBER] ([CHAIN_ID], [PRESCRIBER_NUMBER])
GO

CREATE NONCLUSTERED INDEX [IX_PRESCRIBER_NAME]
ON [EPS].[PRESCRIBER] ([LAST_NAME], [FIRST_NAME])
GO

-- =====================================================================
