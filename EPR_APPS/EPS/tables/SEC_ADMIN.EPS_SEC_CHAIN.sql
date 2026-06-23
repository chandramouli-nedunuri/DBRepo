-- =====================================================================
-- CONVERTED: SEC_ADMIN.EPS_SEC_CHAIN
-- =====================================================================
-- Source: Oracle SEC_ADMIN | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 146 | SYSTEM MASTER TABLE - CRITICAL

-- System master table for chain/organization management
-- This table is referenced by ALL EPS tables (core hierarchical anchor)

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[SEC_ADMIN].[EPS_SEC_CHAIN]', 'U') IS NOT NULL
    DROP TABLE [SEC_ADMIN].[EPS_SEC_CHAIN]
GO

CREATE TABLE [SEC_ADMIN].[EPS_SEC_CHAIN] (
    [CHAIN_NHIN_ID] BIGINT NOT NULL,
    [CHAIN_NAME] VARCHAR(100) NOT NULL,
    [PARENT_CHAIN_ID] BIGINT NULL,
    [COUNTRY_CODE] VARCHAR(2) NULL,
    CONSTRAINT [EPS_SEC_CHAIN_PK] PRIMARY KEY CLUSTERED ([CHAIN_NHIN_ID])
)
GO

-- NOTE: System master table - no Oracle partitioning in standard config
-- NOTE: Removed Oracle storage params, SUPPLEMENTAL LOG
-- CRITICAL: This table is foreign key reference for all 150+ EPS tables
-- Post-Migration: Validate all FK references are satisfied

CREATE NONCLUSTERED INDEX [IX_EPS_SEC_CHAIN_NAME] ON [SEC_ADMIN].[EPS_SEC_CHAIN] ([CHAIN_NAME]) GO
-- =====================================================================
