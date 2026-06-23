IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'EPS')
BEGIN
    EXEC(N'CREATE SCHEMA [EPS]');
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_change_precision_scale]
    @p_table_name NVARCHAR(4000),
    @p_change_list NVARCHAR(4000),
    @p_parallel DECIMAL(38,10) = 0,
    @p_increase_only BIT,
    @p_use_ctas BIT,
    @p_set_unused BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_HELPER.change_precision_scale', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_column]
    @p_table_name NVARCHAR(4000),
    @p_drop_list NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_HELPER.drop_column', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_unused]
    @p_table_name NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_HELPER.drop_unused', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_debug]
    @p_value BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_HELPER.set_debug', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_purge_debug]
    @p_date DATETIME2(7),
    @p_proc NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_HELPER.purge_debug', 1;
END;
GO

