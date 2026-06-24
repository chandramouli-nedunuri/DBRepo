-- =====================================================================
-- CONVERTED: EPS.TX_LOT_AUDIT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_LOT_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_LOT_AUDIT]
GO

CREATE TABLE [EPS].[TX_LOT_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [LOT_NUMBER] VARCHAR(50) NULL,
    [EXPIRATION_DATE] DATETIME2(6) NULL,
    [QUANTITY] DECIMAL(10,2) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [TX_LOT_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_LOT_AUDIT_TS] ON [EPS].[TX_LOT_AUDIT] ([AUDIT_TIMESTAMP]) GO
-- =====================================================================
