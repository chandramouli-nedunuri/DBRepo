-- =====================================================================
-- CONVERTED: EPS.TX_LOT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_LOT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_LOT]
GO

CREATE TABLE [EPS].[TX_LOT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [LOT_NUMBER] VARCHAR(50) NOT NULL,
    [EXPIRATION_DATE] DATETIME2(6) NOT NULL,
    [QUANTITY] DECIMAL(10,2) NOT NULL,
    CONSTRAINT [TX_LOT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [TX_LOT_FK_CHAIN] FOREIGN KEY ([CHAIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_LOT_CHAIN] ON [EPS].[TX_LOT] ([CHAIN_ID]) GO
-- =====================================================================
