-- =====================================================================
-- CONVERTED: EPS.VIAL_INFO
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[VIAL_INFO]', 'U') IS NOT NULL
    DROP TABLE [EPS].[VIAL_INFO]
GO

CREATE TABLE [EPS].[VIAL_INFO] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [VIAL_ID] BIGINT NOT NULL,
    [VIAL_STATUS] VARCHAR(1) NULL,
    [CREATED_DATE] DATETIME2(6) NULL,
    [LAST_UPDATED] DATETIME2(6) NULL,
    CONSTRAINT [VIAL_INFO_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [VIAL_INFO_FK_CHAIN] FOREIGN KEY ([CHAIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_VIAL_INFO_CHAIN] ON [EPS].[VIAL_INFO] ([CHAIN_ID]) GO
-- =====================================================================
