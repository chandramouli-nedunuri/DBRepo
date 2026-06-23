-- =====================================================================
-- CONVERTED: EPS.TX_CRED_AUDIT
-- =====================================================================
-- Source: Oracle EPS | Target: Azure SQL | Date: May 29, 2026

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[EPS].[TX_CRED_AUDIT]', 'U') IS NOT NULL
    DROP TABLE [EPS].[TX_CRED_AUDIT]
GO

CREATE TABLE [EPS].[TX_CRED_AUDIT] (
    [CHAIN_ID] BIGINT NOT NULL,
    [ID] BIGINT NOT NULL,
    [CRED_AMOUNT] DECIMAL(12,2) NULL,
    [REASON_CODE] VARCHAR(10) NULL,
    [CREATEDDATE] DATETIME2(6) NULL,
    [AUDIT_TIMESTAMP] DATETIME2(6) NOT NULL,
    CONSTRAINT [TX_CRED_AUDIT_PK] PRIMARY KEY CLUSTERED ([CHAIN_ID], [ID])
)
GO

-- Removed: Oracle storage params, LIST partitioning, SUPPLEMENTAL LOG
CREATE NONCLUSTERED INDEX [IX_TX_CRED_AUDIT_TS] ON [EPS].[TX_CRED_AUDIT] ([AUDIT_TIMESTAMP]) GO
-- =====================================================================
