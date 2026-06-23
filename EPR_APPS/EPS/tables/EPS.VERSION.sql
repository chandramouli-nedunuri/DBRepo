-- =====================================================================
-- CONVERTED: EPS.VERSION
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[VERSION]', 'U') IS NOT NULL
    DROP TABLE [EPS].[VERSION]
GO

CREATE TABLE [EPS].[VERSION] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [VERSION_NUMBER] VARCHAR(20) NULL,
    [RELEASE_DATE] DATETIME2(6) NULL,
    CONSTRAINT [VERSION_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning
CREATE NONCLUSTERED INDEX [IX_VERSION_CHAIN] ON [EPS].[VERSION] ([CHAIN_ID]) GO
-- =====================================================================
