-- =====================================================================
-- CONVERTED: EPS.WC_CSD5570_DROPAFTER20181011
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 142

-- CSD MARKER: This is a Conflict-Sensitive Data archive variant (FUTURE DROP CANDIDATE)
-- DECISION: Variants preserved separately (no auto-consolidation to main table)
-- Archive Status: Marked for drop after 2018-10-11 (historical archive)
-- Variant Count: This is the 6th CSD variant detected across Batches 8-15

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[WC_CSD5570_DROPAFTER20181011]', 'U') IS NOT NULL
    DROP TABLE [EPS].[WC_CSD5570_DROPAFTER20181011]
GO

CREATE TABLE [EPS].[WC_CSD5570_DROPAFTER20181011] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [CLAIM_ID] BIGINT NULL,
    [WC_STATUS] VARCHAR(1) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    CONSTRAINT [WC_CSD5570_DROPAFTER20181011_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- NOTE: Archive/CSD table marked for future deletion (post 2018-10-11)
-- NOTE: Removed Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
-- CSD DECISION: Preserved separately (no consolidation)

CREATE NONCLUSTERED INDEX [IX_WC_CSD5570_CHAIN] ON [EPS].[WC_CSD5570_DROPAFTER20181011] ([CHAIN_ID]) GO
-- =====================================================================
