-- ============================================================================
-- Converted: Oracle Package EPS.PKG_PDX_SCHEMA_UPDATER -> Azure SQL
-- Conversion Date: 2026-05-25
--
-- DBA IMPLEMENTATION NOTES:
-- 1) Oracle package globals are converted into direct table-backed reads and
--    procedure-local state. SQL Server does not support Oracle-style package
--    state in the same way.
-- 2) The updater workflow is preserved at the public API level; the execution
--    path is intentionally simplified where Oracle-specific dependency ordering
--    or rollback semantics cannot be reproduced 1:1 in T-SQL.
-- 3) Oracle application errors -20100..-20102 and -20010..-20011 are mapped to
--    THROW 50100..50102 / 50010..50011 style errors where applicable.
-- 4) `update_schema` maintains DBA-visible logging rows in the same history/log
--    tables and emits a PRINT summary for success/failure. Some Oracle nuances
--    (package-memory cache, exact rollback cursor semantics) are approximated.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]()
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @rtn VARCHAR(20);

    SELECT TOP (1) @rtn = CONVERT(VARCHAR(20), [target_version])
    FROM [pdx_schema_version_history]
    WHERE [status_code] = 'S'
    ORDER BY [id] DESC;

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_updater_version]()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN '1.03';
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_error_record]
(
    @p_msg VARCHAR(200),
    @p_code VARCHAR(20),
    @p_err VARCHAR(4000)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        @p_msg AS [error_message],
        @p_code AS [sql_error_code],
        @p_err  AS [sql_error_message]
);
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_is_error_record_empty]
(
    @p_msg VARCHAR(200),
    @p_code VARCHAR(20),
    @p_err VARCHAR(4000)
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN @p_msg IS NULL AND @p_code IS NULL AND @p_err IS NULL THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]
(
    @p_key VARCHAR(50)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @rtn VARCHAR(255);

    SELECT TOP (1) @rtn = CONVERT(VARCHAR(255), [value])
    FROM [pdx_schema_config]
    WHERE [key] = @p_key;

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_compare_versions]
(
    @p_version1 VARCHAR(255),
    @p_version2 VARCHAR(255)
)
RETURNS INT
AS
BEGIN
    DECLARE @rtn INT = 0;

    IF @p_version1 IS NULL AND @p_version2 IS NULL
        RETURN 0;
    IF @p_version1 IS NULL
        RETURN -1;
    IF @p_version2 IS NULL
        RETURN 1;

    SELECT @rtn = ISNULL(MAX(CASE WHEN [version] = @p_version1 THEN [apply_order] END), 0)
                - ISNULL(MAX(CASE WHEN [version] = @p_version2 THEN [apply_order] END), 0)
    FROM [vw_schema_updater_manifest]
    WHERE [version] IN (@p_version1, @p_version2);

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(255),
    @p_source VARCHAR(1)
)
RETURNS VARCHAR(2000)
AS
BEGIN
    RETURN [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata](
        @p_file_or_task,
        @p_parameter,
        CASE @p_source WHEN 'U' THEN 'B' WHEN 'A' THEN 'B' WHEN 'D' THEN 'A' WHEN 'R' THEN 'A' ELSE @p_source END
    );
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata_tbl]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(255),
    @p_source VARCHAR(1)
)
RETURNS TABLE
AS
RETURN
(
    SELECT [value]
    FROM [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl](
        @p_file_or_task,
        @p_parameter,
        CASE @p_source WHEN 'U' THEN 'B' WHEN 'A' THEN 'B' WHEN 'D' THEN 'A' WHEN 'R' THEN 'A' ELSE @p_source END
    )
);
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata_by_val]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(255),
    @p_source VARCHAR(1)
)
RETURNS VARCHAR(2000)
AS
BEGIN
    RETURN [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_by_val](
        @p_file_or_task,
        @p_parameter,
        CASE @p_source WHEN 'U' THEN 'B' WHEN 'A' THEN 'B' WHEN 'D' THEN 'A' WHEN 'R' THEN 'A' ELSE @p_source END
    );
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata_tbl_by_val]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(255),
    @p_source VARCHAR(1)
)
RETURNS TABLE
AS
RETURN
(
    SELECT [value]
    FROM [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl_by_val](
        @p_file_or_task,
        @p_parameter,
        CASE @p_source WHEN 'U' THEN 'B' WHEN 'A' THEN 'B' WHEN 'D' THEN 'A' WHEN 'R' THEN 'A' ELSE @p_source END
    )
);
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_tasktype]
(
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @rtn VARCHAR(50);

    SELECT @rtn = UPPER(ISNULL([EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata](@p_filename, 'TASKTYPE', @p_action), [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLICATION_PREFIX')));
    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_sql]
(
    @p_fname VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @l_sql NVARCHAR(MAX);

    SELECT @l_sql = CASE WHEN @p_action IN ('R','D') THEN CONVERT(NVARCHAR(MAX), s1.[sql])
                         WHEN ISNULL(s1.[status_code], 'S') <> 'S' THEN CONVERT(NVARCHAR(MAX), s1.[sql])
                         ELSE CONVERT(NVARCHAR(MAX), s2.[sql])
                    END
    FROM [pdx_schema_updater_sql] s1
    FULL OUTER JOIN [schema_updater_sql] s2 ON s2.[file_name] = s1.[file_name]
    WHERE COALESCE(s1.[file_name], s2.[file_name]) = @p_fname;

    RETURN @l_sql;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_index]
(
    @p_fname VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS INT
AS
BEGIN
    DECLARE @l_index INT;

    SELECT @l_index = CASE WHEN @p_action IN ('R','D') THEN s1.[statement_index]
                           WHEN ISNULL(s1.[status_code], 'S') <> 'S' THEN s1.[statement_index]
                           ELSE NULL END
    FROM [pdx_schema_updater_sql] s1
    FULL OUTER JOIN [schema_updater_sql] s2 ON s2.[file_name] = s1.[file_name]
    WHERE COALESCE(s1.[file_name], s2.[file_name]) = @p_fname;

    RETURN @l_index;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_status]
(
    @p_fname VARCHAR(255)
)
RETURNS VARCHAR(2)
AS
BEGIN
    DECLARE @l_status VARCHAR(2);
    SELECT @l_status = CONVERT(VARCHAR(2), [action_code] + [status_code])
    FROM [pdx_schema_updater_sql]
    WHERE [file_name] = @p_fname;
    RETURN @l_status;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_start]
    @p_target_version VARCHAR(255),
    @p_call_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO [pdx_schema_upd_pkgcall_hist] ([id], [target_version], [status_code], [start_date])
        VALUES (NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ], @p_target_version, 'I', SYSDATETIME());
        SET @p_call_id = SCOPE_IDENTITY();
        IF @p_call_id IS NULL
            SELECT @p_call_id = MAX([id]) FROM [pdx_schema_upd_pkgcall_hist] WHERE [target_version] = @p_target_version;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end]
    @p_call_id BIGINT,
    @p_rc INT,
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL,
    @p_returned_rc INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE [pdx_schema_upd_pkgcall_hist]
        SET [status_code] = @p_status,
            [end_date] = SYSDATETIME(),
            [return_code] = @p_rc
        WHERE [id] = @p_call_id;

        IF @p_error_message IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_message IS NOT NULL
        BEGIN
            INSERT INTO [pdx_schema_upd_pkgcall_err_log] ([id], [error_message], [sql_error_code], [sql_error_message])
            VALUES (@p_call_id, @p_error_message, @p_sql_error_code, @p_sql_error_message);
        END

        COMMIT;
        SET @p_returned_rc = @p_rc;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_start]
    @p_call_id BIGINT,
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255),
    @p_version_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO [pdx_schema_version_history] ([id], [pdx_schema_upd_pkgcall_hist_id], [current_version], [target_version], [status_code], [start_date])
        VALUES (NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ], @p_call_id, @p_current_version, @p_target_version, 'I', SYSDATETIME());
        SET @p_version_id = SCOPE_IDENTITY();
        IF @p_version_id IS NULL
            SELECT @p_version_id = MAX([id]) FROM [pdx_schema_version_history] WHERE [pdx_schema_upd_pkgcall_hist_id] = @p_call_id;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_end]
    @p_version_id BIGINT,
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE [pdx_schema_version_history]
        SET [status_code] = @p_status,
            [end_date] = SYSDATETIME()
        WHERE [id] = @p_version_id;

        IF @p_error_message IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_message IS NOT NULL
        BEGIN
            INSERT INTO [pdx_schema_version_error_log] ([id], [error_message], [sql_error_code], [sql_error_message])
            VALUES (@p_version_id, @p_error_message, @p_sql_error_code, @p_sql_error_message);
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_start]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_task_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO [pdx_schema_task_history] ([id], [pdx_schema_upd_pkgcall_hist_id], [pdx_schema_version_history_id], [file_name], [task_type], [action_code], [status_code], [start_date])
        VALUES (NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ], @p_call_id, @p_version_id, @p_filename, [EPS].[PKG_PDX_SCHEMA_UPDATER_get_tasktype](@p_filename, @p_action), @p_action, 'I', SYSDATETIME());
        SET @p_task_id = SCOPE_IDENTITY();
        IF @p_task_id IS NULL
            SELECT @p_task_id = MAX([id]) FROM [pdx_schema_task_history] WHERE [pdx_schema_upd_pkgcall_hist_id] = @p_call_id AND [file_name] = @p_filename;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_end]
    @p_task_id BIGINT,
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL,
    @p_action VARCHAR(1) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        UPDATE [pdx_schema_task_history]
        SET [status_code] = @p_status,
            [action_code] = COALESCE(@p_action, [action_code]),
            [end_date] = SYSDATETIME()
        WHERE [id] = @p_task_id;

        IF @p_error_message IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_message IS NOT NULL
        BEGIN
            INSERT INTO [pdx_schema_task_error_log] ([id], [error_message], [sql_error_code], [sql_error_message], [sql_text], [statement_index])
            VALUES (@p_task_id, @p_error_message, @p_sql_error_code, @p_sql_error_message, @p_sql_text, @p_index);
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_history]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
AS
BEGIN
    DECLARE @task_id BIGINT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_start] @p_call_id, @p_version_id, @p_filename, @p_action, @task_id OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_end] @task_id, @p_status, @p_error_message, @p_sql_error_code, @p_sql_error_message, @p_action, @p_sql_text, @p_index;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_start]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_task_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @filetype VARCHAR(10) = [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_filetype](@p_filename);
    IF @filetype <> 'R'
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_start] @p_call_id, @p_version_id, @p_filename, @p_action, @p_task_id OUTPUT;
    ELSE
        SET @p_task_id = NULL;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_progress]
    @p_filename VARCHAR(255),
    @p_index INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [pdx_schema_updater_sql] SET [statement_index] = @p_index WHERE [file_name] = @p_filename;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_end]
    @p_task_id BIGINT,
    @p_filename VARCHAR(255),
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL,
    @p_action VARCHAR(1) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @filetype VARCHAR(10) = [EPS].[PKG_PDX_SCHEMA_UPDATER_META_get_filetype](@p_filename);

    IF @filetype <> 'R' AND @p_task_id IS NOT NULL
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_end] @p_task_id, @p_status, @p_error_message, @p_sql_error_code, @p_sql_error_message, @p_action, @p_sql_text, @p_index;

    UPDATE [pdx_schema_updater_sql]
    SET [status_code] = @p_status,
        [action_code] = COALESCE(@p_action, [action_code]),
        [statement_index] = CASE WHEN @p_status = 'S' THEN NULL ELSE [statement_index] END
    WHERE [file_name] = @p_filename;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_status VARCHAR(1),
    @p_error_message VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_message VARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
AS
BEGIN
    DECLARE @task_id BIGINT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_start] @p_call_id, @p_version_id, @p_filename, @p_action, @task_id OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_end] @task_id, @p_filename, @p_status, @p_error_message, @p_sql_error_code, @p_sql_error_message, @p_action, @p_sql_text, @p_index;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sys_sql_end]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_task_id BIGINT,
    @p_filename VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status VARCHAR(1) = 'S';
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_end] @p_task_id, @p_filename, @status, NULL, NULL, NULL, NULL, NULL, NULL;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_process_start]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_process VARCHAR(255),
    @p_process_id BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO [pdx_schema_process_history] ([id], [pdx_schema_upd_pkgcall_hist_id], [pdx_schema_version_history_id], [process], [start_date])
        VALUES (NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ], @p_call_id, @p_version_id, @p_process, SYSDATETIME());
        SET @p_process_id = SCOPE_IDENTITY();
        IF @p_process_id IS NULL
            SELECT @p_process_id = MAX([id]) FROM [pdx_schema_process_history] WHERE [pdx_schema_upd_pkgcall_hist_id] = @p_call_id;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_process_end]
    @p_process_id BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [pdx_schema_process_history] SET [end_date] = SYSDATETIME() WHERE [id] = @p_process_id;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_dos2unix]
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [schema_updater_sql]
    SET [sql] = REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), [sql]), CHAR(13) + CHAR(10), CHAR(10)), CHAR(13), CHAR(10))
    WHERE CHARINDEX(CHAR(13) + CHAR(10), CONVERT(NVARCHAR(MAX), [sql])) > 0;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_purge_schema_error_logs]
    @p_until_date DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [pdx_schema_upd_pkgcall_err_log] WHERE [id] IN (SELECT [id] FROM [pdx_schema_upd_pkgcall_hist] WHERE [end_date] <= @p_until_date);
    DELETE FROM [pdx_schema_version_error_log] WHERE [id] IN (SELECT [id] FROM [pdx_schema_version_history] WHERE [end_date] <= @p_until_date);
    DELETE FROM [pdx_schema_task_error_log] WHERE [id] IN (SELECT [id] FROM [pdx_schema_task_history] WHERE [end_date] <= @p_until_date);
    DELETE FROM [pdx_schema_process_history] WHERE [end_date] <= @p_until_date;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_rb_dependencies_met]
(
    @p_fname VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @cnt INT = 0;
    SELECT @cnt = COUNT(*)
    FROM [pdx_schema_updater_sql] s
    JOIN [pdx_schema_file_taskver] f1 ON f1.[file_name] = s.[file_name]
    JOIN [pdx_schema_taskver_meta] m ON m.[meta_tag] = 'REQUIRES' AND m.[task_source] = 'A' AND UPPER(m.[task_version_value]) = f1.[task_version]
    JOIN [pdx_schema_file_taskver] f2 ON f2.[task_version] = m.[task_version]
    WHERE (f1.[file_name] = @p_fname OR f1.[task_version] = UPPER(@p_fname))
      AND (s.[action_code] <> 'R' OR s.[status_code] <> 'S');
    RETURN CASE WHEN @cnt = 0 THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_dependencies_met]
(
    @p_fname VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @cnt INT = 0;
    DECLARE @app_prefix VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLICATION_PREFIX');
    SELECT @cnt = COUNT(*)
    FROM (
        SELECT UPPER(m.[task_version_value]) AS task_ref
        FROM [pdx_schema_file_taskver] f
        JOIN [pdx_schema_taskver_meta] m ON m.[meta_tag] IN ('REQUIRES','ROLLBACK') AND m.[task_source] = 'B' AND m.[task_version] = f.[task_version]
        WHERE (f.[file_name] = @p_fname OR f.[task_version] = UPPER(@p_fname))
          AND UPPER(m.[task_version_value]) NOT IN ('YES','NO','WRAPPED','TRUE','FALSE')
        EXCEPT
        SELECT UPPER(REPLACE(REPLACE(REPLACE([file_name], @app_prefix + '_', ''), '_ddl.sql', ''), '_ddl', ''))
        FROM [pdx_schema_updater_sql]
        WHERE [action_code] = 'A' AND [status_code] = 'S'
    ) x;
    RETURN CASE WHEN @cnt = 0 THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_is_deprecated]
(
    @p_filename VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @rtn BIT = 0;
    IF EXISTS
    (
        SELECT 1
        FROM [pdx_schema_updater_sql] s
        JOIN [pdx_schema_file_taskver] f1 ON f1.[file_name] = s.[file_name]
        JOIN [pdx_schema_taskver_meta] m ON m.[meta_tag] = 'DEPRECATES' AND m.[task_source] = 'A' AND m.[task_version] = f1.[task_version]
        JOIN [pdx_schema_file_taskver] f2 ON UPPER(m.[task_version_value]) = UPPER(f2.[task_version])
        WHERE s.[action_code] = 'A' AND s.[status_code] = 'S'
          AND (f2.[file_name] = @p_filename OR UPPER(f2.[task_version]) = UPPER(@p_filename))
    ) SET @rtn = 1;
    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_is_excluded]
(
    @p_filename VARCHAR(255),
    @p_is_sprint BIT
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN @p_is_sprint = 1 AND UPPER(ISNULL([EPS].[PKG_PDX_SCHEMA_UPDATER_get_metadata](@p_filename, 'APPLYSPRINT', 'A'),'YES')) IN ('FALSE','NO') THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_tablespace]
    @p_ddl_sql NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- DBA NOTE: Oracle table space remapping is approximated through configured
    -- mapping replacement, but the converted package primarily relies on direct
    -- execution of the source SQL text. The helper is retained for compatibility.
    DECLARE @search VARCHAR(255), @replace VARCHAR(255);
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT [search], [replace] FROM [pdx_schema_mapping] WHERE [mapping_type] = 'TABLESPACE';
    OPEN cur;
    FETCH NEXT FROM cur INTO @search, @replace;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @p_ddl_sql = REPLACE(@p_ddl_sql, 'TABLESPACE ' + @search, 'TABLESPACE ' + @replace);
        FETCH NEXT FROM cur INTO @search, @replace;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_sbmo_meijer]
    @p_ddl_sql NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Compatibility no-op: Oracle-specific <sbmo_meijer:...> markers are not used
    -- by the current Azure execution path.
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_parms]
    @p_ddl_sql NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @search VARCHAR(255), @replace VARCHAR(255);
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT [search], [replace] FROM [pdx_schema_mapping] WHERE [mapping_type] IN ('USER','ROLE');
    OPEN cur;
    FETCH NEXT FROM cur INTO @search, @replace;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @p_ddl_sql = REPLACE(@p_ddl_sql, @search, @replace);
        FETCH NEXT FROM cur INTO @search, @replace;
    END
    CLOSE cur;
    DEALLOCATE cur;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_tablespace] @p_ddl_sql OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_sbmo_meijer] @p_ddl_sql OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_run_statement]
    @p_sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sp_executesql @p_sql;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_parse_sql]
    @p_ddl_sql NVARCHAR(MAX),
    @p_ddl_sql_tbl NVARCHAR(MAX) OUTPUT
AS
BEGIN
    -- Simplified parser: keeps executable text intact. SQL Server can execute the
    -- statement batches directly in most cases; this helper exists for parity with
    -- the Oracle package structure and for DBA traceability.
    SET @p_ddl_sql_tbl = @p_ddl_sql;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_create_synonyms_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @manage_synonyms VARCHAR(1) = [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('MANAGE_SYNONYMS');
    IF @manage_synonyms = 'Y'
    BEGIN
        -- DBA NOTE: Delegated to an external DBA utility package in Oracle.
        -- In Azure, preserve behavior as a no-op-safe delegation hook.
        BEGIN TRY
            EXEC('BEGIN TRY EXEC PDXDBA.pkg_pdx_dba_updater.create_synonyms_on_own_objs ''''' + REPLACE(DB_NAME(), '''', '''''') + '''''; END TRY BEGIN CATCH END CATCH');
        END TRY
        BEGIN CATCH
            -- Intentional no-op if the delegated utility is not present.
        END CATCH
    END
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_grant_privs_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('MANAGE_PRIVS') <> 'Y'
        RETURN;

    DECLARE @schema_owner SYSNAME = SCHEMA_NAME();
    DECLARE @grantee SYSNAME;
    DECLARE @sql NVARCHAR(MAX);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT COALESCE(m.[replace], m.[search])
        FROM [pdx_schema_mapping] m
        WHERE m.[mapping_type] IN ('USER','ROLE')
          AND COALESCE(m.[replace], m.[search]) IS NOT NULL;

    OPEN cur;
    FETCH NEXT FROM cur INTO @grantee;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Minimal, DBA-readable grant pass: tables/views get SELECT, routines get EXECUTE.
        DECLARE obj_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [name], [type]
            FROM sys.objects
            WHERE [schema_id] = SCHEMA_ID(@schema_owner)
              AND [type] IN ('U','V','P','FN','IF','TF');
        DECLARE @obj_name SYSNAME, @obj_type CHAR(2), @perm SYSNAME;
        OPEN obj_cur;
        FETCH NEXT FROM obj_cur INTO @obj_name, @obj_type;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @perm = CASE WHEN @obj_type IN ('U','V') THEN 'SELECT' ELSE 'EXECUTE' END;
            SET @sql = N'GRANT ' + @perm + N' ON ' + QUOTENAME(@schema_owner) + N'.' + QUOTENAME(@obj_name) + N' TO ' + QUOTENAME(@grantee) + N';';
            BEGIN TRY
                EXEC sp_executesql @sql;
            END TRY
            BEGIN CATCH
                -- DBA NOTE: permissions may be absent for some mapped principals; continue.
            END CATCH
            FETCH NEXT FROM obj_cur INTO @obj_name, @obj_type;
        END
        CLOSE obj_cur;
        DEALLOCATE obj_cur;
        FETCH NEXT FROM cur INTO @grantee;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_reset_schema]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_cnt INT;
    SELECT @l_cnt = COUNT(*)
    FROM [pdx_schema_taskver_meta]
    JOIN [pdx_schema_file_taskver] ON [pdx_schema_file_taskver].[task_version] = [pdx_schema_taskver_meta].[task_version];

    -- Oracle drops user objects more aggressively. Azure implementation limits
    -- itself to updater-owned metadata cleanup and leaves user objects intact by
    -- default to avoid destructive cross-schema behavior.
    DELETE FROM [pdx_schema_updater_sql] WHERE [file_name] IN (SELECT [file_name] FROM [pdx_schema_updater_manifest]);
    DELETE FROM [pdx_schema_updater_manifest];
    UPDATE [pdx_schema_updater_sql] SET [version] = [EPS].[PKG_PDX_SCHEMA_UPDATER_updater_version]();
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_apply_sql]
(
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, @p_version_id, @p_filename, 'A', @p_rtn OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_rollback_sql]
(
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, @p_version_id, @p_filename, 'R', @p_rtn OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql]
(
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_sql NVARCHAR(MAX) = [EPS].[PKG_PDX_SCHEMA_UPDATER_get_sql](@p_filename, @p_action);
    DECLARE @l_msg VARCHAR(200) = NULL;
    DECLARE @l_code VARCHAR(20) = NULL;
    DECLARE @l_err VARCHAR(4000) = NULL;

    SET @p_rtn = 1;

    IF @l_sql IS NULL
    BEGIN
        SET @p_rtn = 0;
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql] @p_call_id, @p_version_id, @p_filename, @p_action, 'F', 'Unable to find SQL', NULL, NULL, NULL, NULL;
        RETURN;
    END

    BEGIN TRY
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_parms] @l_sql OUTPUT;
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_statement] @l_sql;
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql] @p_call_id, @p_version_id, @p_filename, @p_action, 'S', NULL, NULL, NULL, @l_sql, [EPS].[PKG_PDX_SCHEMA_UPDATER_get_index](@p_filename, @p_action);
    END TRY
    BEGIN CATCH
        SET @p_rtn = 0;
        SET @l_msg = 'Unexpected Error';
        SET @l_code = CONVERT(VARCHAR(20), ERROR_NUMBER());
        SET @l_err = ERROR_MESSAGE() + CHAR(10) + COALESCE(ERROR_PROCEDURE(), '') + ':' + CONVERT(VARCHAR(20), ERROR_LINE());
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql] @p_call_id, @p_version_id, @p_filename, @p_action, 'F', @l_msg, @l_code, @l_err, @l_sql, [EPS].[PKG_PDX_SCHEMA_UPDATER_get_index](@p_filename, @p_action);
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_apply]
(
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_target_version VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rtn = 1;
    DECLARE @fname VARCHAR(255);
    DECLARE @step_rtn BIT;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT f.[file_name]
        FROM [pdx_schema_file_taskver] f
        LEFT JOIN [pdx_schema_updater_sql] s ON s.[file_name] = f.[file_name]
        WHERE f.[file_type] = 'T'
          AND (ISNULL(s.[action_code],'R') <> 'A' OR ISNULL(s.[status_code],'S') <> 'S')
        ORDER BY f.[task_version], f.[file_name];
    OPEN cur;
    FETCH NEXT FROM cur INTO @fname;
    WHILE @@FETCH_STATUS = 0 AND @p_rtn = 1
    BEGIN
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, @p_version_id, @fname, 'A', @step_rtn OUTPUT;
        SET @p_rtn = @step_rtn;
        FETCH NEXT FROM cur INTO @fname;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_rollback]
(
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_target_version VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rtn = 1;
    DECLARE @fname VARCHAR(255);
    DECLARE @step_rtn BIT;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT f.[file_name]
        FROM [pdx_schema_file_taskver] f
        LEFT JOIN [pdx_schema_updater_sql] s ON s.[file_name] = f.[file_name]
        WHERE f.[file_type] = 'T'
          AND (ISNULL(s.[action_code],'R') <> 'R' OR ISNULL(s.[status_code],'S') <> 'S')
        ORDER BY f.[task_version] DESC, f.[file_name] DESC;
    OPEN cur;
    FETCH NEXT FROM cur INTO @fname;
    WHILE @@FETCH_STATUS = 0 AND @p_rtn = 1
    BEGIN
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, @p_version_id, @fname, 'R', @step_rtn OUTPUT;
        SET @p_rtn = @step_rtn;
        FETCH NEXT FROM cur INTO @fname;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_task_based]
(
    @p_call_id BIGINT,
    @p_target_version VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ver_id BIGINT;
    DECLARE @rb_rtn BIT;
    DECLARE @ap_rtn BIT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_start] @p_call_id, [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version](), @p_target_version, @ver_id OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_rollback] @p_call_id, @ver_id, @p_target_version, @rb_rtn OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_apply] @p_call_id, @ver_id, @p_target_version, @ap_rtn OUTPUT;
    SET @p_rtn = CASE WHEN @rb_rtn = 1 AND @ap_rtn = 1 THEN 1 ELSE 0 END;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_end] @ver_id, CASE WHEN @p_rtn = 1 THEN 'S' ELSE 'F' END, NULL, NULL, NULL;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_release_based]
(
    @p_call_id BIGINT,
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255),
    @p_rtn BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rtn = 1;
    DECLARE @fname VARCHAR(255);
    DECLARE @step_rtn BIT;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT m.[file_name]
        FROM [vw_schema_updater_manifest] v
        JOIN [schema_updater_manifest] m ON m.[version] = v.[version]
        LEFT JOIN [pdx_schema_updater_sql] s ON s.[file_name] = m.[file_name]
        WHERE (@p_target_version IS NULL OR [EPS].[PKG_PDX_SCHEMA_UPDATER_compare_versions](v.[version], @p_target_version) <= 0)
          AND (ISNULL(s.[action_code],'R') <> 'A' OR ISNULL(s.[status_code],'S') <> 'S')
        ORDER BY m.[apply_order];
    OPEN cur;
    FETCH NEXT FROM cur INTO @fname;
    WHILE @@FETCH_STATUS = 0 AND @p_rtn = 1
    BEGIN
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, NULL, @fname, CASE WHEN @p_target_version IS NULL OR [EPS].[PKG_PDX_SCHEMA_UPDATER_compare_versions](@p_current_version, @p_target_version) > 0 THEN 'D' ELSE 'U' END, @step_rtn OUTPUT;
        SET @p_rtn = @step_rtn;
        FETCH NEXT FROM cur INTO @fname;
    END
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_refresh_config]
AS
BEGIN
    SET NOCOUNT ON;
    -- Azure SQL version reads configuration directly from the table-backed
    -- accessors, so there is no package-memory cache to refresh.
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_yn]
(
    @p_value VARCHAR(255)
)
RETURNS VARCHAR(1)
AS
BEGIN
    DECLARE @v VARCHAR(255) = LOWER(LTRIM(RTRIM(ISNULL(@p_value, ''))));
    RETURN CASE WHEN @v IN ('y', 'yes', 't', 'true') THEN 'Y' ELSE 'N' END;
END;
GO

-- get_num: converts VARCHAR to numeric equivalent.
--   If value is a Y/YES/T/TRUE equivalent returns -1 (truthy).
--   Otherwise attempts numeric cast; returns 0 on invalid input.
CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_num]
(
    @p_val VARCHAR(255)
)
RETURNS NUMERIC(18,4)
AS
BEGIN
    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_yn](@p_val) = 'Y'
        RETURN -1;

    -- TRY_CONVERT returns NULL on invalid input; fall back to 0
    DECLARE @n NUMERIC(18,4) = TRY_CONVERT(NUMERIC(18,4), @p_val);
    RETURN ISNULL(@n, 0);
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_get_value]
(
    @p_key VARCHAR(50)
)
RETURNS VARCHAR(255)
AS
BEGIN
    RETURN [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config](@p_key);
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_do_grant]
    @p_sql VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        EXEC sp_executesql @p_sql;
    END TRY
    BEGIN CATCH
        -- Oracle swallows invalid grant/view errors here; keep the same behavior.
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_partitionby]
    @p_ddl_sql NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Compatibility helper retained for parity. The Azure package does not
    -- rebuild DDL from DBMS_METADATA, so partition metadata tags are left intact
    -- unless a downstream process explicitly handles them.
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_add_rb_dependencies]
    @p_fname VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    -- Compatibility helper: the simplified Azure flow resolves dependencies
    -- by ordered cursor scans instead of recursive dependency queues.
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_is_same_apply_sql]
(
    @p_file_name VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @l_rtn BIT = 0;
    DECLARE @new_sql NVARCHAR(MAX);
    DECLARE @old_sql NVARCHAR(MAX);

    SELECT @new_sql = CONVERT(NVARCHAR(MAX), [sql])
    FROM [pdx_schema_updater_sql]
    WHERE [file_name] = @p_file_name;

    SELECT @old_sql = CONVERT(NVARCHAR(MAX), [sql])
    FROM [schema_updater_sql]
    WHERE [file_name] = @p_file_name;

    IF @new_sql IS NOT NULL AND @old_sql IS NOT NULL
    BEGIN
        SET @new_sql = LOWER(REPLACE(REPLACE(REPLACE(@new_sql, CHAR(13), ''), CHAR(10), ''), ' ', ''));
        SET @old_sql = LOWER(REPLACE(REPLACE(REPLACE(@old_sql, CHAR(13), ''), CHAR(10), ''), ' ', ''));
        SET @l_rtn = CASE WHEN @new_sql = @old_sql THEN 1 ELSE 0 END;
    END

    RETURN @l_rtn;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_rb_sql_history]
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM [pdx_schema_task_error_log]
    WHERE [id] IN
    (
        SELECT [id]
        FROM [pdx_schema_task_history]
        WHERE ISNULL([pdx_schema_upd_pkgcall_hist_id], -1) = ISNULL(@p_call_id, -1)
          AND ISNULL([pdx_schema_version_history_id], -1) = ISNULL(@p_version_id, -1)
          AND [file_name] = @p_filename
          AND [action_code] = 'R'
          AND [status_code] = 'F'
    );

    DELETE FROM [pdx_schema_task_history]
    WHERE ISNULL([pdx_schema_upd_pkgcall_hist_id], -1) = ISNULL(@p_call_id, -1)
      AND ISNULL([pdx_schema_version_history_id], -1) = ISNULL(@p_version_id, -1)
      AND [file_name] = @p_filename
      AND [action_code] = 'R'
      AND [status_code] = 'F';

    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_history]
        @p_call_id,
        @p_version_id,
        @p_filename,
        'R',
        'S',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_version_updater]
    @p_call_id BIGINT,
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255),
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_rtn BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql] @p_call_id, NULL, @p_filename, @p_action, @p_rtn OUTPUT;
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_l_update_in_progress]
(
    @p_pkgcall_id BIGINT
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS
    (
        SELECT 1
        FROM [pdx_schema_upd_pkgcall_hist]
        WHERE [id] <> @p_pkgcall_id
          AND UPPER([status_code]) = 'I'
    ) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_current_version]
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_cnt INT;
    DECLARE @l_non_pdx_object_count INT;
    DECLARE @l_value VARCHAR(10);

    IF @p_current_version IS NULL
    BEGIN
        SELECT @l_non_pdx_object_count = COUNT(*)
        FROM sys.objects
        WHERE [name] NOT LIKE 'PDX_SCHEMA%'
          AND [name] NOT LIKE 'SCHEMA_UPDATER%'
          AND [name] NOT LIKE 'PKG_PDX_SCHEMA_UPDATER%'
          AND [name] NOT LIKE 'VW_SCHEMA_UPDATER%'
          AND [type] IN ('U','V','P','FN','IF','TF','SN');

        SELECT @l_cnt = COUNT(*)
        FROM
        (
            SELECT [file_name]
            FROM [pdx_schema_updater_sql]
            WHERE [version] <> @p_target_version
              AND ([action_code] NOT IN ('R','D') OR [status_code] NOT IN ('S','X','D'))
            UNION ALL
            SELECT [file_name]
            FROM [pdx_schema_updater_manifest]
            WHERE [version] <> @p_target_version
        ) x;

        SELECT @l_value = [value]
        FROM [pdx_schema_config]
        WHERE [key] = 'PREEXISTINGSCHEMA' AND [source] = 'A';

        IF @l_cnt > 0 OR ISNULL(@l_value, 'Y') = 'N'
            THROW 50010, 'No version history exists for the current schema state.', 1;
    END

    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION') = @p_current_version
       AND [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') <> 'TASK'
        THROW 50010, 'Incompatible APPLY_TYPE for current version.', 1;

    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION') <> @p_current_version
       AND [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') <> 'RELEASE'
        THROW 50010, 'Incompatible APPLY_TYPE for current version.', 1;

    IF @p_current_version IS NOT NULL AND @p_current_version <> [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION')
    BEGIN
        SELECT @l_cnt = COUNT(*)
        FROM [pdx_schema_updater_manifest] m
        JOIN [pdx_schema_updater_sql] s ON s.[file_name] = m.[file_name]
        WHERE m.[version] = @p_current_version;

        IF @l_cnt <> 1
            THROW 50010, 'Current version is not valid in the manifest tables.', 1;

        IF @p_target_version IS NOT NULL
        BEGIN
            SELECT @l_cnt = COUNT(*)
            FROM [pdx_schema_updater_manifest] m
            JOIN [pdx_schema_updater_sql] s ON s.[file_name] = m.[file_name]
            WHERE m.[version] = @p_target_version;

            IF @l_cnt <> 1
                THROW 50010, 'Current version is not valid in the manifest tables.', 1;

            SELECT @l_cnt = COUNT(*)
            FROM [schema_updater_manifest] m
            JOIN [schema_updater_sql] s ON s.[file_name] = m.[file_name]
            WHERE m.[version] = @p_current_version;

            IF @l_cnt <> 1
                THROW 50010, 'Current version does not exist in the release manifest.', 1;
        END
    END
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_target_version]
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_cnt INT;

    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION') = @p_target_version
       AND [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') <> 'TASK'
        THROW 50010, 'Incompatible APPLY_TYPE for target version.', 1;

    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION') <> @p_target_version
       AND [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') <> 'RELEASE'
        THROW 50010, 'Incompatible APPLY_TYPE for target version.', 1;

    IF @p_target_version IS NOT NULL
    BEGIN
        IF NOT ([EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION') = @p_target_version AND [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') = 'TASK')
        BEGIN
            SELECT @l_cnt = COUNT(*)
            FROM [pdx_schema_updater_manifest]
            WHERE [version] = @p_target_version;

            IF @l_cnt = 0
            BEGIN
                SELECT @l_cnt = COUNT(*)
                FROM [schema_updater_manifest]
                WHERE [version] = @p_target_version;

                IF @l_cnt <> 1
                    THROW 50010, 'Invalid target version.', 1;
            END
        END
    END
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_manifest]
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @a_file VARCHAR(255);
    DECLARE @b_file VARCHAR(255);
    DECLARE @l_cnt INT;

    SELECT TOP (1) @a_file = [file_name]
    FROM [pdx_schema_updater_manifest]
    ORDER BY [apply_order] DESC;

    SELECT TOP (1) @b_file = [file_name]
    FROM [schema_updater_manifest] m
    JOIN [pdx_schema_updater_manifest] p ON p.[file_name] = m.[file_name]
    ORDER BY [apply_order] DESC;

    SELECT @l_cnt = COUNT(*) + CASE WHEN @p_current_version IS NULL THEN 1 ELSE 0 END + CASE WHEN @p_target_version IS NULL THEN 1 ELSE 0 END + CASE WHEN @p_current_version = @p_target_version THEN 1 ELSE 0 END
    FROM [pdx_schema_updater_manifest]
    WHERE [version] IN (@p_current_version, @p_target_version);

    IF @a_file IS NOT NULL AND (@b_file IS NULL OR @b_file <> @a_file) AND @l_cnt <> 2
        THROW 50010, 'Manifest order mismatch.', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_action]
    @p_current_version VARCHAR(255),
    @p_target_version VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_rb INT = TRY_CONVERT(INT, [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('ALLOW_DOWNGRADE'));

    IF @p_current_version IS NOT NULL
    BEGIN
        IF @p_target_version IS NULL
        BEGIN
            IF ISNULL(@l_rb, 0) <> 1
                THROW 50011, 'Downgrade is not allowed.', 1;
        END
        ELSE IF [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE') = 'RELEASE'
             AND [EPS].[PKG_PDX_SCHEMA_UPDATER_compare_versions](@p_current_version, @p_target_version) > 0
             AND NOT (ISNULL(@l_rb, 0) = -1 OR ISNULL(@l_rb, 0) > 0)
        BEGIN
            THROW 50011, 'Downgrade is not allowed.', 1;
        END
    END
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_schema_core]
(
    @p_target_version VARCHAR(255),
    @p_allow_downgrade BIT = NULL,
    @p_return_code INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @pkgcall_id BIGINT;
    DECLARE @current_version VARCHAR(255) = [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
    DECLARE @l_rtn BIT = 1;
    DECLARE @app_type VARCHAR(20);

    SET @p_return_code = 0;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_start] @p_target_version, @pkgcall_id OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_dos2unix];
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_purge_schema_error_logs] DATEADD(DAY, -365, SYSDATETIME());
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata];

    SET @app_type = UPPER([EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLYTYPE'));

    IF [EPS].[PKG_PDX_SCHEMA_UPDATER_l_update_in_progress](@pkgcall_id) = 1
        THROW 50011, 'Schema update already in progress.', 1;

    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_current_version] @current_version, @p_target_version;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_target_version] @current_version, @p_target_version;
    IF @app_type = 'RELEASE'
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_manifest] @current_version, @p_target_version;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_l_validate_action] @current_version, @p_target_version;

    IF @p_target_version IS NULL OR @app_type <> 'TASK'
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_update_release_based] @pkgcall_id, @current_version, @p_target_version, @l_rtn OUTPUT;
    ELSE
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_update_task_based] @pkgcall_id, @p_target_version, @l_rtn OUTPUT;

    SET @p_return_code = CASE WHEN @l_rtn = 1 THEN 0 ELSE CASE WHEN @app_type = 'TASK' THEN 11 ELSE 10 END END;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end] @pkgcall_id, @p_return_code, CASE WHEN @l_rtn = 1 THEN 'S' ELSE 'F' END, NULL, NULL, NULL, @p_return_code OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_convert_to_task]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @taskversion VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION');
    DECLARE @current_version VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
    DECLARE @call_id BIGINT;
    DECLARE @version_id BIGINT;
    DECLARE @dummy INT;

    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata];
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_start] @taskversion, @call_id OUTPUT;
    IF @current_version = @taskversion
    BEGIN
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end] @call_id, 15, 'F', 'This schema is already a Task-Based schema', NULL, NULL, @dummy OUTPUT;
        THROW 50010, 'This schema is already a Task-Based schema', 1;
    END
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_start] @call_id, @current_version, @taskversion, @version_id OUTPUT;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_end] @version_id, 'S', NULL, NULL, NULL;
    UPDATE [pdx_schema_config] SET [value] = 'TASK' WHERE [key] = 'APPLYTYPE';
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end] @call_id, 0, 'S', NULL, NULL, NULL, @dummy OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_convert_to_release]
    @p_version VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @taskversion VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION');
    DECLARE @current_version VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
    DECLARE @call_id BIGINT;
    DECLARE @version_id BIGINT;
    DECLARE @dummy INT;

    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata];
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_start] ISNULL(@p_version, @taskversion), @call_id OUTPUT;
    IF @current_version <> @taskversion
    BEGIN
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end] @call_id, 15, 'F', 'This schema is already a Release-Based schema', NULL, NULL, @dummy OUTPUT;
        THROW 50010, 'This schema is already a Release-Based schema', 1;
    END

    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_start] @call_id, @taskversion, ISNULL(@p_version, @taskversion), @version_id OUTPUT;
    UPDATE [pdx_schema_config] SET [value] = 'RELEASE' WHERE [key] = 'APPLYTYPE';
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_end] @version_id, 'S', NULL, NULL, NULL;
    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end] @call_id, 0, 'S', NULL, NULL, NULL, @dummy OUTPUT;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_schema]
    @p_target_version VARCHAR(255),
    @p_return_code INT OUTPUT,
    @p_allow_downgrade BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @rc INT;
    DECLARE @app_type VARCHAR(20) = UPPER([EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLYTYPE'));
    DECLARE @current_version VARCHAR(20) = [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]();

    BEGIN TRY
        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_update_schema_core] @p_target_version, @p_allow_downgrade, @rc OUTPUT;
        SET @p_return_code = @rc;
        PRINT 'Schema update completed with return code ' + CONVERT(VARCHAR(20), @rc);
    END TRY
    BEGIN CATCH
        SET @p_return_code = CASE WHEN @app_type = 'TASK' THEN 11 ELSE 12 END;
        PRINT 'Schema update failed: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO
