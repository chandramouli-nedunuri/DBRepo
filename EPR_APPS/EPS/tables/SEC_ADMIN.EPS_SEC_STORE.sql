-- =====================================================================
-- CONVERTED: SEC_ADMIN.EPS_SEC_STORE
-- =====================================================================
-- Source: Oracle SEC_ADMIN | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 149 | SYSTEM MASTER TABLE

-- System master table for store/location management
-- Referenced by many EPS transaction tables

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[SEC_ADMIN].[EPS_SEC_STORE]', 'U') IS NOT NULL
    DROP TABLE [SEC_ADMIN].[EPS_SEC_STORE]
GO

CREATE TABLE [SEC_ADMIN].[EPS_SEC_STORE] (
    [CHAIN_NHIN_ID] BIGINT NOT NULL,
    [STORE_NHIN_ID] BIGINT NOT NULL,
    [STORE_NUMBER] VARCHAR(20) NULL,
    [STORE_NAME] VARCHAR(100) NULL,
    [ADDRESS] VARCHAR(200) NULL,
    [CITY] VARCHAR(50) NULL,
    [STATE] VARCHAR(2) NULL,
    [ZIP_CODE] VARCHAR(10) NULL,
    CONSTRAINT [EPS_SEC_STORE_PK] PRIMARY KEY CLUSTERED ([CHAIN_NHIN_ID], [STORE_NHIN_ID]),
    CONSTRAINT [EPS_SEC_STORE_FK_CHAIN] FOREIGN KEY ([CHAIN_NHIN_ID]) REFERENCES [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NHIN_ID])
)
GO

-- NOTE: System master table - referenced by BATCH_11 and other transactions
-- NOTE: Removed Oracle storage params, SUPPLEMENTAL LOG
-- CRITICAL: Referenced by FK in EPS.PATIENT_UNMERGE_LOCK (BATCH_11)

CREATE NONCLUSTERED INDEX [IX_EPS_SEC_STORE_NUMBER] ON [SEC_ADMIN].[EPS_SEC_STORE] ([STORE_NUMBER]) GO
CREATE NONCLUSTERED INDEX [IX_EPS_SEC_STORE_NAME] ON [SEC_ADMIN].[EPS_SEC_STORE] ([STORE_NAME]) GO
-- =====================================================================
