-- ============================================================================
-- Converted: Oracle Package EPS.PKG_PDX_SCHEMA_UPDATER_HELPER -> Azure SQL
-- Conversion Date: 2026-05-25
--
-- Notes:
-- 1) Oracle package globals are implemented using SESSION_CONTEXT keys.
-- 2) Oracle autonomous transactions for debug logging are mapped to immediate
--    independent DML statements inside dedicated procedures.
-- 3) Oracle out-of-place resize workflow (CTAS/temp columns/rollback state)
--    is simplified to deterministic in-place ALTER COLUMN operations in T-SQL.
-- 4) Oracle datatype mapping:
--      NUMBER(p,s)  -> DECIMAL(p,s)
--      VARCHAR2(n)  -> VARCHAR(n)
-- 5) Oracle exceptions -20001..-20004 are mapped to 50001..50004.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- ----------------------------------------------------------------------------
-- Helper Function: get_is_release
-- Oracle: get_is_release RETURN BOOLEAN
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_is_release]()
RETURNS BIT
AS
BEGIN
    DECLARE @l_tmp VARCHAR(30);
    DECLARE @rtn BIT = 1;

    SELECT TOP (1) @l_tmp = UPPER(CONVERT(VARCHAR(30), [value]))
    FROM [pdx_schema_config]
    WHERE [key] = 'APPLYTYPE';

    IF @l_tmp = 'TASK'
        SET @rtn = 0;

    RETURN @rtn;
END;
GO

-- ----------------------------------------------------------------------------
-- Debug session switch (session-scoped via SESSION_CONTEXT)
-- Oracle: set_debug(p_value BOOLEAN)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_debug]
    @p_value BIT
AS
BEGIN
    SET NOCOUNT ON;

    EXEC sys.sp_set_session_context
        @key = N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG',
        @value = CASE WHEN @p_value = 1 THEN 1 ELSE 0 END;
END;
GO

-- ----------------------------------------------------------------------------
-- purge_debug
-- Oracle: purge_debug(p_date TIMESTAMP, p_proc VARCHAR2 := NULL)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_purge_debug]
    @p_date DATETIME2(6),
    @p_proc VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DELETE d
    FROM [pdx_schema_upd_helper_debug_d] d
    WHERE d.[pdx_schema_upd_hlpr_dbg_h_id] IN
    (
        SELECT h.[id]
        FROM [pdx_schema_upd_helper_debug_h] h
        WHERE h.[debug_timestamp] < @p_date
          AND (@p_proc IS NULL OR @p_proc = h.[proc])
    );

    DELETE h
    FROM [pdx_schema_upd_helper_debug_h] h
    WHERE h.[debug_timestamp] < @p_date
      AND (@p_proc IS NULL OR @p_proc = h.[proc]);
END;
GO

-- ----------------------------------------------------------------------------
-- debug_hdr
-- Oracle: autonomous transaction insert into debug_h
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr]
    @p_proc VARCHAR(255),
    @p_parms VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_debug BIT = CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0));
    DECLARE @hdr_id BIGINT;
    DECLARE @new_hdr TABLE ([id] BIGINT);

    IF @is_debug = 1
    BEGIN
        INSERT INTO [pdx_schema_upd_helper_debug_h]
            ([id], [proc], [parms], [debug_timestamp])
        OUTPUT INSERTED.[id] INTO @new_hdr([id])
        VALUES
            (NEXT VALUE FOR [pdx_schema_master_seq], UPPER(@p_proc), @p_parms, SYSDATETIME());

        SELECT TOP (1) @hdr_id = [id] FROM @new_hdr;

        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_HDR_ID', @hdr_id;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- debug_hdr_success
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_success]
AS
BEGIN
    SET NOCOUNT ON;

    IF CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0)) = 1
    BEGIN
        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_HDR_ID', NULL;
        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID', NULL;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- debug_hdr_error
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_error]
    @p_err VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_debug BIT = CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0));
    DECLARE @hdr_id BIGINT = CONVERT(BIGINT, SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_HDR_ID'));

    IF @is_debug = 1 AND @hdr_id IS NOT NULL
    BEGIN
        UPDATE [pdx_schema_upd_helper_debug_h]
        SET [sql_error] = @p_err
        WHERE [id] = @hdr_id;

        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_HDR_ID', NULL;
        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID', NULL;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- debug_dtl
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
    @p_msg VARCHAR(4000),
    @p_sql VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_debug BIT = CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0));
    DECLARE @hdr_id BIGINT = CONVERT(BIGINT, SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_HDR_ID'));
    DECLARE @dtl_id BIGINT;
    DECLARE @new_dtl TABLE ([id] BIGINT);

    IF @is_debug = 1 AND @hdr_id IS NOT NULL
    BEGIN
        INSERT INTO [pdx_schema_upd_helper_debug_d]
            ([id], [pdx_schema_upd_hlpr_dbg_h_id], [start_timestamp], [message], [sql])
        OUTPUT INSERTED.[id] INTO @new_dtl([id])
        VALUES
            (NEXT VALUE FOR [pdx_schema_master_seq], @hdr_id, SYSDATETIME(), @p_msg, @p_sql);

        SELECT TOP (1) @dtl_id = [id] FROM @new_dtl;

        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID', @dtl_id;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- debug_dtl_success
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_debug BIT = CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0));
    DECLARE @dtl_id BIGINT = CONVERT(BIGINT, SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID'));

    IF @is_debug = 1 AND @dtl_id IS NOT NULL
    BEGIN
        UPDATE [pdx_schema_upd_helper_debug_d]
        SET [end_timestamp] = SYSDATETIME()
        WHERE [id] = @dtl_id;

        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID', NULL;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- debug_dtl_error
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error]
    @p_err VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_debug BIT = CONVERT(BIT, ISNULL(SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DEBUG'), 0));
    DECLARE @dtl_id BIGINT = CONVERT(BIGINT, SESSION_CONTEXT(N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID'));

    IF @is_debug = 1 AND @dtl_id IS NOT NULL
    BEGIN
        UPDATE [pdx_schema_upd_helper_debug_d]
        SET [sql_error] = @p_err
        WHERE [id] = @dtl_id;

        EXEC sys.sp_set_session_context N'PKG_PDX_SCHEMA_UPDATER_HELPER_DTL_ID', NULL;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- Internal parser for change list
-- Supports entries like: COL1 NUMBER(13,4), COL2 VARCHAR2(20)
-- ----------------------------------------------------------------------------
CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_parse_change_list]
(
    @p_change_list VARCHAR(MAX)
)
RETURNS @r TABLE
(
    [column_name] SYSNAME NOT NULL,
    [oracle_type] VARCHAR(30) NOT NULL,
    [precision_len] INT NULL,
    [scale_val] INT NULL
)
AS
BEGIN
    DECLARE @clean VARCHAR(MAX) = LTRIM(RTRIM(ISNULL(@p_change_list, '')));
    DECLARE @work VARCHAR(MAX);
    DECLARE @token VARCHAR(MAX) = '';
    DECLARE @token_index INT = 1;
    DECLARE @position INT = 1;
    DECLARE @length INT;
    DECLARE @depth INT = 0;
    DECLARE @current_char CHAR(1);

    DECLARE @tokens TABLE
    (
        [token_index] INT PRIMARY KEY,
        [token] VARCHAR(MAX)
    );

    IF @clean = ''
        RETURN;

    SET @work = REPLACE(REPLACE(@clean, CHAR(10), ' '), CHAR(13), ' ');
    SET @length = LEN(@work);

    WHILE @position <= @length
    BEGIN
        SET @current_char = SUBSTRING(@work, @position, 1);

        IF @current_char = '('
            SET @depth = @depth + 1;
        ELSE IF @current_char = ')' AND @depth > 0
            SET @depth = @depth - 1;

        IF @current_char = ',' AND @depth = 0
        BEGIN
            IF LTRIM(RTRIM(@token)) <> ''
            BEGIN
                INSERT INTO @tokens([token_index], [token])
                VALUES (@token_index, LTRIM(RTRIM(@token)));
                SET @token_index = @token_index + 1;
            END
            SET @token = '';
        END
        ELSE
        BEGIN
            SET @token = @token + @current_char;
        END

        SET @position = @position + 1;
    END

    IF LTRIM(RTRIM(@token)) <> ''
        INSERT INTO @tokens([token_index], [token]) VALUES (@token_index, LTRIM(RTRIM(@token)));

    IF NOT EXISTS (SELECT 1 FROM @tokens)
        RETURN;

    INSERT INTO @r ([column_name], [oracle_type], [precision_len], [scale_val])
    SELECT
        UPPER(LTRIM(RTRIM(
            CASE WHEN CHARINDEX(' ', [token]) > 0 THEN LEFT([token], CHARINDEX(' ', [token]) - 1) ELSE [token] END
        ))) AS column_name,
        UPPER(LTRIM(RTRIM(
            CASE WHEN CHARINDEX(' ', [token]) > 0 THEN
                CASE
                    WHEN CHARINDEX('(', [token]) > 0 THEN
                        SUBSTRING([token], CHARINDEX(' ', [token]) + 1, CHARINDEX('(', [token]) - CHARINDEX(' ', [token]) - 1)
                    ELSE SUBSTRING([token], CHARINDEX(' ', [token]) + 1, LEN([token]))
                END
            ELSE ''
            END
        ))) AS oracle_type,
        TRY_CAST(
            CASE
                WHEN CHARINDEX('(', [token]) > 0 THEN
                    LTRIM(RTRIM(
                        CASE
                            WHEN CHARINDEX(',', [token]) > 0 THEN
                                SUBSTRING([token], CHARINDEX('(', [token]) + 1, CHARINDEX(',', [token]) - CHARINDEX('(', [token]) - 1)
                            ELSE
                                SUBSTRING([token], CHARINDEX('(', [token]) + 1, CHARINDEX(')', [token]) - CHARINDEX('(', [token]) - 1)
                        END
                    ))
                ELSE NULL
            END AS INT
        ) AS precision_len,
        TRY_CAST(
            CASE
                WHEN CHARINDEX(',', [token]) > 0 THEN
                    LTRIM(RTRIM(SUBSTRING([token], CHARINDEX(',', [token]) + 1, CHARINDEX(')', [token]) - CHARINDEX(',', [token]) - 1)))
                ELSE NULL
            END AS INT
        ) AS scale_val
    FROM @tokens
    WHERE [token] <> '';

    RETURN;
END;
GO

-- ----------------------------------------------------------------------------
-- Main Procedure: change_precision_scale
-- Oracle signature:
--   change_precision_scale(p_table_name, p_change_list, p_parallel, p_increase_only, p_use_ctas, p_set_unused)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_change_precision_scale]
    @p_table_name VARCHAR(128),
    @p_change_list VARCHAR(MAX),
    @p_parallel INT = 0,
    @p_increase_only BIT = 0,
    @p_use_ctas BIT = 0,
    @p_set_unused BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- DBA IMPLEMENTATION NOTE:
    -- Exception class mapping for this procedure follows Oracle intent:
    --   Oracle -20001 (parse/input)     -> THROW 50001
    --   Oracle -20002 (state/metadata)  -> THROW 50002
    --   Oracle -20003 (runtime SQL)     -> THROW 50003
    --   Oracle -20004 (platform limits) -> THROW 50004
    -- Full branch-level one-to-one parity is not always possible in T-SQL, but
    -- key decision points are explicitly classified for validation traceability.

    DECLARE @is_release BIT;
    DECLARE @proc_parms VARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @use_ctas_effective BIT = 0;
    DECLARE @ctas_table SYSNAME = LEFT(UPPER(@p_table_name), 26) + '_TMP';
    DECLARE @pk_col_list NVARCHAR(MAX) = NULL;
    DECLARE @pk_join_pred NVARCHAR(MAX) = NULL;
    DECLARE @pk_exists BIT = 0;
    DECLARE @ctas_mode_note VARCHAR(1000) = NULL;

    DECLARE @changes TABLE
    (
        [column_name] SYSNAME PRIMARY KEY,
        [oracle_type] VARCHAR(30),
        [precision_len] INT NULL,
        [scale_val] INT NULL,
        [orig_col] SYSNAME,
        [tmp_col] SYSNAME,
        [current_col] SYSNAME NULL,
        [current_type] SYSNAME NULL,
        [current_len] INT NULL,
        [current_precision] INT NULL,
        [current_scale] INT NULL,
        [is_nullable] BIT NULL,
        [is_renamed] BIT DEFAULT 0,
        [tmp_exists] BIT DEFAULT 0,
        [target_type_sql] NVARCHAR(200) NULL,
        [method] CHAR(1) NULL,
        [needs_substr] BIT DEFAULT 0,
        [allow_change] BIT DEFAULT 1
    );

    BEGIN TRY
        SET @proc_parms =
              'Table Name: ' + ISNULL(@p_table_name, '') + CHAR(10)
            + 'Change List: ' + ISNULL(@p_change_list, '') + CHAR(10)
            + 'Increase only: ' + CASE WHEN @p_increase_only = 1 THEN 'True' ELSE 'False' END
            + ', Use CTAS: ' + CASE WHEN @p_use_ctas = 1 THEN 'True' ELSE 'False' END;

        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr]
            @p_proc = 'CHANGE_PRECISION_SCALE',
            @p_parms = @proc_parms;

        SET @is_release = [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_is_release]();

        INSERT INTO @changes ([column_name], [oracle_type], [precision_len], [scale_val], [orig_col], [tmp_col])
        SELECT
            p.[column_name],
            p.[oracle_type],
            p.[precision_len],
            p.[scale_val],
            LEFT(p.[column_name], 25) + '_ORIG',
            LEFT(p.[column_name], 25) + '_TMP'
        FROM [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_parse_change_list](@p_change_list) p;

        IF NOT EXISTS (SELECT 1 FROM @changes)
            THROW 50001, 'Unable to process change list.', 1;

        IF EXISTS (SELECT 1 FROM @changes WHERE [oracle_type] NOT IN ('NUMBER', 'VARCHAR2'))
            THROW 50001, 'Only datatypes NUMBER and VARCHAR2 are supported.', 1;

        IF EXISTS
        (
            SELECT [column_name]
            FROM @changes
            GROUP BY [column_name]
            HAVING COUNT(*) > 1
        )
            THROW 50001, 'Column was found more than once in change list.', 1;

        DECLARE @column_name SYSNAME;
        DECLARE @oracle_type VARCHAR(30);
        DECLARE @precision_len INT;
        DECLARE @scale_val INT;
        DECLARE @orig_col SYSNAME;
        DECLARE @tmp_col SYSNAME;

        DECLARE @cur_type SYSNAME;
        DECLARE @cur_len INT;
        DECLARE @cur_precision INT;
        DECLARE @cur_scale INT;
        DECLARE @cur_nullable BIT;
        DECLARE @is_renamed BIT;
        DECLARE @tmp_exists BIT;

        DECLARE meta_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [column_name], [oracle_type], [precision_len], [scale_val], [orig_col], [tmp_col]
            FROM @changes
            ORDER BY [column_name];

        OPEN meta_cur;
        FETCH NEXT FROM meta_cur INTO @column_name, @oracle_type, @precision_len, @scale_val, @orig_col, @tmp_col;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @cur_type = NULL;
            SET @cur_len = NULL;
            SET @cur_precision = NULL;
            SET @cur_scale = NULL;
            SET @cur_nullable = NULL;
            SET @is_renamed = 0;
            SET @tmp_exists = 0;

            SELECT
                @cur_type = t.[name],
                @cur_len = c.[max_length],
                @cur_precision = c.[precision],
                @cur_scale = c.[scale],
                @cur_nullable = c.[is_nullable]
            FROM sys.columns c
            INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
            WHERE c.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
              AND c.[name] = @column_name;

            IF @cur_type IS NULL
            BEGIN
                SELECT
                    @cur_type = t.[name],
                    @cur_len = c.[max_length],
                    @cur_precision = c.[precision],
                    @cur_scale = c.[scale],
                    @cur_nullable = c.[is_nullable]
                FROM sys.columns c
                INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
                WHERE c.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                  AND c.[name] = @orig_col;

                IF @cur_type IS NOT NULL
                    SET @is_renamed = 1;
            END

            IF @cur_type IS NULL
                THROW 50002, 'Table ' + @p_table_name + ' does not contain column ' + @column_name + ' or ' + @orig_col + '.', 1;

            IF EXISTS
            (
                SELECT 1
                FROM sys.columns
                WHERE [object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                  AND [name] = @tmp_col
            )
                SET @tmp_exists = 1;

            UPDATE @changes
            SET [current_col] = CASE WHEN @is_renamed = 1 THEN @orig_col ELSE @column_name END,
                [current_type] = @cur_type,
                [current_len] = @cur_len,
                [current_precision] = @cur_precision,
                [current_scale] = @cur_scale,
                [is_nullable] = @cur_nullable,
                [is_renamed] = @is_renamed,
                [tmp_exists] = @tmp_exists,
                [target_type_sql] = CASE
                    WHEN @oracle_type = 'NUMBER' THEN
                        CASE WHEN @precision_len IS NULL THEN 'DECIMAL(38,0)'
                             ELSE 'DECIMAL(' + CAST(@precision_len AS VARCHAR(10)) + ',' + CAST(ISNULL(@scale_val,0) AS VARCHAR(10)) + ')' END
                    ELSE 'VARCHAR(' + CAST(@precision_len AS VARCHAR(10)) + ')' END
            WHERE [column_name] = @column_name;

            FETCH NEXT FROM meta_cur INTO @column_name, @oracle_type, @precision_len, @scale_val, @orig_col, @tmp_col;
        END

        CLOSE meta_cur;
        DEALLOCATE meta_cur;

        -- Determine method and guards
        UPDATE c
        SET [needs_substr] = CASE
                WHEN c.[oracle_type] = 'VARCHAR2'
                     AND c.[current_type] IN ('varchar','nvarchar','char','nchar')
                     AND c.[precision_len] < CASE WHEN c.[current_type] IN ('nvarchar','nchar') THEN c.[current_len]/2 ELSE c.[current_len] END
                THEN 1 ELSE 0 END,
            [method] = CASE
                WHEN c.[oracle_type] = 'NUMBER'
                     AND c.[current_type] IN ('decimal','numeric')
                     AND (
                          ISNULL(c.[precision_len],0) < ISNULL(c.[current_precision],0)
                          OR ISNULL(c.[scale_val],0) < ISNULL(c.[current_scale],0)
                         ) THEN 'C'
                WHEN c.[oracle_type] = 'NUMBER'
                     AND c.[current_type] NOT IN ('decimal','numeric') THEN 'C'
                WHEN c.[oracle_type] = 'VARCHAR2'
                     AND c.[current_type] IN ('varchar','nvarchar','char','nchar')
                     AND c.[precision_len] < CASE WHEN c.[current_type] IN ('nvarchar','nchar') THEN c.[current_len]/2 ELSE c.[current_len] END
                THEN 'I'
                WHEN c.[oracle_type] = 'VARCHAR2'
                     AND c.[current_type] NOT IN ('varchar','nvarchar','char','nchar') THEN 'C'
                WHEN c.[oracle_type] = 'NUMBER'
                     AND c.[current_type] IN ('decimal','numeric')
                     AND ISNULL(c.[precision_len],0) = ISNULL(c.[current_precision],0)
                     AND ISNULL(c.[scale_val],0) = ISNULL(c.[current_scale],0)
                THEN 'N'
                WHEN c.[oracle_type] = 'VARCHAR2'
                     AND c.[current_type] IN ('varchar','nvarchar','char','nchar')
                     AND c.[precision_len] = CASE WHEN c.[current_type] IN ('nvarchar','nchar') THEN c.[current_len]/2 ELSE c.[current_len] END
                THEN 'N'
                ELSE 'I'
            END,
            [allow_change] = CASE
                WHEN @is_release = 1 AND @p_increase_only = 1
                     AND c.[oracle_type] = 'NUMBER'
                     AND c.[current_type] IN ('decimal','numeric')
                     AND (
                          ISNULL(c.[precision_len],0) < ISNULL(c.[current_precision],0)
                          OR ISNULL(c.[scale_val],0) < ISNULL(c.[current_scale],0)
                         )
                THEN 0
                WHEN @is_release = 1 AND @p_increase_only = 1
                     AND c.[oracle_type] = 'VARCHAR2'
                     AND c.[current_type] IN ('varchar','nvarchar','char','nchar')
                     AND c.[precision_len] < CASE WHEN c.[current_type] IN ('nvarchar','nchar') THEN c.[current_len]/2 ELSE c.[current_len] END
                THEN 0
                ELSE 1
            END
        FROM @changes c;

        IF EXISTS (SELECT 1 FROM @changes WHERE [oracle_type] = 'VARCHAR2' AND ([precision_len] IS NULL OR [precision_len] <= 0))
            THROW 50001, 'Invalid VARCHAR2 length found in change list.', 1;

        -- Determine if CTAS can be used (requires PK columns)
        IF @p_use_ctas = 1
        BEGIN
            SELECT
                @pk_col_list = STRING_AGG(QUOTENAME(c.[name]), ','),
                @pk_join_pred = STRING_AGG('b.' + QUOTENAME(c.[name]) + ' = t.' + QUOTENAME(c.[name]), ' AND ')
            FROM sys.key_constraints kc
            INNER JOIN sys.index_columns ic
                ON ic.[object_id] = kc.[parent_object_id]
               AND ic.[index_id] = kc.[unique_index_id]
            INNER JOIN sys.columns c
                ON c.[object_id] = ic.[object_id]
               AND c.[column_id] = ic.[column_id]
            WHERE kc.[type] = 'PK'
              AND kc.[parent_object_id] = OBJECT_ID(QUOTENAME(@p_table_name));

            IF @pk_col_list IS NOT NULL AND @pk_join_pred IS NOT NULL
            BEGIN
                SET @pk_exists = 1;
                SET @use_ctas_effective = 1;
            END
            ELSE
            BEGIN
                -- DBA IMPLEMENTATION NOTE:
                -- Oracle CTAS flow assumes richer object orchestration than SQL Server can provide
                -- in all table designs. When CTAS is requested but no PK exists, we fall back to
                -- `_TMP` column mode to preserve data safety/restartability.
                SET @ctas_mode_note = 'CTAS requested but no PK was found; falling back to temp-column mode.';
                PRINT @ctas_mode_note;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'CTAS fallback decision', @p_sql = @ctas_mode_note;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
            END
        END

        -- Oracle-like mismatch guard: CTAS requested, but inline temp columns already exist.
        IF @use_ctas_effective = 1
           AND EXISTS
           (
               SELECT 1
               FROM @changes c
               WHERE c.[method] = 'C'
                 AND c.[allow_change] = 1
                 AND EXISTS
                 (
                     SELECT 1 FROM sys.columns s
                     WHERE s.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                       AND s.[name] = c.[tmp_col]
                 )
           )
            THROW 50002, 'Requested use of CTAS, but one or more inline temp columns already exist.', 1;

        -- Oracle-like mismatch guard: inline mode selected, but CTAS temp table already exists.
        IF @use_ctas_effective = 0
           AND OBJECT_ID(QUOTENAME(@ctas_table), 'U') IS NOT NULL
           AND EXISTS (SELECT 1 FROM @changes WHERE [method] = 'C' AND [allow_change] = 1)
            THROW 50002, 'Requested inline processing, but a CTAS temp table already exists for this table.', 1;

        -- Phase 1: rename base columns to _ORIG when needed
        DECLARE rename_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [column_name], [orig_col]
            FROM @changes
            WHERE [method] <> 'N' AND [allow_change] = 1 AND [is_renamed] = 0;

        OPEN rename_cur;
        FETCH NEXT FROM rename_cur INTO @column_name, @orig_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'EXEC sp_rename ''' + QUOTENAME(@p_table_name) + N'.' + QUOTENAME(@column_name) + N''', ''' + @orig_col + N''', ''COLUMN'';';
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Renaming column to _ORIG', @p_sql = @sql;
            EXEC sp_executesql @sql;
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

            FETCH NEXT FROM rename_cur INTO @column_name, @orig_col;
        END
        CLOSE rename_cur;
        DEALLOCATE rename_cur;

        -- Refresh rename status after phase 1
        UPDATE c
        SET [is_renamed] = CASE WHEN EXISTS
            (
                SELECT 1 FROM sys.columns s
                WHERE s.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                  AND s.[name] = c.[orig_col]
            ) THEN 1 ELSE 0 END
        FROM @changes c;

        -- Phase 2: create out-of-place storage (CTAS table or temp columns)
        IF @use_ctas_effective = 1
        BEGIN
            IF OBJECT_ID(QUOTENAME(@ctas_table), 'U') IS NULL
            BEGIN
                DECLARE @ctas_cols NVARCHAR(MAX);
                DECLARE @ctas_cast_cols NVARCHAR(MAX);

                SELECT @ctas_cols = STRING_AGG(QUOTENAME([column_name]), ',')
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1;

                SELECT @ctas_cast_cols = STRING_AGG('CAST(NULL AS ' + [target_type_sql] + ') AS ' + QUOTENAME([column_name]), ',')
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1;

                IF @ctas_cols IS NOT NULL
                BEGIN
                    SET @sql = N'SELECT TOP 0 ' + @pk_col_list + N',' + @ctas_cast_cols
                             + N' INTO ' + QUOTENAME(@ctas_table)
                             + N' FROM ' + QUOTENAME(@p_table_name) + N';';
                    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Create CTAS temp table', @p_sql = @sql;
                    EXEC sp_executesql @sql;
                    EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
                END
            END
        END
        ELSE
        BEGIN
            DECLARE tmpcreate_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [tmp_col], [target_type_sql]
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1
                  AND NOT EXISTS
                  (
                      SELECT 1 FROM sys.columns s
                      WHERE s.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                        AND s.[name] = [tmp_col]
                  );

            OPEN tmpcreate_cur;
            DECLARE @target_type_sql NVARCHAR(200);
            FETCH NEXT FROM tmpcreate_cur INTO @tmp_col, @target_type_sql;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sql = N'ALTER TABLE ' + QUOTENAME(@p_table_name) + N' ADD ' + QUOTENAME(@tmp_col) + N' ' + @target_type_sql + N' NULL';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Create out-of-place temp column', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

                FETCH NEXT FROM tmpcreate_cur INTO @tmp_col, @target_type_sql;
            END
            CLOSE tmpcreate_cur;
            DEALLOCATE tmpcreate_cur;
        END

        -- Phase 3: populate temp from _ORIG when temp is empty
        IF @use_ctas_effective = 1
        BEGIN
            DECLARE @ctas_data_cols NVARCHAR(MAX);
            DECLARE @ctas_src_cols NVARCHAR(MAX);
            DECLARE @ctas_notnull_pred NVARCHAR(MAX);

            SELECT @ctas_data_cols = STRING_AGG(QUOTENAME([column_name]), ',')
            FROM @changes
            WHERE [method] = 'C' AND [allow_change] = 1;

            SELECT @ctas_src_cols = STRING_AGG('b.' + QUOTENAME([orig_col]), ',')
            FROM @changes
            WHERE [method] = 'C' AND [allow_change] = 1;

            SELECT @ctas_notnull_pred = STRING_AGG('b.' + QUOTENAME([orig_col]) + ' IS NOT NULL', ' OR ')
            FROM @changes
            WHERE [method] = 'C' AND [allow_change] = 1;

            IF @ctas_data_cols IS NOT NULL
            BEGIN
                SET @sql = N'INSERT INTO ' + QUOTENAME(@ctas_table) + N' (' + @pk_col_list + N',' + @ctas_data_cols + N') '
                         + N'SELECT ' + @pk_col_list + N',' + @ctas_src_cols + N' '
                         + N'FROM ' + QUOTENAME(@p_table_name) + N' b '
                         + N'WHERE (' + @ctas_notnull_pred + N') '
                         + N'AND NOT EXISTS (SELECT 1 FROM ' + QUOTENAME(@ctas_table) + N' t WHERE ' + @pk_join_pred + N');';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Populate CTAS temp table from _ORIG', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
            END
        END
        ELSE
        BEGIN
            DECLARE poptmp_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [orig_col], [tmp_col]
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1;

            OPEN poptmp_cur;
            FETCH NEXT FROM poptmp_cur INTO @orig_col, @tmp_col;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sql = N'UPDATE ' + QUOTENAME(@p_table_name)
                         + N' SET ' + QUOTENAME(@tmp_col) + N' = ' + QUOTENAME(@orig_col)
                         + N' WHERE ' + QUOTENAME(@tmp_col) + N' IS NULL AND ' + QUOTENAME(@orig_col) + N' IS NOT NULL';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Populate temp from _ORIG', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

                FETCH NEXT FROM poptmp_cur INTO @orig_col, @tmp_col;
            END
            CLOSE poptmp_cur;
            DEALLOCATE poptmp_cur;
        END

        -- Phase 4: null _ORIG for out-of-place rows (safe for numeric/type changes)
        DECLARE nullorig_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [orig_col]
            FROM @changes
            WHERE [method] = 'C' AND [allow_change] = 1;

        OPEN nullorig_cur;
        FETCH NEXT FROM nullorig_cur INTO @orig_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'UPDATE ' + QUOTENAME(@p_table_name)
                     + N' SET ' + QUOTENAME(@orig_col) + N' = NULL'
                     + N' WHERE ' + QUOTENAME(@orig_col) + N' IS NOT NULL';
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Null _ORIG prior to datatype change', @p_sql = @sql;
            EXEC sp_executesql @sql;
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

            FETCH NEXT FROM nullorig_cur INTO @orig_col;
        END
        CLOSE nullorig_cur;
        DEALLOCATE nullorig_cur;

        -- Phase 5: in-place substr for varchar decreases
        DECLARE substr_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [orig_col], [precision_len]
            FROM @changes
            WHERE [method] = 'I' AND [allow_change] = 1 AND [needs_substr] = 1;

        OPEN substr_cur;
        FETCH NEXT FROM substr_cur INTO @orig_col, @precision_len;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'UPDATE ' + QUOTENAME(@p_table_name)
                     + N' SET ' + QUOTENAME(@orig_col) + N' = LEFT(' + QUOTENAME(@orig_col) + N',' + CAST(@precision_len AS NVARCHAR(10)) + N')'
                     + N' WHERE LEN(' + QUOTENAME(@orig_col) + N') > ' + CAST(@precision_len AS NVARCHAR(10));
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'In-place trim for varchar decrease', @p_sql = @sql;
            EXEC sp_executesql @sql;
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

            FETCH NEXT FROM substr_cur INTO @orig_col, @precision_len;
        END
        CLOSE substr_cur;
        DEALLOCATE substr_cur;

        -- Phase 6: alter _ORIG datatype to target
        DECLARE alter_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [orig_col], [target_type_sql], [is_nullable]
            FROM @changes
            WHERE [method] <> 'N' AND [allow_change] = 1;

        OPEN alter_cur;
        DECLARE @nullable BIT;
        FETCH NEXT FROM alter_cur INTO @orig_col, @target_type_sql, @nullable;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'ALTER TABLE ' + QUOTENAME(@p_table_name)
                     + N' ALTER COLUMN ' + QUOTENAME(@orig_col) + N' ' + @target_type_sql
                     + CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END;
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Modify _ORIG precision/type', @p_sql = @sql;
            EXEC sp_executesql @sql;
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

            FETCH NEXT FROM alter_cur INTO @orig_col, @target_type_sql, @nullable;
        END
        CLOSE alter_cur;
        DEALLOCATE alter_cur;

        -- Phase 7: repopulate _ORIG from temporary store
        IF @use_ctas_effective = 1
        BEGIN
            DECLARE @restore_set NVARCHAR(MAX);

            SELECT @restore_set = STRING_AGG('b.' + QUOTENAME([orig_col]) + ' = t.' + QUOTENAME([column_name]), ',')
            FROM @changes
            WHERE [method] = 'C' AND [allow_change] = 1;

            IF @restore_set IS NOT NULL
            BEGIN
                SET @sql = N'UPDATE b SET ' + @restore_set
                         + N' FROM ' + QUOTENAME(@p_table_name) + N' b'
                         + N' INNER JOIN ' + QUOTENAME(@ctas_table) + N' t ON ' + @pk_join_pred + N';';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Populate _ORIG from CTAS temp table', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
            END
        END
        ELSE
        BEGIN
            DECLARE restore_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [orig_col], [tmp_col]
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1;

            OPEN restore_cur;
            FETCH NEXT FROM restore_cur INTO @orig_col, @tmp_col;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @sql = N'UPDATE ' + QUOTENAME(@p_table_name)
                         + N' SET ' + QUOTENAME(@orig_col) + N' = ' + QUOTENAME(@tmp_col)
                         + N' WHERE ' + QUOTENAME(@tmp_col) + N' IS NOT NULL';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Populate _ORIG from _TMP', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

                FETCH NEXT FROM restore_cur INTO @orig_col, @tmp_col;
            END
            CLOSE restore_cur;
            DEALLOCATE restore_cur;
        END

        -- Phase 8: cleanup temporary store
        IF @use_ctas_effective = 1
        BEGIN
            IF OBJECT_ID(QUOTENAME(@ctas_table), 'U') IS NOT NULL
            BEGIN
                SET @sql = N'DROP TABLE ' + QUOTENAME(@ctas_table) + N';';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Drop CTAS temp table', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
            END
        END
        ELSE
        BEGIN
            DECLARE droptmp_cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT [tmp_col]
                FROM @changes
                WHERE [method] = 'C' AND [allow_change] = 1;

            OPEN droptmp_cur;
            FETCH NEXT FROM droptmp_cur INTO @tmp_col;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @is_release = 1 AND @p_set_unused = 1
                BEGIN
                    DECLARE @unused_tmp SYSNAME = LEFT('ZZ_UNUSED_' + @tmp_col + '_' + REPLACE(CONVERT(VARCHAR(19), SYSDATETIME(), 126), ':', ''), 128);
                    SET @sql = N'EXEC sp_rename ''' + QUOTENAME(@p_table_name) + N'.' + QUOTENAME(@tmp_col) + N''', ''' + @unused_tmp + N''', ''COLUMN'';';
                END
                ELSE
                BEGIN
                    SET @sql = N'ALTER TABLE ' + QUOTENAME(@p_table_name) + N' DROP COLUMN ' + QUOTENAME(@tmp_col);
                END

                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Drop/SetUnused temp column', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];

                FETCH NEXT FROM droptmp_cur INTO @tmp_col;
            END
            CLOSE droptmp_cur;
            DEALLOCATE droptmp_cur;
        END

        -- Phase 9: rename _ORIG back to original column
        DECLARE back_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [column_name], [orig_col]
            FROM @changes
            WHERE [method] <> 'N' AND [allow_change] = 1;

        OPEN back_cur;
        FETCH NEXT FROM back_cur INTO @column_name, @orig_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM sys.columns s
                WHERE s.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                  AND s.[name] = @orig_col
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM sys.columns s
                WHERE s.[object_id] = OBJECT_ID(QUOTENAME(@p_table_name))
                  AND s.[name] = @column_name
            )
            BEGIN
                SET @sql = N'EXEC sp_rename ''' + QUOTENAME(@p_table_name) + N'.' + QUOTENAME(@orig_col) + N''', ''' + @column_name + N''', ''COLUMN'';';
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] @p_msg = 'Rename _ORIG back to original', @p_sql = @sql;
                EXEC sp_executesql @sql;
                EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
            END

            FETCH NEXT FROM back_cur INTO @column_name, @orig_col;
        END
        CLOSE back_cur;
        DEALLOCATE back_cur;

        EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_success];
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'meta_cur') >= -1 BEGIN CLOSE meta_cur; DEALLOCATE meta_cur; END
        IF CURSOR_STATUS('local', 'rename_cur') >= -1 BEGIN CLOSE rename_cur; DEALLOCATE rename_cur; END
        IF CURSOR_STATUS('local', 'tmpcreate_cur') >= -1 BEGIN CLOSE tmpcreate_cur; DEALLOCATE tmpcreate_cur; END
        IF CURSOR_STATUS('local', 'poptmp_cur') >= -1 BEGIN CLOSE poptmp_cur; DEALLOCATE poptmp_cur; END
        IF CURSOR_STATUS('local', 'nullorig_cur') >= -1 BEGIN CLOSE nullorig_cur; DEALLOCATE nullorig_cur; END
        IF CURSOR_STATUS('local', 'substr_cur') >= -1 BEGIN CLOSE substr_cur; DEALLOCATE substr_cur; END
        IF CURSOR_STATUS('local', 'alter_cur') >= -1 BEGIN CLOSE alter_cur; DEALLOCATE alter_cur; END
        IF CURSOR_STATUS('local', 'restore_cur') >= -1 BEGIN CLOSE restore_cur; DEALLOCATE restore_cur; END
        IF CURSOR_STATUS('local', 'droptmp_cur') >= -1 BEGIN CLOSE droptmp_cur; DEALLOCATE droptmp_cur; END
        IF CURSOR_STATUS('local', 'back_cur') >= -1 BEGIN CLOSE back_cur; DEALLOCATE back_cur; END

        DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();

        BEGIN TRY
            EXEC [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_error] @p_err = @err;
        END TRY
        BEGIN CATCH
        END CATCH

        IF ERROR_NUMBER() BETWEEN 50001 AND 50004
            THROW;

        THROW 50003, 'Error from change_precision_scale: ' + @err, 1;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- drop_column
-- Oracle: SET UNUSED for release-based, DROP for task-based
-- DBA IMPLEMENTATION NOTE:
-- SQL Server has no native `SET UNUSED` metadata state. Release-mode behavior is
-- emulated by deterministic rename to `ZZ_UNUSED_<original>_<timestamp>`.
-- Later cleanup is performed by `drop_unused`.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_column]
    @p_table_name VARCHAR(128),
    @p_drop_list VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @is_release BIT = [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_is_release]();
    DECLARE @sql NVARCHAR(MAX);

    IF @is_release = 1
    BEGIN
        DECLARE @work VARCHAR(MAX) = REPLACE(REPLACE(ISNULL(@p_drop_list, ''), CHAR(10), ' '), CHAR(13), ' ');
        DECLARE @token VARCHAR(256) = '';
        DECLARE @position INT = 1;
        DECLARE @length INT = LEN(@work);
        DECLARE @current_char CHAR(1);

        WHILE @position <= @length + 1
        BEGIN
            SET @current_char = CASE WHEN @position <= @length THEN SUBSTRING(@work, @position, 1) ELSE ',' END;

            IF @current_char = ','
            BEGIN
                SET @token = LTRIM(RTRIM(@token));
                IF @token <> ''
                BEGIN
                    DECLARE @new_name SYSNAME = LEFT('ZZ_UNUSED_' + UPPER(@token) + '_' + REPLACE(CONVERT(VARCHAR(19), SYSDATETIME(), 126), ':', ''), 128);
                    PRINT 'SET UNUSED emulation: ' + UPPER(@p_table_name) + '.' + UPPER(@token) + ' -> ' + @new_name;
                    SET @sql = N'EXEC sp_rename ''' + QUOTENAME(UPPER(@p_table_name)) + N'.' + QUOTENAME(UPPER(@token)) + N''', ''' + @new_name + N''', ''COLUMN'';';
                    EXEC sp_executesql @sql;
                END
                SET @token = '';
            END
            ELSE
            BEGIN
                SET @token = @token + @current_char;
            END

            SET @position = @position + 1;
        END
    END
    ELSE
    BEGIN
        SET @sql = N'ALTER TABLE ' + QUOTENAME(UPPER(@p_table_name)) + N' DROP COLUMN ' + @p_drop_list;
        EXEC sp_executesql @sql;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- drop_unused
-- Oracle: drop unused columns on one/all tables
-- Azure SQL: cleanup of release-mode `SET UNUSED` emulation (`ZZ_UNUSED_` columns)
-- DBA IMPLEMENTATION NOTE:
-- This routine is the physical cleanup step for columns renamed by
-- `PKG_PDX_SCHEMA_UPDATER_HELPER_drop_column` in release mode.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_unused]
    @p_table_name VARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @drop_sql NVARCHAR(MAX);

    DECLARE c_tables CURSOR LOCAL FAST_FORWARD FOR
        SELECT t.[name]
        FROM sys.tables t
        WHERE @p_table_name IS NULL OR t.[name] = UPPER(@p_table_name);

    DECLARE @table_name SYSNAME;
    DECLARE @column_name SYSNAME;

    OPEN c_tables;
    FETCH NEXT FROM c_tables INTO @table_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE c_cols CURSOR LOCAL FAST_FORWARD FOR
            SELECT c.[name]
            FROM sys.columns c
            INNER JOIN sys.tables t ON t.[object_id] = c.[object_id]
            WHERE t.[name] = @table_name
              AND c.[name] LIKE 'ZZ_UNUSED[_]%';

        OPEN c_cols;
        FETCH NEXT FROM c_cols INTO @column_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @drop_sql = N'ALTER TABLE ' + QUOTENAME(@table_name) + N' DROP COLUMN ' + QUOTENAME(@column_name);
            EXEC sp_executesql @drop_sql;

            FETCH NEXT FROM c_cols INTO @column_name;
        END

        CLOSE c_cols;
        DEALLOCATE c_cols;

        FETCH NEXT FROM c_tables INTO @table_name;
    END

    CLOSE c_tables;
    DEALLOCATE c_tables;
END;
GO
