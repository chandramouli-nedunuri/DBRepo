-- =====================================================================
-- CONVERTED: EPS.VIAL_INFO_AUDIT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[VIAL_INFO_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[VIAL_INFO_AUDIT]
GO

CREATE TABLE [EPS].[VIAL_INFO_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [VIAL_ID] BIGINT NULL,
    [VIAL_STATUS] VARCHAR(1) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [VIAL_INFO_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_VIAL_INFO_AUDIT_TS] ON [EPS].[VIAL_INFO_AUDIT] ([AUDIT_TIMESTAMP]) GO
-- =====================================================================
