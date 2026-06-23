-- =====================================================================
-- CONVERTED: EPS.WORKMANS_COMP
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[WORKMANS_COMP]', 'U') IS NOT NULL
    DROP TABLE [EPS].[WORKMANS_COMP]
GO

CREATE TABLE [EPS].[WORKMANS_COMP] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [CLAIM_ID] BIGINT NOT NULL,
    [AMOUNT] DECIMAL(12,2) NOT NULL,
    [STATUS] VARCHAR(1) NULL,
    CONSTRAINT [WORKMANS_COMP_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [WORKMANS_COMP_FK_CHAIN] FOREIGN KEY ([CHAIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_WORKMANS_COMP_CHAIN] ON [EPS].[WORKMANS_COMP] ([CHAIN_ID]) GO
-- =====================================================================
