-- =====================================================================
-- CONVERTED: EPS.TX_TP_AUDIT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_TP_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_TP_AUDIT]
GO

CREATE TABLE [EPS].[TX_TP_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [TP_ID] BIGINT NULL,
    [AMOUNT] DECIMAL(12,2) NULL,
    [STATUS] VARCHAR(1) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [TX_TP_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_TP_AUDIT_TS] ON [EPS].[TX_TP_AUDIT] ([AUDIT_TIMESTAMP]) GO
-- =====================================================================
