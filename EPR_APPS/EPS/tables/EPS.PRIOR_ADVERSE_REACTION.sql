-- =====================================================================
-- CONVERTED: EPS.PRIOR_ADVERSE_REACTION
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 99

-- Master registry table for adverse reactions

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PRIOR_ADVERSE_REACTION]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PRIOR_ADVERSE_REACTION]
GO

CREATE TABLE [EPS].[PRIOR_ADVERSE_REACTION] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [ID_PATIENT] BIGINT NOT NULL,
    [NHIN_ID] BIGINT NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    [CLASS_NUMBER] DECIMAL(5,0) NULL,
    [KDC5] DECIMAL(5,0) NULL,
    [RASH] VARCHAR(1) NULL,
    [SHOCK] VARCHAR(1) NULL,
    [BREATH] VARCHAR(1) NULL,
    [GI_TRACT] VARCHAR(1) NULL,
    [BLOOD] VARCHAR(1) NULL,
    [UNSPEC] VARCHAR(1) NULL,
    [START_DATE] DATETIME2(6) NULL,
    [ADDED] DATETIME2(6) NULL,
    [REPORT_BY] VARCHAR(2) NULL,
    [DELETED] VARCHAR(1) NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PRIOR_ADVERSE_REACTION_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [PRIOR_ADVERSE_REACTION_FK_PATIENT] FOREIGN KEY ([CHAIN_ID], [ID_PATIENT])
        REFERENCES [EPS].[PATIENT] ([CHAIN_ID], [ID]) ON DELETE NO ACTION ON UPDATE NO ACTION
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned in Azure SQL)
--       Future redesign recommended using RANGE partition on AUDIT_TIMESTAMP if audit table grows

-- NOTE: Use Change Data Capture (CDC) or Change Tracking as replacement
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE INITIALLY DEFERRED FK constraint in Oracle
--       Converted to standard FK (Azure doesn't support DEFERRED mode)
--       Post-migration: Validate that foreign key constraints can be satisfied
--       If needed, implement application-level deferral logic during data migration

-- INDEX RECOMMENDATION:
-- Consider adding index for CHAIN_ID filtering:
CREATE NONCLUSTERED INDEX [IX_PRIOR_ADVERSE_REACTION_CHAIN_PATIENT]
ON [EPS].[PRIOR_ADVERSE_REACTION] ([CHAIN_ID], [ID_PATIENT])
GO

-- =====================================================================
