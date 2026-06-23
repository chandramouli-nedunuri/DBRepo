-- =====================================================================
-- CONVERTED: EPS.PATIENT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 92

-- CORE MASTER TABLE FOR PATIENT RECORD
-- Central repository for all patient demographic and status information

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PATIENT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PATIENT]
GO

CREATE TABLE [EPS].[PATIENT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [MRN] VARCHAR(20) NULL,
    [NHIN_ID] BIGINT NULL,
    [FIRST_NAME] VARCHAR(100) NOT NULL,
    [LAST_NAME] VARCHAR(100) NOT NULL,
    [MIDDLE_NAME] VARCHAR(100) NULL,
    [DATE_OF_BIRTH] DATETIME NULL,
    [GENDER] VARCHAR(1) NULL,
    [PHONE] VARCHAR(20) NULL,
    [EMAIL] VARCHAR(100) NULL,
    [STATUS] VARCHAR(1) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PATIENT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [PATIENT_FK_CHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)
--       Future: Consider RANGE partitioning by CREATED_DATE or similar if table grows significantly

-- NOTE: Use Change Data Capture (CDC) or Change Tracking
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE INITIALLY DEFERRED FK constraints converted to standard FK
--       Azure doesn't support DEFERRED mode
--       Post-migration: Validate FK relationships
--       This is the core patient master; validate all referential integrity

-- CRITICAL: This table is referenced by many other tables
-- Dependencies: PATIENT_UNMERGE_LOCK, PAYMENT, PRESCRIBER, PRIOR_ADVERSE_REACTION, and all PATIENT_* tables
-- Ensure referential integrity during migration

-- Index recommendations for core master table:
CREATE NONCLUSTERED INDEX [IX_PATIENT_MRN]
ON [EPS].[PATIENT] ([MRN])
GO

CREATE NONCLUSTERED INDEX [IX_PATIENT_NAME]
ON [EPS].[PATIENT] ([LAST_NAME], [FIRST_NAME])
GO

CREATE NONCLUSTERED INDEX [IX_PATIENT_CHAIN_DOB]
ON [EPS].[PATIENT] ([CHAIN_ID], [DATE_OF_BIRTH])
GO

-- =====================================================================
