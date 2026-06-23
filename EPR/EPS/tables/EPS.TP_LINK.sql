-- =====================================================================
-- CONVERTED: EPS.TP_LINK
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TP_LINK]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TP_LINK]
GO

CREATE TABLE [EPS].[TP_LINK] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TP_ID] BIGINT NULL,
    [LINK_DATE] DATETIME2(6) NULL,
    [STATUS] VARCHAR(1) NULL,
    CONSTRAINT [TP_LINK_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TP_LINK_CHAIN] ON [EPS].[TP_LINK] ([CHAIN_ID]) GO
-- =====================================================================
