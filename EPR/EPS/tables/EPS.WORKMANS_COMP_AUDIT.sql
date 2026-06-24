-- =====================================================================
-- CONVERTED: EPS.WORKMANS_COMP_AUDIT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[WORKMANS_COMP_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[WORKMANS_COMP_AUDIT]
GO

CREATE TABLE [EPS].[WORKMANS_COMP_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [CLAIM_ID] BIGINT NULL,
    [AMOUNT] DECIMAL(12,2) NULL,
    [STATUS] VARCHAR(1) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [WORKMANS_COMP_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_WORKMANS_COMP_AUDIT_TS] ON [EPS].[WORKMANS_COMP_AUDIT] ([AUDIT_TIMESTAMP]) GO
-- =====================================================================
