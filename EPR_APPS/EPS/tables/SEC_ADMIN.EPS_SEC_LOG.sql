-- =====================================================================
-- CONVERTED: SEC_ADMIN.EPS_SEC_LOG
-- =====================================================================
-- Source: Oracle SEC_ADMIN | Target: Azure SQL | Date: May 29, 2026
-- Status: BATCH 15, File 147 | SYSTEM LOG TABLE

-- System logging table for audit trail and activity tracking

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[SEC_ADMIN].[EPS_SEC_LOG]', 'U') IS NOT NULL
    DROP TABLE [SEC_ADMIN].[EPS_SEC_LOG]
GO

CREATE TABLE [SEC_ADMIN].[EPS_SEC_LOG] (
    [LOG_ID] BIGINT NOT NULL,
    [CHAIN_ID] BIGINT NULL,
    [USER_ID] VARCHAR(50) NULL,
    [ACTION_TYPE] VARCHAR(50) NULL,
    [DETAILS] VARCHAR(MAX) NULL,
    [LOG_DATE] DATETIME2(6) NOT NULL,
    CONSTRAINT [EPS_SEC_LOG_PK] PRIMARY KEY CLUSTERED ([LOG_ID])
)
GO

-- NOTE: System log table - no partitioning
-- NOTE: Removed Oracle storage params, SUPPLEMENTAL LOG
-- Size consideration: Log tables may grow quickly - consider archival strategy

CREATE NONCLUSTERED INDEX [IX_EPS_SEC_LOG_DATE] ON [SEC_ADMIN].[EPS_SEC_LOG] ([LOG_DATE]) GO
CREATE NONCLUSTERED INDEX [IX_EPS_SEC_LOG_USER] ON [SEC_ADMIN].[EPS_SEC_LOG] ([USER_ID]) GO
-- =====================================================================
