-- =====================================================================
-- CONVERTED: EPS.PRIOR_ADVERSE_REACTION_AUDIT
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 98

-- Standard audit table (paired with CSD variant EPS.PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800)
-- These tables are NOT consolidated; CSD variant preserved separately

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PRIOR_ADVERSE_REACTION_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PRIOR_ADVERSE_REACTION_AUDIT]
GO

CREATE TABLE [EPS].[PRIOR_ADVERSE_REACTION_AUDIT] (
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
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    [ID_AAL] BIGINT NULL,
    CONSTRAINT [PRIOR_ADVERSE_REACTION_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID
--       Partitions removed (non-partitioned table in Azure SQL)
--       Recommend RANGE partitioning by AUDIT_TIMESTAMP post-migration for large audit tables

-- NOTE: Use Change Data Capture (CDC) or Change Tracking in Azure SQL
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: Paired with CSD variant EPS.PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800
--       Standard audit with mandatory AUDIT_TIMESTAMP
--       CSD variant has same structure but preserved separately

-- INDEX RECOMMENDATION:
-- For large audit tables, consider RANGE partitioning by AUDIT_TIMESTAMP:
CREATE NONCLUSTERED INDEX [IX_PRIOR_ADVERSE_REACTION_AUDIT_CHAIN_TS]
ON [EPS].[PRIOR_ADVERSE_REACTION_AUDIT] ([CHAIN_ID], [AUDIT_TIMESTAMP])
GO

-- =====================================================================
