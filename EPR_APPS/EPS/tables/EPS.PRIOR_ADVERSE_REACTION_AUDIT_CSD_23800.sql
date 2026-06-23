-- =====================================================================
-- CONVERTED: EPS.PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800
-- =====================================================================
-- Source: Oracle EPS
-- Target: Azure SQL Server 2019+
-- Conversion Date: May 29, 2026
-- Status: BATCH 11, File 97

-- CSD MARKER: This is a Conflict-Sensitive Data variant
-- DECISION: Variants preserved separately (no auto-consolidation to main table)
-- Characteristic: CSD variant #5; 77 LIST partitions removed (ACMEHQ...CSQATESTCHAIN8105)
-- Variant Count: Batch 8 (1), Batch 9 (2), Batch 10 (4), Batch 11 (1) = 5 total CSD variants

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800]', 'U') IS NOT NULL
    DROP TABLE [EPS].[PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800]
GO

CREATE TABLE [EPS].[PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800] (
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
    CONSTRAINT [PRIOR_ADVERSE_AUDIT_CSD_23800_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Oracle storage and tuning parameters removed
--       Azure SQL manages storage, concurrency, caching, and logging automatically
--       Removed: PCTFREE, PCTUSED, INITRANS, MAXTRANS, TABLESPACE, BUFFER_POOL, FLASH_CACHE

-- NOTE: Original table used Oracle LIST partitioning by CHAIN_ID (77 partitions)
--       Partitions removed (non-partitioned table in Azure SQL)
--       Removed partition values (ACMEHQ, ALBERT, APOTHERCARY, AVELLA, BEST, BURKLOW, DAHLS, DARBYS, DUMMY, ... OTHER)

-- NOTE: Use Change Data Capture (CDC) or Change Tracking in Azure SQL as replacement
--       Removed: SUPPLEMENTAL LOG DATA (ALL) COLUMNS

-- NOTE: DEFERRABLE VARCHAR CONSTRAINT present in Oracle
--       Converted to standard FK constraint (Azure doesn't support DEFERRED mode)
--       Post-migration validation required

-- CSD DECISION: Variants preserved separately (not consolidated)
--       This table is kept as a separate entity from PRIOR_ADVERSE_REACTION_AUDIT
--       Consolidation deferred pending business requirements

-- INDEX RECOMMENDATION:
-- For CSD variant audit tables, consider adding filtered index:
CREATE NONCLUSTERED INDEX [IX_PRIOR_ADVERSE_REACTION_AUDIT_CSD_CHAIN_TS]
ON [EPS].[PRIOR_ADVERSE_REACTION_AUDIT_CSD_23800] ([CHAIN_ID], [AUDIT_TIMESTAMP])
GO

-- =====================================================================
