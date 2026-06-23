-- =====================================================================
-- CONVERTED: EPS.TX_CRED
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_CRED]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_CRED]
GO

CREATE TABLE [EPS].[TX_CRED] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [CRED_AMOUNT] DECIMAL(12,2) NOT NULL,
    [REASON_CODE] VARCHAR(10) NOT NULL,
    [CREATEDDATE] DATETIME2(6) NULL,
    CONSTRAINT [TX_CRED_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID]),
    CONSTRAINT [TX_CRED_FK_CHAIN] FOREIGN KEY ([CHAIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_CRED_CHAIN] ON [EPS].[TX_CRED] ([CHAIN_ID]) GO
-- =====================================================================
