-- =====================================================================
-- CONVERTED: EPS.WORK_WINN_DIXIE
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[WORK_WINN_DIXIE]', 'U') IS NOT NULL
    DROP TABLE [EPS].[WORK_WINN_DIXIE]
GO

CREATE TABLE [EPS].[WORK_WINN_DIXIE] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [RECORD_TYPE] VARCHAR(20) NULL,
    [PROCESSED_DATE] DATETIME2(6) NULL,
    CONSTRAINT [WORK_WINN_DIXIE_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_WORK_WINN_DIXIE_DATE] ON [EPS].[WORK_WINN_DIXIE] ([PROCESSED_DATE]) GO
-- =====================================================================
