-- =====================================================================
-- CONVERTED: EPS.TX_TP
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_TP]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_TP]
GO

CREATE TABLE [EPS].[TX_TP] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TP_ID] BIGINT NOT NULL,
    [AMOUNT] DECIMAL(12,2) NOT NULL,
    [STATUS] VARCHAR(1) NULL,
    CONSTRAINT [TX_TP_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [TX_TP_FK_CHAIN] FOREIGN KEY ([CHAIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_TP_CHAIN] ON [EPS].[TX_TP] ([CHAIN_ID]) GO
-- =====================================================================
