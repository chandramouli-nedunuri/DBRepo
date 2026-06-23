-- =====================================================================
-- CONVERTED: EPS.PAYMENT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 94

-- Master transaction table for payments

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PAYMENT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PAYMENT]
GO

CREATE TABLE [EPS].[PAYMENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [PAYMENT_DATE] DATETIME2(6) NOT NULL,
    [PAYMENT_METHOD] VARCHAR(20) NULL,
    [AMOUNT] DECIMAL(12,2) NOT NULL,
    [STATUS] VARCHAR(1) NULL,
    [REFERENCE_CODE] VARCHAR(50) NULL,
    [POSTED_DATE] DATETIME2(6) NULL,
    [POSTED_BY] VARCHAR(20) NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PAYMENT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [PAYMENT_FK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [PAYMENT_FK_CHAIN] FOREIGN KEY ([CHAIN_ID])
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
CREATE NONCLUSTERED INDEX [IX_PAYMENT_CHAIN_PATIENT]
ON [EPS].[PAYMENT] ([CHAIN_ID], [ID_PATIENT])
GO

CREATE NONCLUSTERED INDEX [IX_PAYMENT_DATE]
ON [EPS].[PAYMENT] ([PAYMENT_DATE])
GO

-- =====================================================================
