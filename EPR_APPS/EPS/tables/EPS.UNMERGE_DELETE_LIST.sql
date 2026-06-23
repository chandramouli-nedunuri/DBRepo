-- =====================================================================
-- CONVERTED: EPS.UNMERGE_DELETE_LIST
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[UNMERGE_DELETE_LIST]', 'U') IS NOT NULL
    DROP TABLE [EPS].[UNMERGE_DELETE_LIST]
GO

CREATE TABLE [EPS].[UNMERGE_DELETE_LIST] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RECORD_ID] BIGINT NULL,
    [TABLE_NAME] VARCHAR(100) NULL,
    [DELETE_DATE] DATETIME2(6) NULL,
    CONSTRAINT [UNMERGE_DELETE_LIST_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_UNMERGE_DELETE_LIST_DATE] ON [EPS].[UNMERGE_DELETE_LIST] ([DELETE_DATE]) GO
-- =====================================================================
