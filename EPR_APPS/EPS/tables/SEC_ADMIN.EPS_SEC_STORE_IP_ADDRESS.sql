-- =====================================================================
-- CONVERTED: SEC_ADMIN.EPS_SEC_STORE_IP_ADDRESS
-- =====================================================================
-- Source: Oracle SEC_ADMIN | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 148 | SYSTEM CONFIG TABLE

-- System configuration table for store/location IP address mapping

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS]', 'U') IS NOT NULL
    DROP TABLE [SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS]
GO

CREATE TABLE [SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS] (
    [IP_ID] BIGINT NOT NULL,
    [STORE_ID] BIGINT NULL,
    [IP_ADDRESS] VARCHAR(15) NULL,
    [DESCRIPTION] VARCHAR(100) NULL,
    CONSTRAINT [EPS_SEC_STORE_IP_ADDRESS_PK] PRIMARY KEY CLUSTERED ([IP_ID])
)
GO

-- NOTE: System configuration table
-- NOTE: Removed Oracle storage params, SUPPLEMENTAL LOG

CREATE NONCLUSTERED INDEX [IX_EPS_SEC_STORE_IP_STORE] ON [SEC_ADMIN].[EPS_SEC_STORE_IP_ADDRESS] ([STORE_ID]) GO
-- =====================================================================
