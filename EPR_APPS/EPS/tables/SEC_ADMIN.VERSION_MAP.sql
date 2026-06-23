-- =====================================================================
-- CONVERTED: SEC_ADMIN.VERSION_MAP
-- =====================================================================
-- Source: Oracle SEC_ADMIN | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 150 | FINAL TABLE - SYSTEM METADATA

-- System metadata table for version/schema versioning

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[SEC_ADMIN].[VERSION_MAP]', 'U') IS NOT NULL
    DROP TABLE [SEC_ADMIN].[VERSION_MAP]
GO

CREATE TABLE [SEC_ADMIN].[VERSION_MAP] (
    [VERSION_ID] BIGINT NOT NULL,
    [VERSION_NUMBER] VARCHAR(20) NOT NULL,
    [SCHEMA_VERSION] VARCHAR(20) NULL,
    [RELEASE_DATE] DATETIME2(6) NULL,
    CONSTRAINT [VERSION_MAP_PK] PRIMARY KEY CLUSTERED ([VERSION_ID])
)
GO

-- NOTE: Final table - system metadata for versioning
-- NOTE: Removed Oracle storage params, SUPPLEMENTAL LOG
-- FINAL BATCH: This is the last table of 150 total tables

-- =====================================================================
-- PROJECT COMPLETE: All 150 tables converted
-- =====================================================================
