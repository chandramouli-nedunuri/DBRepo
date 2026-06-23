-- =====================================================================
-- CONVERTED: EPS.PATIENT_UNMERGE_LOCK
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 91

-- Master table for patient unmerge lock management

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PATIENT_UNMERGE_LOCK]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PATIENT_UNMERGE_LOCK]
GO

CREATE TABLE [EPS].[PATIENT_UNMERGE_LOCK] (
    [CHAIN_ID] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [LAST_UPDATED] DATETIME NULL,
    [ID_AAL] BIGINT NOT NULL,
    CONSTRAINT [PAT_UNMERGE_LOCK_FK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]),
    CONSTRAINT [PATIENT_UNMERGE_FK_ESCHAIN] FOREIGN KEY ([CHAIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID]),
    CONSTRAINT [PATIENT_UNMERGE_FK_ESSTORE] FOREIGN KEY ([CHAIN_ID], [NHIN_ID])
        REFERENCES [SEC_ADMIN].[EPS_SEC_STORE] ([CHAIN_NHIN_ID], [STORE_NHIN_ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       ~22 LIST partitions removed (ECOM, GEAGLE, HANNAF, MEIJER, RXCOM, SHOPKO, STLUKE, FREDS, GUNDER, WEBSCR, DUMMY, MEDSHP, ACMEHQ, SPRVAL, KMART, WEIS, SAFEWAY, SAVMRT, UNITEDS, DAHLS, FRUTH, WINNDIXIE, etc.)
--       Non-partitioned table in Azure SQL

-- NOTE: Use Change Data Capture (CDC) or Change Tracking as replacement
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE INITIALLY DEFERRED FK constraints in Oracle
--       Converted to standard FK constraints (Azure doesn't support DEFERRED mode)
--       Post-migration: Validate that all foreign key relationships can be satisfied
--       If required, implement application-level deferral logic during data load

-- Index for CHAIN_ID filtering and locks:
CREATE NONCLUSTERED INDEX [IX_PATIENT_UNMERGE_LOCK_CHAIN_PATIENT]
ON [EPS].[PATIENT_UNMERGE_LOCK] ([CHAIN_ID], [ID_PATIENT])
GO

-- =====================================================================
