-- ============================================================================
-- Converted: Oracle Package SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_META -> Azure SQL
-- Conversion Date: 2026-05-25
--
-- DBA IMPLEMENTATION NOTES:
-- 1) Oracle package state (PL/SQL associative arrays and g_captured) is mapped to
--    persisted metadata tables plus SESSION_CONTEXT flag:
--       - PDX_SCHEMA_FILE_TASKVER
--       - PDX_SCHEMA_TASKVER_META
--       - PKG_PDX_SCHEMA_UPDATER_META_CAPTURED (session key)
-- 2) Oracle REGEXP parsing is approximated using line-based parsing and string logic
--    in T-SQL. Behavior is functionally aligned for standard metadata comment formats.
-- 3) Oracle raise_application_error(-20010/-20011) is mapped to THROW 50010/50011.
-- 4) Oracle nested-table return type results_tbl is mapped to table-valued functions.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_version]()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN '1.01';
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash]
(
    @p_sql NVARCHAR(MAX)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @rtn VARCHAR(255);
    SELECT @rtn = LOWER(CONVERT(VARCHAR(64), HASHBYTES('MD5', CONVERT(VARBINARY(MAX), ISNULL(@p_sql, N''))), 2));
    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname]
(
    @p_file_or_task VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @rtn VARCHAR(255);

    SELECT TOP (1) @rtn = [task_version]
    FROM [PDX_SCHEMA_FILE_TASKVER]
    WHERE [file_name] = @p_file_or_task;

    IF @rtn IS NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM [PDX_SCHEMA_FILE_TASKVER] WHERE [task_version] = UPPER(@p_file_or_task))
            SET @rtn = UPPER(@p_file_or_task);
    END

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_filename]
(
    @p_file_or_task VARCHAR(255)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @rtn VARCHAR(255);

    SELECT TOP (1) @rtn = [file_name]
    FROM [PDX_SCHEMA_FILE_TASKVER]
    WHERE [task_version] = UPPER(@p_file_or_task);

    IF @rtn IS NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM [PDX_SCHEMA_FILE_TASKVER] WHERE [file_name] = @p_file_or_task)
            SET @rtn = @p_file_or_task;
    END

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_filetype]
(
    @p_file_or_task VARCHAR(255)
)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @task VARCHAR(255) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task);
    DECLARE @rtn VARCHAR(10);

    SELECT TOP (1) @rtn = [file_type]
    FROM [PDX_SCHEMA_FILE_TASKVER]
    WHERE [task_version] = @task;

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(40),
    @p_source VARCHAR(1)
)
RETURNS VARCHAR(2000)
AS
BEGIN
    DECLARE @task VARCHAR(255) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task);
    DECLARE @cnt INT;
    DECLARE @rtn VARCHAR(2000);

    SELECT @cnt = COUNT(*)
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version] = @task
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source);

    IF ISNULL(@cnt, 0) > 1
        BEGIN
                -- DBA IMPLEMENTATION NOTE:
                -- T-SQL scalar functions cannot THROW directly. To preserve Oracle-like
                -- TOO_MANY_ROWS semantics, force a single-row scalar assignment that
                -- fails when more than one row exists.
                SET @rtn =
                (
                        SELECT [task_version_value]
                        FROM [PDX_SCHEMA_TASKVER_META]
                        WHERE [task_version] = @task
                            AND [meta_tag] = UPPER(@p_parameter)
                            AND [task_source] = UPPER(@p_source)
                );
        END

    SELECT TOP (1) @rtn = [task_version_value]
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version] = @task
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source)
    ORDER BY [task_version_value];

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(40),
    @p_source VARCHAR(1)
)
RETURNS TABLE
AS
RETURN
(
    SELECT [task_version_value] AS [value]
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version] = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task)
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source)
);
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_by_val]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(40),
    @p_source VARCHAR(1)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @task VARCHAR(255) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task);
    DECLARE @cnt INT;
    DECLARE @rtn VARCHAR(255);

    SELECT @cnt = COUNT(*)
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version_value] = @task
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source);

    IF ISNULL(@cnt, 0) > 1
        BEGIN
                -- DBA IMPLEMENTATION NOTE:
                -- Same TOO_MANY_ROWS emulation pattern as get_metadata:
                -- scalar assignment intentionally errors if multiple rows are returned.
                SET @rtn =
                (
                        SELECT [task_version]
                        FROM [PDX_SCHEMA_TASKVER_META]
                        WHERE [task_version_value] = @task
                            AND [meta_tag] = UPPER(@p_parameter)
                            AND [task_source] = UPPER(@p_source)
                );
        END

    SELECT TOP (1) @rtn = [task_version]
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version_value] = @task
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source)
    ORDER BY [task_version];

    RETURN @rtn;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_metadata_tbl_by_val]
(
    @p_file_or_task VARCHAR(255),
    @p_parameter VARCHAR(40),
    @p_source VARCHAR(1)
)
RETURNS TABLE
AS
RETURN
(
    SELECT [task_version] AS [value]
    FROM [PDX_SCHEMA_TASKVER_META]
    WHERE [task_version_value] = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task)
      AND [meta_tag] = UPPER(@p_parameter)
      AND [task_source] = UPPER(@p_source)
);
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_delete_metadata]
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [pdx_schema_file_hash];
    DELETE FROM [PDX_SCHEMA_FILE_TASKVER];
    DELETE FROM [PDX_SCHEMA_TASKVER_META];

    EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_META_CAPTURED', 0;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_erase_obsolete_metadata]
AS
BEGIN
    SET NOCOUNT ON;

    -- Remove stale hash rows (A source)
    DELETE h
    FROM [pdx_schema_file_hash] h
    LEFT JOIN [pdx_schema_updater_sql] s ON s.[file_name] = h.[file_name]
    WHERE h.[file_source] = 'A'
      AND (s.[file_name] IS NULL OR h.[file_hash] <> ISNULL([SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash](CONVERT(NVARCHAR(MAX), s.[sql])), '0'));

    -- Remove stale hash rows (B source)
    DELETE h
    FROM [pdx_schema_file_hash] h
    LEFT JOIN [schema_updater_sql] s ON s.[file_name] = h.[file_name]
    WHERE h.[file_source] = 'B'
      AND (s.[file_name] IS NULL OR h.[file_hash] <> ISNULL([SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash](CONVERT(NVARCHAR(MAX), s.[sql])), '0'));

    -- Remove task/file rows for missing hashes
    DELETE ft
    FROM [PDX_SCHEMA_FILE_TASKVER] ft
    LEFT JOIN [pdx_schema_file_hash] h ON h.[file_name] = ft.[file_name]
    WHERE h.[file_name] IS NULL;

    -- Remove metadata for tasks no longer mapped
    DELETE m
    FROM [PDX_SCHEMA_TASKVER_META] m
    LEFT JOIN [PDX_SCHEMA_FILE_TASKVER] ft ON ft.[task_version] = m.[task_version]
    WHERE ft.[task_version] IS NULL;

    EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_META_CAPTURED', 0;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_filetask_map]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @prefix VARCHAR(50);
    SELECT TOP (1) @prefix = LOWER(CONVERT(VARCHAR(50), [value]))
    FROM [pdx_schema_config]
    WHERE [key] = 'APPLICATIONPREFIX';

    ;WITH source_rows AS
    (
        SELECT s.[file_name], CONVERT(NVARCHAR(MAX), s.[sql]) AS [ddl]
        FROM [pdx_schema_updater_sql] s
        UNION ALL
        SELECT s.[file_name], CONVERT(NVARCHAR(MAX), s.[sql]) AS [ddl]
        FROM [schema_updater_sql] s
    ),
    parsed AS
    (
        SELECT
            r.[file_name],
            CASE
                WHEN UPPER(r.[ddl]) LIKE '%-- RELEASEFILE:%' OR UPPER(r.[ddl]) LIKE '%-- RELEASEREF:%' THEN 'R'
                WHEN UPPER(r.[ddl]) LIKE '%-- TASKFILE:%' OR UPPER(r.[ddl]) LIKE '%-- TASKREF:%' THEN 'T'
                ELSE 'O'
            END AS [file_type],
            CASE
                WHEN @prefix IS NOT NULL
                     AND CHARINDEX(LOWER(@prefix) + '_', LOWER(r.[file_name])) > 0
                     AND CHARINDEX('_ddl.sql', LOWER(r.[file_name])) > 0
                THEN UPPER(SUBSTRING(
                       r.[file_name],
                       CHARINDEX(LOWER(@prefix) + '_', LOWER(r.[file_name])) + LEN(@prefix) + 1,
                       CHARINDEX('_ddl.sql', LOWER(r.[file_name])) - (CHARINDEX(LOWER(@prefix) + '_', LOWER(r.[file_name])) + LEN(@prefix) + 1)
                ))
                ELSE NULL
            END AS [task_version]
        FROM source_rows r
    )
    INSERT INTO [PDX_SCHEMA_FILE_TASKVER]([file_name], [task_version], [file_type])
    SELECT p.[file_name], p.[task_version], MIN(p.[file_type])
    FROM parsed p
    LEFT JOIN [PDX_SCHEMA_FILE_TASKVER] ft ON ft.[file_name] = p.[file_name]
    WHERE p.[task_version] IS NOT NULL
      AND ft.[file_name] IS NULL
    GROUP BY p.[file_name], p.[task_version];
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source]
    @p_source CHAR(1),
    @p_task VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @src TABLE
    (
        [file_name] VARCHAR(255),
        [ddl] NVARCHAR(MAX),
        [task_version] VARCHAR(255),
        [file_type] VARCHAR(1)
    );

    IF @p_source = 'A'
    BEGIN
        INSERT INTO @src([file_name], [ddl], [task_version], [file_type])
        SELECT v.[file_name], CONVERT(NVARCHAR(MAX), s.[sql]), v.[task_version], v.[file_type]
        FROM [pdx_schema_updater_sql] s
        INNER JOIN [PDX_SCHEMA_FILE_TASKVER] v ON v.[file_name] = s.[file_name]
        LEFT JOIN [pdx_schema_file_hash] h ON h.[file_name] = s.[file_name] AND h.[file_source] = 'A'
        WHERE (@p_task IS NULL OR v.[task_version] = @p_task)
          AND (@p_task IS NOT NULL OR h.[file_hash] IS NULL);
    END
    ELSE
    BEGIN
        INSERT INTO @src([file_name], [ddl], [task_version], [file_type])
        SELECT v.[file_name], CONVERT(NVARCHAR(MAX), s.[sql]), v.[task_version], v.[file_type]
        FROM [schema_updater_sql] s
        INNER JOIN [PDX_SCHEMA_FILE_TASKVER] v ON v.[file_name] = s.[file_name]
        LEFT JOIN [pdx_schema_file_hash] h ON h.[file_name] = s.[file_name] AND h.[file_source] = 'B'
        WHERE (@p_task IS NULL OR v.[task_version] = @p_task)
          AND h.[file_hash] IS NULL;
    END

    IF @p_task IS NOT NULL
    BEGIN
        DELETE FROM [pdx_schema_file_hash] WHERE [file_source] = @p_source AND [file_name] IN (SELECT [file_name] FROM @src);
        DELETE FROM [PDX_SCHEMA_TASKVER_META] WHERE [task_source] = @p_source AND [task_version] = @p_task;
    END

    DECLARE @file_name VARCHAR(255);
    DECLARE @ddl NVARCHAR(MAX);
    DECLARE @task_version VARCHAR(255);
    DECLARE @file_type VARCHAR(1);

    DECLARE src_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT [file_name], [ddl], [task_version], [file_type] FROM @src;

    OPEN src_cur;
    FETCH NEXT FROM src_cur INTO @file_name, @ddl, @task_version, @file_type;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @lines TABLE ([line] NVARCHAR(MAX));
        INSERT INTO @lines([line])
        SELECT LTRIM(RTRIM([value]))
        FROM STRING_SPLIT(REPLACE(REPLACE(ISNULL(@ddl, N''), CHAR(13), N''), CHAR(9), N' '), CHAR(10))
        WHERE LTRIM(RTRIM([value])) <> N'';

        DECLARE @tags TABLE ([tag] VARCHAR(30));
        INSERT INTO @tags([tag]) VALUES
            ('HASHKEY'), ('REQUIRES'), ('ROLLBACK'), ('DEPRECATES'), ('TASKTYPE'), ('ATTRIBCHECK'), ('APPLYSPRINT'), ('APPLYIF'), ('EXCLUDEIF');

        DECLARE @tag VARCHAR(30);
        DECLARE tag_cur CURSOR LOCAL FAST_FORWARD FOR SELECT [tag] FROM @tags;

        OPEN tag_cur;
        FETCH NEXT FROM tag_cur INTO @tag;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @meta_value NVARCHAR(MAX);
            DECLARE @prefix NVARCHAR(40) = N'-- ' + @tag + N':';

            DECLARE line_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [line] FROM @lines WHERE UPPER([line]) LIKE UPPER(@prefix) + N'%';

            DECLARE @line NVARCHAR(MAX);
            OPEN line_cur;
            FETCH NEXT FROM line_cur INTO @line;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @meta_value = LTRIM(RTRIM(SUBSTRING(@line, LEN(@prefix) + 1, 4000)));

                IF @tag = 'ATTRIBCHECK'
                BEGIN
                    IF ISNULL(@meta_value, N'') = N''
                        THROW 50011, 'ATTRIBCHECK for task is missing value in source SQL', 1;

                    INSERT INTO [PDX_SCHEMA_TASKVER_META]([task_version], [meta_tag], [task_version_value], [task_source])
                    VALUES (@task_version, @tag, @meta_value, @p_source);
                END
                ELSE
                BEGIN
                    IF ISNULL(@meta_value, N'') = N''
                        THROW 50011, 'Metadata tag has empty or invalid value in source SQL', 1;

                    ;WITH vals AS
                    (
                        SELECT LTRIM(RTRIM([value])) AS v
                        FROM STRING_SPLIT(@meta_value, ',')
                    )
                    INSERT INTO [PDX_SCHEMA_TASKVER_META]([task_version], [meta_tag], [task_version_value], [task_source])
                    SELECT @task_version, @tag, v, @p_source
                    FROM vals
                    WHERE v <> '';
                END

                FETCH NEXT FROM line_cur INTO @line;
            END
            CLOSE line_cur;
            DEALLOCATE line_cur;

            FETCH NEXT FROM tag_cur INTO @tag;
        END
        CLOSE tag_cur;
        DEALLOCATE tag_cur;

        IF @file_type = 'R'
        BEGIN
            DECLARE release_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [line] FROM @lines WHERE [line] LIKE '--@%';

            OPEN release_cur;
            FETCH NEXT FROM release_cur INTO @line;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @ref VARCHAR(255) = LTRIM(RTRIM(REPLACE(REPLACE(SUBSTRING(@line, 4, 4000), '_ddl.sql', ''), '_ddl', '')));
                DECLARE @ref_task VARCHAR(255) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@ref);

                IF @ref_task IS NULL
                    THROW 50011, 'Unable to resolve RELEASETASK reference. Ensure referenced task file metadata exists.', 1;

                INSERT INTO [PDX_SCHEMA_TASKVER_META]([task_version], [meta_tag], [task_version_value], [task_source])
                VALUES (@task_version, 'RELEASETASK', @ref_task, @p_source);

                FETCH NEXT FROM release_cur INTO @line;
            END
            CLOSE release_cur;
            DEALLOCATE release_cur;
        END

        INSERT INTO [pdx_schema_file_hash]([file_name], [file_source], [file_hash])
        VALUES (@file_name, @p_source, [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash](@ddl));

        FETCH NEXT FROM src_cur INTO @file_name, @ddl, @task_version, @file_type;
    END

    CLOSE src_cur;
    DEALLOCATE src_cur;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_task_tbl_exists]
(
    @parm1 VARCHAR(255),
    @parm2 VARCHAR(1),
    @parm3 VARCHAR(40)
)
RETURNS BIT
AS
BEGIN
    DECLARE @exists BIT = 0;

    IF EXISTS
    (
        SELECT 1
        FROM [PDX_SCHEMA_TASKVER_META]
        WHERE [task_version] = @parm1
          AND [task_source] = @parm2
          AND [meta_tag] = @parm3
    )
        SET @exists = 1;

    RETURN @exists;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_apply_pvt]
    @p_task VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source]
        @p_source = 'A',
        @p_task = @p_task;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_build]
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source]
        @p_source = 'B',
        @p_task = NULL;
END;
GO

CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_validate_metadata]()
RETURNS BIT
AS
BEGIN
    DECLARE @cnt INT;
    DECLARE @ok BIT = 1;

    SELECT @cnt = COUNT(*)
    FROM [pdx_schema_file_hash] h
    FULL OUTER JOIN [pdx_schema_updater_sql] s ON s.[file_name] = h.[file_name]
    WHERE h.[file_source] = 'A'
      AND ISNULL(h.[file_hash], '0') <> ISNULL([SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash](CONVERT(NVARCHAR(MAX), s.[sql])), '0');

    IF ISNULL(@cnt, 0) > 0
        SET @ok = 0;

    IF @ok = 1
    BEGIN
        SELECT @cnt = COUNT(*)
        FROM [pdx_schema_file_hash] h
        FULL OUTER JOIN [schema_updater_sql] s ON s.[file_name] = h.[file_name]
        WHERE h.[file_source] = 'B'
          AND ISNULL(h.[file_hash], '0') <> ISNULL([SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_meta_hash](CONVERT(NVARCHAR(MAX), s.[sql])), '0');

        IF ISNULL(@cnt, 0) > 0
            SET @ok = 0;
    END

    RETURN @ok;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata]
AS
BEGIN
    SET NOCOUNT ON;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_erase_obsolete_metadata];
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_filetask_map];
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source] @p_source = 'A', @p_task = NULL;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source] @p_source = 'B', @p_task = NULL;

    EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_META_CAPTURED', 1;

    IF [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_validate_metadata]() = 0
        THROW 50010, 'Metadata is out of sync. Execute PKG_PDX_SCHEMA_UPDATER_META_delete_metadata and re-run read_metadata.', 1;
END;
GO

CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_refresh_metadata_apply]
    @p_file_or_task VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_META_CAPTURED'), 0)) = 0
        THROW 50010, 'read_metadata must be executed before refresh_metadata_apply.', 1;

    DECLARE @task VARCHAR(255) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_get_taskname](@p_file_or_task);

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_META_read_metadata_parse_source] @p_source = 'A', @p_task = @task;
END;
GO
