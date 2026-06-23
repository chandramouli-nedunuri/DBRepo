IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'EPS')
BEGIN
    EXEC(N'CREATE SCHEMA [EPS]');
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_meta_version]
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.meta_version', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.read_metadata', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_delete_metadata]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.delete_metadata', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_refresh_metadata_apply]
    @p_file_or_task NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.refresh_metadata_apply', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash]
    @p_sql NVARCHAR(MAX),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.meta_hash', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname]
    @p_file_or_task NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_taskname', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_filename]
    @p_file_or_task NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_filename', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_filetype]
    @p_file_or_task NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_filetype', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata]
    @p_file_or_task NVARCHAR(4000),
    @p_parameter NVARCHAR(4000),
    @p_source NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_metadata', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl]
    @p_file_or_task NVARCHAR(4000),
    @p_parameter NVARCHAR(4000),
    @p_source NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_metadata_tbl', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_by_val]
    @p_file_or_task NVARCHAR(4000),
    @p_parameter NVARCHAR(4000),
    @p_source NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_metadata_by_val', 1;
END;
GO


CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl_by_val]
    @p_file_or_task NVARCHAR(4000),
    @p_parameter NVARCHAR(4000),
    @p_source NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER_META.get_metadata_tbl_by_val', 1;
END;
GO

