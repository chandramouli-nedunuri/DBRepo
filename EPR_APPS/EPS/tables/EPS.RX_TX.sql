-- =====================================================================
-- CONVERTED: EPS.RX_TX
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 13, File 120

-- CORE MASTER TABLE FOR PRESCRIPTION TRANSACTIONS
-- Central repository for all prescription transaction records (fills, refills, voids)

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[RX_TX]', 'U') IS NOT NULL
    DROP TABLE [EPS].[RX_TX]
GO

CREATE TABLE [EPS].[RX_TX] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PRESCRIPTION] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [ID_PRESCRIBER] BIGINT NULL,
    [NHIN_ID] BIGINT NULL,
    [TRANSACTION_DATE] DATETIME2(6) NOT NULL,
    [TRANSACTION_TYPE] VARCHAR(1) NULL,
    [RX_AMOUNT] DECIMAL(10,2) NULL,
    [RX_QUANTITY] DECIMAL(10,2) NULL,
    [DAYS_SUPPLY] INT NULL,
    [STATUS] VARCHAR(1) NULL,
    [VOID_DATE] DATETIME2(6) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [RX_TX_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [RX_TX_FK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [RX_TX_FK_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions likely extensive (50+ partitions) - all removed
--       Non-partitioned table in Azure SQL

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE INITIALLY DEFERRED FK constraints in Oracle
--       Converted to standard FK constraints (Azure doesn't support DEFERRED mode)
--       Post-migration: Validate FK relationships, particularly to PATIENT and PRESCRIBER

-- CRITICAL: This is core prescription transaction master table
-- Heavy usage expected; validate performance post-migration
-- Consider RANGE partitioning by TRANSACTION_DATE in post-migration phase

-- INDEX RECOMMENDATIONS:
-- These indexes are critical for prescription lookup performance:
CREATE NONCLUSTERED INDEX [IX_RX_TX_PATIENT]
ON [EPS].[RX_TX] ([CHAIN_ID], [ID_PATIENT])
GO

CREATE NONCLUSTERED INDEX [IX_RX_TX_DATE]
ON [EPS].[RX_TX] ([TRANSACTION_DATE])
GO

CREATE NONCLUSTERED INDEX [IX_RX_TX_PRESCRIPTION]
ON [EPS].[RX_TX] ([CHAIN_ID], [ID_PRESCRIPTION])
GO

CREATE NONCLUSTERED INDEX [IX_RX_TX_STATUS]
ON [EPS].[RX_TX] ([STATUS])
GO

-- =====================================================================
