/**********************************************************************************************************************
* Azure SQL T-SQL Conversion: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_HELPER
* Source: EPR_Oracle/Packages/SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_HELPER.sql
*
* Conversion Notes (Column K):
*   - Oracle package-level state variables (g_is_release, g_debug, g_debug_hdr_id, g_debug_dtl_id) are stored
*     in SESSION_CONTEXT using sys.sp_set_session_context (requires SQL Server 2016+ / Azure SQL DB).
*   - Oracle BOOLEAN parameters and return types converted to BIT (1=TRUE, 0=FALSE, NULL=NULL).
*   - Oracle PRAGMA AUTONOMOUS_TRANSACTION is NOT supported in Azure SQL. All debug procedures
*     (debug_hdr, debug_dtl and their success/error variants) execute within the caller's transaction.
*     Debug rows may be rolled back if the caller rolls back. Documented deviation.
*   - Oracle INDEX BY associative array (coltbl) is converted to temp table #coldata shared across
*     all helper procedures. #coldata is created by change_precision_scale and all sub-procs reference it.
*     Sub-procedures process_change_list, set_renamed, set_method, validate_data, create_out_of_place,
*     is_oop_populated, populate_tmp, set_orig_null, update_decreasing_varchar, modify_precisions,
*     is_orig_populated, populate_orig_from_tmp, drop_tmp, rename_orig, modify_types are only meaningful
*     when called from within change_precision_scale (which creates #coldata).
*   - Oracle EXECUTE IMMEDIATE converted to EXEC sp_executesql or EXEC (@sql).
*   - Oracle user_tab_columns mapped to INFORMATION_SCHEMA.COLUMNS (all schemas).
*   - Oracle user_constraints + user_cons_columns mapped to INFORMATION_SCHEMA.TABLE_CONSTRAINTS
*     + INFORMATION_SCHEMA.KEY_COLUMN_USAGE + INFORMATION_SCHEMA.COLUMNS.
*   - Oracle REGEXP_COUNT/REGEXP_SUBSTR/REGEXP_REPLACE for parsing p_change_list replaced with
*     STRING_SPLIT-based parsing (SQL Server 2016+ / Azure SQL DB compatible).
*   - ALTER TABLE ... SET UNUSED is NOT supported in Azure SQL. drop_column uses DROP COLUMN
*     for both release-based and task-based schemas (behavioral deviation - documented).
*   - Oracle user_unused_col_tabs has no Azure SQL equivalent. drop_unused is a no-op stub.
*   - RAISE_APPLICATION_ERROR(-20001) -> THROW 50001; (-20002) -> 50002; (-20003) -> 50003;
*     (-20004) -> 50004; DTL_EXCEPTION -> 50099.
*   - Oracle DBMS_OUTPUT.PUT_LINE mapped to PRINT.
*   - Oracle NVL -> ISNULL; SUBSTR -> SUBSTRING/LEFT; LENGTH -> LEN; SYSTIMESTAMP -> SYSDATETIME().
*   - p_parallel hint support: Oracle /*+ parallel(...) */ query hints have no direct T-SQL DDL equivalent;
*     parallel parameters are accepted but not applied to DDL statements.
*   - LOCK TABLE ... IN EXCLUSIVE MODE -> SELECT TOP 0 FROM table WITH (TABLOCKX, HOLDLOCK).
*   - DROP TABLE ... PURGE -> DROP TABLE (no PURGE concept in Azure SQL).
*   - Oracle USING INDEX in CREATE TABLE PRIMARY KEY constraint -> omitted (T-SQL auto-creates PK index).
*   - Oracle NO_DATA_FOUND exception in SELECT INTO -> handled via TRY/CATCH with @@ROWCOUNT check.
*
* SSMA Errors Addressed:
*   - O2SS0518: Wrapper functions not supported -> converted to stored procedures with OUTPUT params.
*   - O2SS0404: ROWID column -> not used in converted T-SQL.
*   - O2SS0013: EXECUTE IMMEDIATE -> sp_executesql / EXEC (@sql).
*   - O2SS0050/O2SS0560: Identifier conversion issues -> resolved via INFORMATION_SCHEMA mappings.
*   - O2SS0452: xp_ora2ms_exec2_ex in UDF -> replaced with EXEC sp_executesql in procedures.
**********************************************************************************************************************/

-- ============================================================
-- Helper: Session Context accessors for package-level state
-- g_debug          -> SESSION_CONTEXT key N'pdx_helper_debug'        (N'1'/N'0')
-- g_is_release     -> SESSION_CONTEXT key N'pdx_helper_is_release'   (N'1'/N'0'/NULL)
-- g_debug_hdr_id   -> SESSION_CONTEXT key N'pdx_helper_dbg_hdr_id'   (numeric as NVARCHAR)
-- g_debug_dtl_id   -> SESSION_CONTEXT key N'pdx_helper_dbg_dtl_id'   (numeric as NVARCHAR)
-- ============================================================

-- ============================================================
-- PROCEDURE: set_debug
-- Sets the package-level debug flag (g_debug).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_debug]
    @p_value BIT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sys.sp_set_session_context
        @key   = N'pdx_helper_debug',
        @value = CASE WHEN @p_value = 1 THEN N'1' ELSE N'0' END;
END;
GO

-- ============================================================
-- PROCEDURE: purge_debug
-- Deletes debug header/detail rows older than p_date, optionally filtered by proc name.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_purge_debug]
    @p_date DATETIME2,
    @p_proc VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM pdx_schema_upd_helper_debug_d
    WHERE pdx_schema_upd_hlpr_dbg_h_id IN (
        SELECT id FROM pdx_schema_upd_helper_debug_h h
        WHERE h.debug_timestamp < @p_date
          AND (@p_proc IS NULL OR @p_proc = h.[proc])
    );
    DELETE FROM pdx_schema_upd_helper_debug_h
    WHERE debug_timestamp < @p_date
      AND (@p_proc IS NULL OR @p_proc = [proc]);
    COMMIT; -- Oracle had explicit COMMIT; preserved for symmetry
END;
GO

-- ============================================================
-- PROCEDURE: debug_hdr
-- Inserts a debug header row (AUTONOMOUS_TRANSACTION in Oracle; regular txn in Azure SQL).
-- Note: In Azure SQL, PRAGMA AUTONOMOUS_TRANSACTION is not supported. Debug rows participate
-- in the caller's transaction and may be rolled back if the caller rolls back.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr]
    @p_proc   VARCHAR(255),
    @p_parms  VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug') AS NVARCHAR(10));
    IF ISNULL(@v_debug, N'0') = N'1'
    BEGIN
        DECLARE @v_new_id BIGINT;
        SELECT @v_new_id = NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ];
        INSERT INTO pdx_schema_upd_helper_debug_h (id, [proc], parms, debug_timestamp)
        VALUES (@v_new_id, UPPER(@p_proc), @p_parms, SYSDATETIME());
        EXEC sys.sp_set_session_context
            @key   = N'pdx_helper_dbg_hdr_id',
            @value = CAST(@v_new_id AS NVARCHAR(50));
        -- Reset detail id
        EXEC sys.sp_set_session_context
            @key   = N'pdx_helper_dbg_dtl_id',
            @value = NULL;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: debug_hdr_success
-- Clears g_debug_hdr_id and g_debug_dtl_id on successful completion.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_success]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug') AS NVARCHAR(10));
    IF ISNULL(@v_debug, N'0') = N'1'
    BEGIN
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_hdr_id', @value = NULL;
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_dtl_id', @value = NULL;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: debug_hdr_error
-- Updates the debug header row with error text.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_error]
    @p_err VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug  NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug')       AS NVARCHAR(10));
    DECLARE @v_hdr_id NVARCHAR(50) = CAST(SESSION_CONTEXT(N'pdx_helper_dbg_hdr_id')  AS NVARCHAR(50));
    IF ISNULL(@v_debug, N'0') = N'1' AND @v_hdr_id IS NOT NULL
    BEGIN
        UPDATE pdx_schema_upd_helper_debug_h
        SET sql_error = @p_err
        WHERE id = CAST(@v_hdr_id AS BIGINT);
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_hdr_id', @value = NULL;
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_dtl_id', @value = NULL;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: debug_dtl
-- Inserts a debug detail row linked to the current header.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
    @p_msg VARCHAR(255),
    @p_sql VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug  NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug')      AS NVARCHAR(10));
    DECLARE @v_hdr_id NVARCHAR(50) = CAST(SESSION_CONTEXT(N'pdx_helper_dbg_hdr_id') AS NVARCHAR(50));
    IF ISNULL(@v_debug, N'0') = N'1' AND @v_hdr_id IS NOT NULL
    BEGIN
        DECLARE @v_new_id BIGINT;
        SELECT @v_new_id = NEXT VALUE FOR [PDX_SCHEMA_MASTER_SEQ];
        INSERT INTO pdx_schema_upd_helper_debug_d
            (id, pdx_schema_upd_hlpr_dbg_h_id, start_timestamp, message, sql)
        VALUES
            (@v_new_id, CAST(@v_hdr_id AS BIGINT), SYSDATETIME(), @p_msg, @p_sql);
        EXEC sys.sp_set_session_context
            @key   = N'pdx_helper_dbg_dtl_id',
            @value = CAST(@v_new_id AS NVARCHAR(50));
    END;
END;
GO

-- ============================================================
-- PROCEDURE: debug_dtl_success
-- Updates end_timestamp on the current debug detail row.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug  NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug')      AS NVARCHAR(10));
    DECLARE @v_dtl_id NVARCHAR(50) = CAST(SESSION_CONTEXT(N'pdx_helper_dbg_dtl_id') AS NVARCHAR(50));
    IF ISNULL(@v_debug, N'0') = N'1' AND @v_dtl_id IS NOT NULL
    BEGIN
        UPDATE pdx_schema_upd_helper_debug_d
        SET end_timestamp = SYSDATETIME()
        WHERE id = CAST(@v_dtl_id AS BIGINT);
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_dtl_id', @value = NULL;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: debug_dtl_error
-- Updates sql_error on the current debug detail row.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error]
    @p_err VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_debug  NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_debug')      AS NVARCHAR(10));
    DECLARE @v_dtl_id NVARCHAR(50) = CAST(SESSION_CONTEXT(N'pdx_helper_dbg_dtl_id') AS NVARCHAR(50));
    IF ISNULL(@v_debug, N'0') = N'1' AND @v_dtl_id IS NOT NULL
    BEGIN
        UPDATE pdx_schema_upd_helper_debug_d
        SET sql_error = @p_err
        WHERE id = CAST(@v_dtl_id AS BIGINT);
        EXEC sys.sp_set_session_context @key = N'pdx_helper_dbg_dtl_id', @value = NULL;
    END;
END;
GO

-- ============================================================
-- FUNCTION: get_is_release
-- Returns 1 if APPLYTYPE != 'TASK', 0 otherwise.
-- Caches result in SESSION_CONTEXT (mirrors Oracle package variable g_is_release).
-- O2SS0518: Wrapper function pattern -> implemented as scalar function; EXEC restriction addressed
--           by avoiding dynamic SQL inside this function.
-- ============================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_is_release]()
RETURNS BIT
AS
BEGIN
    DECLARE @cached NVARCHAR(10) = CAST(SESSION_CONTEXT(N'pdx_helper_is_release') AS NVARCHAR(10));
    -- Note: SESSION_CONTEXT is read-only inside a function; cache write is done in init procedure below.
    -- If cache is warm, return it.
    IF @cached = N'1' RETURN 1;
    IF @cached = N'0' RETURN 0;
    -- Cold path: read from table. 
    -- Note: SESSION_CONTEXT cannot be SET inside a T-SQL scalar function.
    -- Callers requiring caching should call PKG_PDX_SCHEMA_UPDATER_HELPER_init_is_release first.
    DECLARE @l_tmp VARCHAR(30);
    SELECT @l_tmp = UPPER([value]) FROM pdx_schema_config WHERE [key] = 'APPLYTYPE';
    RETURN CASE WHEN ISNULL(@l_tmp, '') != 'TASK' THEN 1 ELSE 0 END;
END;
GO

-- ============================================================
-- PROCEDURE: init_is_release (Azure-only helper)
-- Warms the SESSION_CONTEXT cache for get_is_release (needed because functions cannot call sp_set_session_context).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_init_is_release]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @l_tmp VARCHAR(30);
    SELECT @l_tmp = UPPER([value]) FROM pdx_schema_config WHERE [key] = 'APPLYTYPE';
    EXEC sys.sp_set_session_context
        @key   = N'pdx_helper_is_release',
        @value = CASE WHEN ISNULL(@l_tmp, '') != 'TASK' THEN N'1' ELSE N'0' END;
END;
GO

-- ============================================================
-- FUNCTION: get_rename_column_name
-- Returns the temporary renamed column name (original kept with _ORIG suffix).
-- Oracle nested FUNCTION within change_precision_scale; extracted as standalone.
-- ============================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name]
(
    @p_column VARCHAR(30)
)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN LEFT(UPPER(@p_column), 25) + '_ORIG';
END;
GO

-- ============================================================
-- FUNCTION: get_temp_table_name
-- Returns the temp table name for CTAS mode, or the original table name for column mode.
-- Oracle nested FUNCTION within change_precision_scale; extracted as standalone.
-- ============================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name]
(
    @p_table    VARCHAR(30),
    @p_use_ctas BIT
)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CASE WHEN @p_use_ctas = 1 THEN LEFT(UPPER(@p_table), 26) + '_TMP' ELSE UPPER(@p_table) END;
END;
GO

-- ============================================================
-- FUNCTION: get_temp_column_name
-- Returns the temp column name: same name (CTAS) or suffixed _TMP (column mode).
-- Oracle nested FUNCTION within change_precision_scale; extracted as standalone.
-- ============================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name]
(
    @p_column   VARCHAR(30),
    @p_use_ctas BIT
)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CASE WHEN @p_use_ctas = 1 THEN UPPER(@p_column) ELSE LEFT(UPPER(@p_column), 25) + '_TMP' END;
END;
GO

-- ============================================================
-- FUNCTION: get_data_type
-- Reconstructs a data type string (NUMBER or VARCHAR2) from parts.
-- RAISE_APPLICATION_ERROR(-20004) -> THROW 50004 (not inside function -> use RETURN NULL with caller check).
-- Note: T-SQL scalar functions cannot THROW; unsupported type returns a sentinel value '##UNSUPPORTED##'.
--       Callers must check for this sentinel.
-- Oracle nested FUNCTION within change_precision_scale; extracted as standalone.
-- ============================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type]
(
    @p_type     VARCHAR(15),
    @p_prec_len INT,
    @p_scale    INT = NULL
)
RETURNS VARCHAR(60)
AS
BEGIN
    DECLARE @l_rtn VARCHAR(60);
    IF @p_type = 'NUMBER'
    BEGIN
        SET @l_rtn = 'NUMBER' + CASE
            WHEN @p_prec_len IS NOT NULL
                THEN '(' + CAST(@p_prec_len AS VARCHAR(10))
                     + CASE WHEN ISNULL(@p_scale, 0) != 0 THEN ',' + CAST(@p_scale AS VARCHAR(10)) ELSE '' END
                     + ')'
            ELSE ''
        END;
    END
    ELSE IF @p_type = 'VARCHAR2'
    BEGIN
        SET @l_rtn = 'VARCHAR2(' + CAST(@p_prec_len AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        -- Cannot THROW from a function; return sentinel. Caller must check.
        SET @l_rtn = '##UNSUPPORTED##';
    END;
    RETURN @l_rtn;
END;
GO

-- ============================================================
-- PROCEDURE: process_change_list
-- Parses p_change_list (comma-separated 'COL TYPE[(PREC[,SCALE])]') and populates #coldata.
-- Oracle used REGEXP_COUNT/REGEXP_SUBSTR; replaced with STRING_SPLIT-based parser.
-- #coldata must already exist (created by change_precision_scale caller).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_process_change_list]
    @p_change_list VARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM #coldata;

    DECLARE @token         VARCHAR(200);
    DECLARE @col           VARCHAR(30);
    DECLARE @l_type        VARCHAR(15);
    DECLARE @rest          VARCHAR(100);
    DECLARE @prec_scale    VARCHAR(30);
    DECLARE @l_prec        INT;
    DECLARE @l_scale       INT;
    DECLARE @paren_open    INT;
    DECLARE @paren_close   INT;
    DECLARE @comma_pos     INT;
    DECLARE @space_pos     INT;
    DECLARE @unparsed      VARCHAR(4000) = '';

    DECLARE token_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT LTRIM(RTRIM([value]))
        FROM STRING_SPLIT(@p_change_list, ',')
        WHERE LTRIM(RTRIM([value])) <> '';

    OPEN token_cur;
    FETCH NEXT FROM token_cur INTO @token;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Validate token matches expected pattern: NAME TYPE[(PREC[,SCALE])]
        SET @space_pos = CHARINDEX(' ', @token);
        IF @space_pos = 0
        BEGIN
            SET @unparsed = @unparsed + @token + ',';
            FETCH NEXT FROM token_cur INTO @token;
            CONTINUE;
        END;

        SET @col  = LTRIM(RTRIM(UPPER(LEFT(@token, @space_pos - 1))));
        SET @rest = LTRIM(RTRIM(SUBSTRING(@token, @space_pos + 1, LEN(@token))));

        -- Parse type and optional (precision, scale)
        SET @paren_open  = CHARINDEX('(', @rest);
        SET @paren_close = CHARINDEX(')', @rest);
        IF @paren_open > 0 AND @paren_close > @paren_open
        BEGIN
            SET @l_type     = LTRIM(RTRIM(LEFT(@rest, @paren_open - 1)));
            SET @prec_scale = LTRIM(RTRIM(SUBSTRING(@rest, @paren_open + 1, @paren_close - @paren_open - 1)));
            SET @comma_pos  = CHARINDEX(',', @prec_scale);
            IF @comma_pos > 0
            BEGIN
                SET @l_prec  = TRY_CAST(LTRIM(RTRIM(LEFT(@prec_scale, @comma_pos - 1))) AS INT);
                SET @l_scale = TRY_CAST(LTRIM(RTRIM(SUBSTRING(@prec_scale, @comma_pos + 1, LEN(@prec_scale)))) AS INT);
            END
            ELSE
            BEGIN
                SET @l_prec  = TRY_CAST(LTRIM(RTRIM(@prec_scale)) AS INT);
                SET @l_scale = NULL;
            END;
        END
        ELSE
        BEGIN
            SET @l_type     = LTRIM(RTRIM(@rest));
            SET @l_prec     = NULL;
            SET @l_scale    = NULL;
        END;

        -- Validate type
        IF @l_type NOT IN ('NUMBER', 'VARCHAR2')
            THROW 50001, 'Only datatypes NUMBER and VARCHAR2 are supported.', 1;

        -- Validate not duplicate
        IF EXISTS (SELECT 1 FROM #coldata WHERE col_name = @col)
        BEGIN
            DECLARE @dup_msg VARCHAR(200) = 'Column ' + @col + ' was found more than once in change list.';
            THROW 50001, @dup_msg, 1;
        END;

        INSERT INTO #coldata (col_name, data_type, data_precision_length, data_scale)
        VALUES (@col, @l_type, @l_prec, @l_scale);

        FETCH NEXT FROM token_cur INTO @token;
    END;

    CLOSE token_cur;
    DEALLOCATE token_cur;

    IF LTRIM(RTRIM(@unparsed)) <> ''
    BEGIN
        DECLARE @unp_msg VARCHAR(500) = 'Unable to process change list: ' + @unparsed;
        THROW 50001, @unp_msg, 1;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: set_renamed
-- For each column in #coldata, checks INFORMATION_SCHEMA.COLUMNS to determine:
--   - Does the original column exist? (tmp_renamed = 'N')
--   - Does the _ORIG renamed version exist? (tmp_renamed = 'Y')
--   - Does a temp column (_TMP) or temp table (_TMP) exist? (new_renamed = 'C'/'T'/'N')
-- Updates #coldata accordingly.
-- Note: Queries INFORMATION_SCHEMA.COLUMNS without schema filter (mirrors Oracle user_tab_columns).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_renamed]
    @p_table    VARCHAR(255),
    @p_use_ctas BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_column         VARCHAR(30);
    DECLARE @l_renamed_column VARCHAR(30);
    DECLARE @l_temp_column    VARCHAR(30);
    DECLARE @l_temp_table     VARCHAR(30);
    DECLARE @l_type           VARCHAR(30);
    DECLARE @l_length         INT;
    DECLARE @l_precision      INT;
    DECLARE @l_scale          INT;
    DECLARE @l_found          INT;

    DECLARE col_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name FROM #coldata ORDER BY col_name;

    OPEN col_cur;
    FETCH NEXT FROM col_cur INTO @l_column;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Try to find original column
        SELECT @l_found = 1, @l_type = DATA_TYPE,
               @l_length = CHARACTER_MAXIMUM_LENGTH,
               @l_precision = NUMERIC_PRECISION,
               @l_scale = NUMERIC_SCALE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = UPPER(@p_table)
          AND COLUMN_NAME = UPPER(@l_column);

        IF ISNULL(@l_found, 0) = 1
        BEGIN
            IF @l_type NOT IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real',
                               'nvarchar','varchar','char','nchar')
               AND @l_type NOT IN ('NUMBER','VARCHAR2') -- Oracle-style aliases for compat check
            BEGIN
                -- We map Oracle NUMBER -> numeric/decimal/int and VARCHAR2 -> varchar/nvarchar on target.
                -- Accept any numeric or varchar type as compatible.
                NULL; -- no-op: type validation done at method level
            END;
            UPDATE #coldata SET
                tmp_renamed            = 'N',
                tmp_type               = CASE WHEN @l_type IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real') THEN 'NUMBER'
                                              WHEN @l_type IN ('nvarchar','varchar','char','nchar') THEN 'VARCHAR2'
                                              ELSE UPPER(@l_type) END,
                tmp_precision_length   = CASE WHEN @l_type IN ('nvarchar','varchar','char','nchar') THEN @l_length ELSE @l_precision END,
                tmp_scale              = @l_scale
            WHERE col_name = @l_column;
        END
        ELSE
        BEGIN
            -- Try renamed (_ORIG) version
            SET @l_renamed_column = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_column);
            SET @l_found = 0;
            SELECT @l_found = 1, @l_type = DATA_TYPE,
                   @l_length = CHARACTER_MAXIMUM_LENGTH,
                   @l_precision = NUMERIC_PRECISION,
                   @l_scale = NUMERIC_SCALE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = UPPER(@p_table)
              AND COLUMN_NAME = @l_renamed_column;

            IF @l_found = 0
            BEGIN
                DECLARE @nr_msg VARCHAR(200) = 'Table ' + @p_table + ' does not contain column ' + @l_column + ', nor the renamed column';
                THROW 50001, @nr_msg, 1;
            END;

            UPDATE #coldata SET
                tmp_renamed            = 'Y',
                tmp_type               = CASE WHEN @l_type IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real') THEN 'NUMBER'
                                              WHEN @l_type IN ('nvarchar','varchar','char','nchar') THEN 'VARCHAR2'
                                              ELSE UPPER(@l_type) END,
                tmp_precision_length   = CASE WHEN @l_type IN ('nvarchar','varchar','char','nchar') THEN @l_length ELSE @l_precision END,
                tmp_scale              = @l_scale
            WHERE col_name = @l_column;
        END;

        -- Check for temporary column (_TMP)
        SET @l_temp_column = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_column, 0); -- non-CTAS name
        SET @l_found = 0;
        SELECT @l_found = 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = UPPER(@p_table)
          AND COLUMN_NAME = @l_temp_column;

        IF @l_found = 1
        BEGIN
            IF @p_use_ctas = 1
            BEGIN
                DECLARE @ctas_col_msg VARCHAR(200) = 'Requested use of CTAS, but temporary column ' + @l_temp_column + ' exists on table.';
                THROW 50001, @ctas_col_msg, 1;
            END;
            UPDATE #coldata SET new_renamed = 'C' WHERE col_name = @l_column;
        END
        ELSE
        BEGIN
            -- Check for temp table (_TMP)
            SET @l_temp_table = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, 1);
            SET @l_found = 0;
            SELECT @l_found = 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = @l_temp_table
              AND COLUMN_NAME = UPPER(@l_column);

            IF @l_found = 1
            BEGIN
                IF @p_use_ctas = 0
                BEGIN
                    DECLARE @inline_msg VARCHAR(200) = 'Requested use of Inline, but temporary table ' + @l_temp_table + ' exists in schema for modified column.';
                    THROW 50001, @inline_msg, 1;
                END;
                UPDATE #coldata SET new_renamed = 'T' WHERE col_name = @l_column;
            END
            ELSE
            BEGIN
                UPDATE #coldata SET new_renamed = 'N' WHERE col_name = @l_column;
            END;
        END;

        SET @l_found = 0;
        FETCH NEXT FROM col_cur INTO @l_column;
    END;

    CLOSE col_cur;
    DEALLOCATE col_cur;
END;
GO

-- ============================================================
-- PROCEDURE: set_method
-- Determines the processing method for each column based on current vs desired type/precision.
-- Updates #coldata.method and .action.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_method]
    @p_table         VARCHAR(255),
    @p_increase_only BIT,
    @p_use_ctas      BIT,
    @p_is_release    BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_column      VARCHAR(30);
    DECLARE @data_type     VARCHAR(15);
    DECLARE @data_prec     INT;
    DECLARE @data_scale    INT;
    DECLARE @tmp_renamed   CHAR(1);
    DECLARE @tmp_type      VARCHAR(15);
    DECLARE @tmp_prec      INT;
    DECLARE @tmp_scale     INT;
    DECLARE @new_renamed   CHAR(1);

    DECLARE @l_decreasing  BIT;
    DECLARE @l_increasing  BIT;
    DECLARE @l_outofplace  BIT;

    -- For re-attempt detection with existing temp col/table
    DECLARE @tmp_col_type  VARCHAR(30);
    DECLARE @tmp_col_prec  INT;
    DECLARE @tmp_col_scale INT;
    DECLARE @tmp_col_len   INT;
    DECLARE @tmp_col_found INT;
    DECLARE @l_temp_col    VARCHAR(30);
    DECLARE @l_temp_tbl    VARCHAR(30);
    DECLARE @l_action      CHAR(1);

    DECLARE col_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, data_type, data_precision_length, data_scale,
               tmp_renamed, tmp_type, tmp_precision_length, tmp_scale,
               new_renamed
        FROM #coldata
        ORDER BY col_name;

    OPEN col_cur;
    FETCH NEXT FROM col_cur INTO
        @l_column, @data_type, @data_prec, @data_scale,
        @tmp_renamed, @tmp_type, @tmp_prec, @tmp_scale, @new_renamed;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Default action = Apply
        UPDATE #coldata SET [action] = 'A' WHERE col_name = @l_column;

        -- Compute decreasing flag
        SET @l_decreasing =
            CASE WHEN (@data_type = 'NUMBER' AND @tmp_type = 'NUMBER'
                       AND (ISNULL(@data_prec,0) - ISNULL(@data_scale,0) < ISNULL(@tmp_prec,0) - ISNULL(@tmp_scale,0)
                           OR ISNULL(@data_prec,0) < ISNULL(@tmp_prec,0)
                           OR ISNULL(@data_scale,0) < ISNULL(@tmp_scale,0)))
                  OR (@data_type = 'VARCHAR2' AND @tmp_type = 'VARCHAR2'
                      AND @data_prec < @tmp_prec)
                 THEN 1 ELSE 0 END;

        SET @l_increasing =
            CASE WHEN @l_decreasing = 0
                 AND ((@data_type = 'NUMBER' AND @tmp_type = 'NUMBER'
                       AND (ISNULL(@data_prec,0) - ISNULL(@data_scale,0) > ISNULL(@tmp_prec,0) - ISNULL(@tmp_scale,0)
                           OR ISNULL(@data_prec,0) > ISNULL(@tmp_prec,0)
                           OR ISNULL(@data_scale,0) > ISNULL(@tmp_scale,0)))
                     OR (@data_type = 'VARCHAR2' AND @tmp_type = 'VARCHAR2'
                         AND @data_prec > @tmp_prec))
                 THEN 1 ELSE 0 END;

        SET @l_outofplace =
            CASE WHEN (@data_type = 'NUMBER' AND @tmp_type = 'NUMBER'
                       AND (ISNULL(@data_prec,0) - ISNULL(@data_scale,0) < ISNULL(@tmp_prec,0) - ISNULL(@tmp_scale,0)
                           OR ISNULL(@data_prec,0) < ISNULL(@tmp_prec,0)
                           OR ISNULL(@data_scale,0) < ISNULL(@tmp_scale,0)))
                  OR @data_type != @tmp_type
                 THEN 1 ELSE 0 END;

        -- Determine method
        IF @tmp_renamed = 'N' AND @l_decreasing = 0 AND @l_increasing = 0 AND @l_outofplace = 0
        BEGIN
            IF @new_renamed != 'N'
                THROW 50002, 'It appears that column is already of the requested size, but a temporary column exists.', 1;
            UPDATE #coldata SET method = 'N' WHERE col_name = @l_column;
            PRINT @l_column + ' N - Not renamed and is neither increasing, decreasing, nor changing datatype';
        END
        ELSE IF @tmp_renamed = 'Y'
        BEGIN
            IF @new_renamed IN ('C','T')
            BEGIN
                -- Re-attempt or rollback: check if temp col/table has the desired type
                SET @l_temp_col = CASE WHEN @p_use_ctas = 1
                                       THEN [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_column, 1)
                                       ELSE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_column, 0) END;
                SET @l_temp_tbl = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, @p_use_ctas);

                PRINT @l_temp_tbl + '.' + @l_temp_col;

                SET @tmp_col_found = 0;
                SELECT @tmp_col_found = 1,
                       @tmp_col_type  = DATA_TYPE,
                       @tmp_col_len   = CHARACTER_MAXIMUM_LENGTH,
                       @tmp_col_prec  = NUMERIC_PRECISION,
                       @tmp_col_scale = NUMERIC_SCALE
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_NAME = @l_temp_tbl AND COLUMN_NAME = @l_temp_col;

                IF @tmp_col_found = 1
                BEGIN
                    DECLARE @tmp_dt_str VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](
                        CASE WHEN @tmp_col_type IN ('int','bigint','decimal','numeric','float','real') THEN 'NUMBER' ELSE 'VARCHAR2' END,
                        CASE WHEN @tmp_col_type IN ('nvarchar','varchar','char','nchar') THEN @tmp_col_len ELSE @tmp_col_prec END,
                        @tmp_col_scale);
                    DECLARE @new_dt_str VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](
                        @data_type, @data_prec, @data_scale);
                    IF @tmp_dt_str != @new_dt_str
                        UPDATE #coldata SET [action] = 'R' WHERE col_name = @l_column;
                END;
            END;

            IF @new_renamed = 'C'
            BEGIN
                IF @p_use_ctas = 1
                    THROW 50002, 'Tmp Column found, however Tmp Table was requested.', 1;
                UPDATE #coldata SET method = 'C' WHERE col_name = @l_column;
                PRINT @l_column + ' C - column is already renamed and temp column was found';
            END
            ELSE IF @new_renamed = 'T'
            BEGIN
                IF @p_use_ctas = 0
                    THROW 50002, 'Tmp Table found, however Tmp Column was requested.', 1;
                UPDATE #coldata SET method = 'T' WHERE col_name = @l_column;
                PRINT @l_column + ' T - column is already renamed and temp table was found';
            END;

            -- If new_renamed = 'N' and tmp_renamed = 'Y', method is still NULL -> fall through to logic below
        END;

        -- If method still NULL (tmp_renamed='N' and conditions not met above, or tmp_renamed='Y' new_renamed='N')
        IF NOT EXISTS (SELECT 1 FROM #coldata WHERE col_name = @l_column AND method IS NOT NULL)
        BEGIN
            IF @p_is_release = 1 AND @l_decreasing = 1 AND @p_increase_only = 1 AND @data_type = @tmp_type
            BEGIN
                UPDATE #coldata SET method = 'N' WHERE col_name = @l_column;
                PRINT @l_column + ' N - decreasing precision, but requested to perform increase-only';
            END
            ELSE IF @l_increasing = 1 AND @l_outofplace = 0
            BEGIN
                UPDATE #coldata SET method = 'I' WHERE col_name = @l_column;
                PRINT @l_column + ' I - Increasing precision can be done directly';
            END
            ELSE IF @l_decreasing = 1 OR @l_outofplace = 1
            BEGIN
                IF @l_outofplace = 1
                BEGIN
                    UPDATE #coldata SET method = CASE WHEN @p_use_ctas = 1 THEN 'T' ELSE 'C' END WHERE col_name = @l_column;
                    PRINT @l_column + ' ' + CASE WHEN @p_use_ctas = 1 THEN 'T' ELSE 'C' END + ' - change must be done out of place';
                END
                ELSE
                BEGIN
                    UPDATE #coldata SET method = 'I' WHERE col_name = @l_column;
                    PRINT @l_column + ' I - Assumes VARCHAR2 decrease which can be done directly';
                END;
            END
            ELSE IF @l_decreasing = 0 AND @l_increasing = 0 AND @l_outofplace = 0
            BEGIN
                UPDATE #coldata SET method = 'I' WHERE col_name = @l_column;
                PRINT @l_column + ' I - Assumes we still have ORIG columns and simply need to rename them';
            END
            ELSE
            BEGIN
                DECLARE @logic_err VARCHAR(200) = 'Logic error - ' + @l_column + ' in validate_data.';
                THROW 50002, @logic_err, 1;
            END;
        END;

        FETCH NEXT FROM col_cur INTO
            @l_column, @data_type, @data_prec, @data_scale,
            @tmp_renamed, @tmp_type, @tmp_prec, @tmp_scale, @new_renamed;
    END;

    CLOSE col_cur;
    DEALLOCATE col_cur;
END;
GO

-- ============================================================
-- PROCEDURE: validate_data
-- Validates consistency of #coldata state (renamed/method/action).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_validate_data]
    @p_use_ctas BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_column      VARCHAR(30);
    DECLARE @method        CHAR(1);
    DECLARE @tmp_renamed   CHAR(1);
    DECLARE @new_renamed   CHAR(1);
    DECLARE @l_action      CHAR(1);

    DECLARE @l_fnd_renamed BIT = 0;
    DECLARE @l_all_renamed BIT = 1;
    DECLARE @l_fnd_temp    BIT = 0;
    DECLARE @l_all_temp    BIT = 1;
    DECLARE @l_tc_action   CHAR(1) = NULL;

    -- First pass
    DECLARE pass1_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, method, tmp_renamed, new_renamed FROM #coldata ORDER BY col_name;
    OPEN pass1_cur;
    FETCH NEXT FROM pass1_cur INTO @l_column, @method, @tmp_renamed, @new_renamed;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @method != 'N' AND @tmp_renamed = 'Y'
            SET @l_fnd_renamed = 1;
        ELSE IF @method != 'N' AND @tmp_renamed != 'Y'
            SET @l_all_renamed = 0;
        ELSE IF @method = 'N' AND @tmp_renamed = 'Y'
        BEGIN
            DECLARE @v_msg1 VARCHAR(200);
            SET @v_msg1 = @l_column + ' is not being modified, but is renamed from original.';
            THROW 50003, @v_msg1, 1;
        END;

        IF @method IN ('C','T') AND @new_renamed != 'N'
            SET @l_fnd_temp = 1;
        ELSE IF @method IN ('C','T') AND @new_renamed = 'N'
            SET @l_all_temp = 0;

        IF @method IN ('C','T')
            SET @l_tc_action = (SELECT [action] FROM #coldata WHERE col_name = @l_column);

        FETCH NEXT FROM pass1_cur INTO @l_column, @method, @tmp_renamed, @new_renamed;
    END;
    CLOSE pass1_cur;
    DEALLOCATE pass1_cur;

    -- Second pass: validate each column
    DECLARE pass2_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, method, new_renamed, [action] FROM #coldata ORDER BY col_name;
    OPEN pass2_cur;
    FETCH NEXT FROM pass2_cur INTO @l_column, @method, @new_renamed, @l_action;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_fnd_renamed = 1 AND @l_all_renamed = 0 AND @new_renamed != 'N'
            THROW 50003, 'No temp table/column should exist unless all modified original columns are renamed.', 1;

        IF @method = 'C'
        BEGIN
            IF @new_renamed NOT IN ('N','C')
            BEGIN
                DECLARE @v_msg2 VARCHAR(200);
                SET @v_msg2 = 'Found ' + @l_column + ' In temporary table, but was expecting temporary column.';
                THROW 50003, @v_msg2, 1;
            END;
            IF @p_use_ctas = 1
            BEGIN
                DECLARE @v_msg3 VARCHAR(200);
                SET @v_msg3 = @l_column + ' logic would use CTAS, but CTAS was not requested.';
                THROW 50003, @v_msg3, 1;
            END;
        END
        ELSE IF @method = 'T'
        BEGIN
            IF @new_renamed NOT IN ('N','T')
            BEGIN
                DECLARE @v_msg4 VARCHAR(200);
                SET @v_msg4 = 'Found ' + @l_column + ' In temporary column, but was expecting temporary table.';
                THROW 50003, @v_msg4, 1;
            END;
            IF @p_use_ctas = 0
            BEGIN
                DECLARE @v_msg5 VARCHAR(200);
                SET @v_msg5 = @l_column + ' logic would use Temp Columns, but CTAS was requested.';
                THROW 50003, @v_msg5, 1;
            END;
        END
        ELSE
        BEGIN
            IF @new_renamed != 'N'
            BEGIN
                DECLARE @v_msg6 VARCHAR(200);
                SET @v_msg6 = 'Found ' + @l_column + ' In temporary column/table, but was expecting none.';
                THROW 50003, @v_msg6, 1;
            END;
        END;

        IF @method IN ('C','T') AND @l_action != @l_tc_action
            THROW 50003, 'Found a mixture of Apply/Rollback actions, should be only one.', 1;

        FETCH NEXT FROM pass2_cur INTO @l_column, @method, @new_renamed, @l_action;
    END;
    CLOSE pass2_cur;
    DEALLOCATE pass2_cur;

    IF @l_fnd_temp = 1 AND @l_all_temp = 0
        THROW 50003, 'Creation of temporary column/table is one operation, but not all are present.', 1;
END;
GO

-- ============================================================
-- PROCEDURE: create_out_of_place
-- Issues ALTER TABLE ADD or CREATE TABLE _TMP DDL for out-of-place columns.
-- EXECUTE IMMEDIATE -> EXEC sp_executesql.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_create_out_of_place]
    @p_table VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql         NVARCHAR(MAX) = NULL;
    DECLARE @l_column      VARCHAR(30);
    DECLARE @l_method      CHAR(1);
    DECLARE @l_data_type   VARCHAR(15);
    DECLARE @l_data_prec   INT;
    DECLARE @l_data_scale  INT;
    DECLARE @l_use_ctas    BIT;
    DECLARE @l_first       BIT = 1;

    -- Determine mode from first C or T method
    SELECT TOP 1 @l_method = method FROM #coldata WHERE method IN ('C','T') ORDER BY col_name;

    IF @l_method = 'C'
    BEGIN
        SET @l_use_ctas = 0;
        SET @l_sql = 'ALTER TABLE ' + @p_table + ' ADD (';
    END
    ELSE IF @l_method = 'T'
    BEGIN
        SET @l_use_ctas = 1;
        SET @l_sql = 'CREATE TABLE ' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, 1) + ' (';

        -- Add PK columns first (for CTAS temp table)
        DECLARE pk_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT kcu.COLUMN_NAME, c.DATA_TYPE,
                   c.CHARACTER_MAXIMUM_LENGTH, c.NUMERIC_PRECISION, c.NUMERIC_SCALE
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
               AND kcu.TABLE_NAME      = tc.TABLE_NAME
            JOIN INFORMATION_SCHEMA.COLUMNS c
                ON c.TABLE_NAME  = tc.TABLE_NAME
               AND c.COLUMN_NAME = kcu.COLUMN_NAME
            WHERE tc.TABLE_NAME       = UPPER(@p_table)
              AND tc.CONSTRAINT_TYPE  = 'PRIMARY KEY'
            ORDER BY kcu.ORDINAL_POSITION;

        DECLARE @pk_col  VARCHAR(128);
        DECLARE @pk_dt   VARCHAR(30);
        DECLARE @pk_len  INT;
        DECLARE @pk_prec INT;
        DECLARE @pk_scl  INT;

        OPEN pk_cur;
        FETCH NEXT FROM pk_cur INTO @pk_col, @pk_dt, @pk_len, @pk_prec, @pk_scl;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @pk_ora_type VARCHAR(15) =
                CASE WHEN @pk_dt IN ('int','bigint','decimal','numeric','float','real') THEN 'NUMBER'
                     ELSE 'VARCHAR2' END;
            DECLARE @pk_prec_use INT = CASE WHEN @pk_ora_type = 'VARCHAR2' THEN @pk_len ELSE @pk_prec END;
            SET @l_sql = @l_sql
                + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + @pk_col + ' '
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@pk_ora_type, @pk_prec_use, @pk_scl);
            SET @l_first = 0;
            FETCH NEXT FROM pk_cur INTO @pk_col, @pk_dt, @pk_len, @pk_prec, @pk_scl;
        END;
        CLOSE pk_cur;
        DEALLOCATE pk_cur;
    END;

    IF @l_sql IS NULL
    BEGIN
        -- No C or T method columns; nothing to do
        RETURN;
    END;

    -- Add the changed columns
    DECLARE ocp_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, data_type, data_precision_length, data_scale
        FROM #coldata WHERE method IN ('C','T')
        ORDER BY col_name;

    OPEN ocp_cur;
    FETCH NEXT FROM ocp_cur INTO @l_column, @l_data_type, @l_data_prec, @l_data_scale;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @l_sql = @l_sql
            + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_column, @l_use_ctas)
            + ' '
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@l_data_type, @l_data_prec, @l_data_scale);
        SET @l_first = 0;
        FETCH NEXT FROM ocp_cur INTO @l_column, @l_data_type, @l_data_prec, @l_data_scale;
    END;
    CLOSE ocp_cur;
    DEALLOCATE ocp_cur;

    -- Close the DDL statement
    IF @l_use_ctas = 1
    BEGIN
        -- Add PRIMARY KEY constraint
        SET @l_sql = @l_sql + ', PRIMARY KEY (';
        DECLARE @l_first2 BIT = 1;
        DECLARE pk2_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT kcu.COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
               AND kcu.TABLE_NAME      = tc.TABLE_NAME
            WHERE tc.TABLE_NAME      = UPPER(@p_table)
              AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
            ORDER BY kcu.ORDINAL_POSITION;

        DECLARE @pk2_col VARCHAR(128);
        OPEN pk2_cur;
        FETCH NEXT FROM pk2_cur INTO @pk2_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first2 = 0 THEN ',' ELSE '' END + @pk2_col;
            SET @l_first2 = 0;
            FETCH NEXT FROM pk2_cur INTO @pk2_col;
        END;
        CLOSE pk2_cur;
        DEALLOCATE pk2_cur;
        SET @l_sql = @l_sql + ')';
        -- Oracle had USING INDEX here; omitted in Azure SQL (PK automatically creates clustered index)
    END;
    SET @l_sql = @l_sql + ')';

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] 'Create Out Of Place Table/Columns', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err1 VARCHAR(MAX) = ERROR_MESSAGE() + ' State: ' + CAST(ERROR_STATE() AS VARCHAR);
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err1;
        THROW 50099, 'DTL_EXCEPTION raised in create_out_of_place', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: is_oop_populated
-- Checks whether the out-of-place temp columns/table have any populated values.
-- Returns result via OUTPUT parameter (replaces Oracle BOOLEAN RETURN).
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_is_oop_populated]
    @p_table      VARCHAR(255),
    @p_use_ctas   BIT,
    @p_parallel   INT = 0,
    @result       BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql    NVARCHAR(MAX) = NULL;
    DECLARE @l_column VARCHAR(30);
    DECLARE @l_first  BIT = 1;
    DECLARE @l_dummy  VARCHAR(1);

    SET @result = 0;

    DECLARE oop_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name FROM #coldata WHERE method IN ('C','T') ORDER BY col_name;
    OPEN oop_cur;
    FETCH NEXT FROM oop_cur INTO @l_column;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_sql IS NULL
            SET @l_sql = 'SELECT TOP 1 NULL FROM '
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, @p_use_ctas)
                + ' t WHERE ';
        SET @l_sql = @l_sql
            + CASE WHEN @l_first = 0 THEN ' OR ' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_column, @p_use_ctas)
            + ' IS NOT NULL';
        SET @l_first = 0;
        FETCH NEXT FROM oop_cur INTO @l_column;
    END;
    CLOSE oop_cur;
    DEALLOCATE oop_cur;

    IF @l_sql IS NOT NULL
    BEGIN
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
            'Querying whether out-of-place columns have been populated', @l_sql;
        BEGIN TRY
            CREATE TABLE #oop_check (dummy VARCHAR(1));
            INSERT INTO #oop_check EXEC sp_executesql @l_sql;
            IF @@ROWCOUNT > 0
                SET @result = 1;
            ELSE
                SET @result = 0;
            DROP TABLE IF EXISTS #oop_check;
        END TRY
        BEGIN CATCH
            DROP TABLE IF EXISTS #oop_check;
            DECLARE @err2 VARCHAR(MAX) = ERROR_MESSAGE();
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err2;
            THROW 50099, 'DTL_EXCEPTION raised in is_oop_populated', 1;
        END CATCH;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
    END
    ELSE
    BEGIN
        THROW 50004, 'Requested to check if Out Of Place Table/Column is populated, but we do not need Out Of Place processing.', 1;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: populate_tmp
-- Copies data from original (renamed _ORIG) columns into temp column or temp table.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_populate_tmp]
    @p_table    VARCHAR(255),
    @p_use_ctas BIT,
    @p_parallel INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql    NVARCHAR(MAX);
    DECLARE @l_column VARCHAR(30);
    DECLARE @l_first  BIT = 1;

    IF @p_use_ctas = 1
    BEGIN
        -- INSERT INTO temp_table (pk_cols, changed_cols) SELECT pk_cols, orig_cols FROM source
        SET @l_sql = 'INSERT INTO ' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, 1) + ' t (';

        -- PK columns
        DECLARE pk_ptmp CURSOR LOCAL FAST_FORWARD FOR
            SELECT kcu.COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
               AND kcu.TABLE_NAME      = tc.TABLE_NAME
            WHERE tc.TABLE_NAME = UPPER(@p_table) AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
            ORDER BY kcu.ORDINAL_POSITION;

        DECLARE @pk_c VARCHAR(128);
        OPEN pk_ptmp;
        FETCH NEXT FROM pk_ptmp INTO @pk_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END + @pk_c;
            SET @l_first = 0;
            FETCH NEXT FROM pk_ptmp INTO @pk_c;
        END;
        CLOSE pk_ptmp; DEALLOCATE pk_ptmp;

        -- Changed columns (same name in tmp table)
        DECLARE ch_ptmp CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'T' ORDER BY col_name;
        DECLARE @ch_c VARCHAR(30);
        OPEN ch_ptmp;
        FETCH NEXT FROM ch_ptmp INTO @ch_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + ',' + @ch_c;
            FETCH NEXT FROM ch_ptmp INTO @ch_c;
        END;
        CLOSE ch_ptmp; DEALLOCATE ch_ptmp;

        SET @l_sql = @l_sql + ') SELECT ';
        SET @l_first = 1;

        -- SELECT PK columns from source
        DECLARE pk_ptmp2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT kcu.COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
               AND kcu.TABLE_NAME      = tc.TABLE_NAME
            WHERE tc.TABLE_NAME = UPPER(@p_table) AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
            ORDER BY kcu.ORDINAL_POSITION;
        OPEN pk_ptmp2;
        FETCH NEXT FROM pk_ptmp2 INTO @pk_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END + @pk_c;
            SET @l_first = 0;
            FETCH NEXT FROM pk_ptmp2 INTO @pk_c;
        END;
        CLOSE pk_ptmp2; DEALLOCATE pk_ptmp2;

        -- SELECT orig (_ORIG) columns
        DECLARE ch_ptmp2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'T' ORDER BY col_name;
        OPEN ch_ptmp2;
        FETCH NEXT FROM ch_ptmp2 INTO @ch_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@ch_c);
            SET @l_first = 0;
            FETCH NEXT FROM ch_ptmp2 INTO @ch_c;
        END;
        CLOSE ch_ptmp2; DEALLOCATE ch_ptmp2;

        -- WHERE clause: any orig col IS NOT NULL
        SET @l_sql = @l_sql + ' FROM ' + @p_table + ' s WHERE ';
        SET @l_first = 1;
        DECLARE wh_ptmp CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'T' ORDER BY col_name;
        OPEN wh_ptmp;
        FETCH NEXT FROM wh_ptmp INTO @ch_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ' OR ' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@ch_c) + ' IS NOT NULL';
            SET @l_first = 0;
            FETCH NEXT FROM wh_ptmp INTO @ch_c;
        END;
        CLOSE wh_ptmp; DEALLOCATE wh_ptmp;
    END
    ELSE
    BEGIN
        -- UPDATE table SET _TMP_col = _ORIG_col WHERE any _ORIG_col IS NOT NULL
        SET @l_sql = 'UPDATE ' + @p_table + ' SET ';
        DECLARE upd_ptmp CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'C' ORDER BY col_name;
        DECLARE @upd_c VARCHAR(30);
        OPEN upd_ptmp;
        FETCH NEXT FROM upd_ptmp INTO @upd_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@upd_c, 0)
                + ' = '
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@upd_c);
            SET @l_first = 0;
            FETCH NEXT FROM upd_ptmp INTO @upd_c;
        END;
        CLOSE upd_ptmp; DEALLOCATE upd_ptmp;

        SET @l_sql = @l_sql + ' WHERE ';
        SET @l_first = 1;
        DECLARE wh_ptmp2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'C' ORDER BY col_name;
        OPEN wh_ptmp2;
        FETCH NEXT FROM wh_ptmp2 INTO @upd_c;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ' OR ' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@upd_c) + ' IS NOT NULL';
            SET @l_first = 0;
            FETCH NEXT FROM wh_ptmp2 INTO @upd_c;
        END;
        CLOSE wh_ptmp2; DEALLOCATE wh_ptmp2;
    END;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
        'Populate Out Of Place Table/Columns', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err3 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err3;
        THROW 50099, 'DTL_EXCEPTION raised in populate_tmp', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: set_orig_null
-- NULLs the _ORIG columns on the base table for out-of-place columns.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_orig_null]
    @p_table VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql   NVARCHAR(MAX) = 'UPDATE ' + @p_table + ' SET ';
    DECLARE @l_col   VARCHAR(30);
    DECLARE @l_first BIT = 1;
    DECLARE @where   NVARCHAR(MAX) = '';
    DECLARE @wfirst  BIT = 1;

    DECLARE son_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name FROM #coldata WHERE method IN ('C','T') ORDER BY col_name;
    OPEN son_cur;
    FETCH NEXT FROM son_cur INTO @l_col;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @l_sql  = @l_sql  + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col) + ' = NULL';
        SET @where  = @where  + CASE WHEN @wfirst = 0 THEN ' OR ' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col) + ' IS NOT NULL';
        SET @l_first = 0; SET @wfirst = 0;
        FETCH NEXT FROM son_cur INTO @l_col;
    END;
    CLOSE son_cur; DEALLOCATE son_cur;

    SET @l_sql = @l_sql + ' WHERE ' + @where;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] 'Null columns for data type change', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err4 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err4;
        THROW 50099, 'DTL_EXCEPTION raised in set_orig_null', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: update_decreasing_varchar
-- For VARCHAR2 in-place decreasing columns: SUBSTR to target length before modifying.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_update_decreasing_varchar]
    @p_table VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql   NVARCHAR(MAX) = NULL;
    DECLARE @l_col   VARCHAR(30);
    DECLARE @l_prec  INT;
    DECLARE @l_tprec INT;
    DECLARE @l_type  VARCHAR(15);
    DECLARE @l_meth  CHAR(1);
    DECLARE @l_first BIT = 1;
    DECLARE @wfirst  BIT = 1;
    DECLARE @where   NVARCHAR(MAX) = '';

    -- SET clause
    DECLARE udv_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, data_type, data_precision_length, tmp_precision_length, method
        FROM #coldata
        WHERE data_type = 'VARCHAR2' AND method = 'I' AND data_precision_length < tmp_precision_length
        ORDER BY col_name;

    OPEN udv_cur;
    FETCH NEXT FROM udv_cur INTO @l_col, @l_type, @l_prec, @l_tprec, @l_meth;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_first = 1
            SET @l_sql = 'UPDATE ' + @p_table + ' SET ';
        SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
            + ' = SUBSTRING('
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
            + ',1,' + CAST(@l_prec AS VARCHAR(10)) + ')';
        SET @l_first = 0;
        FETCH NEXT FROM udv_cur INTO @l_col, @l_type, @l_prec, @l_tprec, @l_meth;
    END;
    CLOSE udv_cur; DEALLOCATE udv_cur;

    IF @l_sql IS NULL RETURN;

    -- WHERE clause
    DECLARE udv_wh CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, data_precision_length
        FROM #coldata
        WHERE data_type = 'VARCHAR2' AND method = 'I' AND data_precision_length < tmp_precision_length
        ORDER BY col_name;
    DECLARE @wc VARCHAR(30); DECLARE @wp INT;
    OPEN udv_wh;
    FETCH NEXT FROM udv_wh INTO @wc, @wp;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @where = @where + CASE WHEN @wfirst = 0 THEN ' OR ' ELSE '' END
            + 'LEN(' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@wc)
            + ') > ' + CAST(@wp AS VARCHAR(10));
        SET @wfirst = 0;
        FETCH NEXT FROM udv_wh INTO @wc, @wp;
    END;
    CLOSE udv_wh; DEALLOCATE udv_wh;

    SET @l_sql = @l_sql + ' WHERE ' + @where;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
        'Perform in-place update for decreasing varchar2 length', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err5 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err5;
        THROW 50099, 'DTL_EXCEPTION raised in update_decreasing_varchar', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: modify_precisions
-- Issues ALTER TABLE MODIFY for changed column precision/types.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_modify_precisions]
    @p_table VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql  NVARCHAR(MAX) = NULL;
    DECLARE @l_col  VARCHAR(30);
    DECLARE @l_dt   VARCHAR(15);
    DECLARE @l_prec INT;
    DECLARE @l_scl  INT;
    DECLARE @l_tdt  VARCHAR(15);
    DECLARE @l_tprec INT;
    DECLARE @l_tscl INT;
    DECLARE @l_meth CHAR(1);
    DECLARE @l_first BIT = 1;

    DECLARE mp_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, data_type, data_precision_length, data_scale,
               tmp_type, tmp_precision_length, tmp_scale, method
        FROM #coldata WHERE method != 'N'
        ORDER BY col_name;

    OPEN mp_cur;
    FETCH NEXT FROM mp_cur INTO @l_col, @l_dt, @l_prec, @l_scl,
                                @l_tdt, @l_tprec, @l_tscl, @l_meth;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @new_dt_mp VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@l_dt,  @l_prec, @l_scl);
        DECLARE @old_dt_mp VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@l_tdt, @l_tprec, @l_tscl);

        IF @new_dt_mp != @old_dt_mp
        BEGIN
            IF @l_first = 1
                SET @l_sql = 'ALTER TABLE ' + @p_table + ' MODIFY (';
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
                + ' ' + @new_dt_mp;
            SET @l_first = 0;
        END;
        FETCH NEXT FROM mp_cur INTO @l_col, @l_dt, @l_prec, @l_scl,
                                    @l_tdt, @l_tprec, @l_tscl, @l_meth;
    END;
    CLOSE mp_cur; DEALLOCATE mp_cur;

    IF @l_sql IS NULL RETURN;

    SET @l_sql = @l_sql + ')';

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl] 'Modify column precisions', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err6 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err6;
        THROW 50099, 'DTL_EXCEPTION raised in modify_precisions', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: is_orig_populated
-- Checks whether original _ORIG columns have any non-null values.
-- Returns BIT via OUTPUT.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_is_orig_populated]
    @p_table    VARCHAR(255),
    @p_parallel INT = 0,
    @result     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql  NVARCHAR(MAX) = NULL;
    DECLARE @l_col  VARCHAR(30);
    DECLARE @l_first BIT = 1;

    SET @result = 0;

    DECLARE iop_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name FROM #coldata WHERE method IN ('C','T') ORDER BY col_name;
    OPEN iop_cur;
    FETCH NEXT FROM iop_cur INTO @l_col;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_sql IS NULL
            SET @l_sql = 'SELECT TOP 1 NULL FROM ' + @p_table + ' t WHERE ';
        SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ' OR ' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col) + ' IS NOT NULL';
        SET @l_first = 0;
        FETCH NEXT FROM iop_cur INTO @l_col;
    END;
    CLOSE iop_cur; DEALLOCATE iop_cur;

    IF @l_sql IS NOT NULL
    BEGIN
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
            'Querying whether original columns have been populated', @l_sql;
        BEGIN TRY
            CREATE TABLE #orig_check (dummy VARCHAR(1));
            INSERT INTO #orig_check EXEC sp_executesql @l_sql;
            SET @result = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
            DROP TABLE IF EXISTS #orig_check;
        END TRY
        BEGIN CATCH
            DROP TABLE IF EXISTS #orig_check;
            DECLARE @err7 VARCHAR(MAX) = ERROR_MESSAGE();
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err7;
            THROW 50099, 'DTL_EXCEPTION raised in is_orig_populated', 1;
        END CATCH;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
    END
    ELSE
    BEGIN
        THROW 50004, 'Requested to check if Original column(s) are populated, but we do not need Out Of Place processing.', 1;
    END;
END;
GO

-- ============================================================
-- PROCEDURE: populate_orig_from_tmp
-- Copies data back from temp col/table into the _ORIG columns on the base table.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_populate_orig_from_tmp]
    @p_table    VARCHAR(255),
    @p_use_ctas BIT,
    @p_parallel INT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql  NVARCHAR(MAX);
    DECLARE @l_col  VARCHAR(30);
    DECLARE @l_first BIT = 1;

    IF @p_use_ctas = 1
    BEGIN
        -- UPDATE (SELECT o.orig, n.tmp FROM base o JOIN tmp n ON pk) SET orig = tmp
        SET @l_sql = 'UPDATE (SELECT ';
        DECLARE oft_ctas CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'T' ORDER BY col_name;
        OPEN oft_ctas;
        FETCH NEXT FROM oft_ctas INTO @l_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + 'o.' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
                + ',n.' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_col, 1);
            SET @l_first = 0;
            FETCH NEXT FROM oft_ctas INTO @l_col;
        END;
        CLOSE oft_ctas; DEALLOCATE oft_ctas;

        SET @l_sql = @l_sql + ' FROM ' + @p_table + ' o JOIN '
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, 1) + ' n ON (';

        SET @l_first = 1;
        DECLARE oft_pk CURSOR LOCAL FAST_FORWARD FOR
            SELECT kcu.COLUMN_NAME
            FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
               AND kcu.TABLE_NAME      = tc.TABLE_NAME
            WHERE tc.TABLE_NAME = UPPER(@p_table) AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
            ORDER BY kcu.ORDINAL_POSITION;
        DECLARE @pk_oft VARCHAR(128);
        OPEN oft_pk;
        FETCH NEXT FROM oft_pk INTO @pk_oft;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ' AND ' ELSE '' END
                + 'o.' + @pk_oft + ' = n.' + @pk_oft;
            SET @l_first = 0;
            FETCH NEXT FROM oft_pk INTO @pk_oft;
        END;
        CLOSE oft_pk; DEALLOCATE oft_pk;

        SET @l_sql = @l_sql + ') ) SET ';
        SET @l_first = 1;
        DECLARE oft_set CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'T' ORDER BY col_name;
        OPEN oft_set;
        FETCH NEXT FROM oft_set INTO @l_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
                + ' = ' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_col, 1);
            SET @l_first = 0;
            FETCH NEXT FROM oft_set INTO @l_col;
        END;
        CLOSE oft_set; DEALLOCATE oft_set;
    END
    ELSE
    BEGIN
        -- UPDATE table SET orig = tmp_col WHERE any tmp IS NOT NULL
        SET @l_sql = 'UPDATE ' + @p_table + ' SET ';
        DECLARE oft_col CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'C' ORDER BY col_name;
        OPEN oft_col;
        FETCH NEXT FROM oft_col INTO @l_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
                + ' = ' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_col, 0);
            SET @l_first = 0;
            FETCH NEXT FROM oft_col INTO @l_col;
        END;
        CLOSE oft_col; DEALLOCATE oft_col;

        SET @l_sql = @l_sql + ' WHERE ';
        SET @l_first = 1;
        DECLARE oft_wh CURSOR LOCAL FAST_FORWARD FOR
            SELECT col_name FROM #coldata WHERE method = 'C' ORDER BY col_name;
        OPEN oft_wh;
        FETCH NEXT FROM oft_wh INTO @l_col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ' OR ' ELSE '' END
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_col, 0) + ' IS NOT NULL';
            SET @l_first = 0;
            FETCH NEXT FROM oft_wh INTO @l_col;
        END;
        CLOSE oft_wh; DEALLOCATE oft_wh;
    END;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
        'Populate original columns from Out of place table/columns', @l_sql;
    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @err8 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err8;
        THROW 50099, 'DTL_EXCEPTION raised in populate_orig_from_tmp', 1;
    END CATCH;
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
END;
GO

-- ============================================================
-- PROCEDURE: drop_tmp
-- Drops or sets unused temp columns/table after data has been copied.
-- Oracle: SET UNUSED not available in Azure SQL; uses DROP column/table only.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_tmp]
    @p_table      VARCHAR(255),
    @p_use_ctas   BIT,
    @p_set_unused BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_sql       NVARCHAR(MAX) = NULL;
    DECLARE @l_col       VARCHAR(30);
    DECLARE @l_first     BIT = 1;
    DECLARE @l_col_list  VARCHAR(4000) = '';
    DECLARE @l_temp_table VARCHAR(30);
    DECLARE @l_multi     INT;

    -- Build column list (includes PK columns for CTAS drop check)
    DECLARE pk_dt CURSOR LOCAL FAST_FORWARD FOR
        SELECT kcu.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
            ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
           AND kcu.TABLE_NAME      = tc.TABLE_NAME
        WHERE tc.TABLE_NAME = UPPER(@p_table) AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
        ORDER BY kcu.ORDINAL_POSITION;
    DECLARE @pk_dtc VARCHAR(128);
    OPEN pk_dt;
    FETCH NEXT FROM pk_dt INTO @pk_dtc;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @l_col_list = @l_col_list + CASE WHEN @l_first = 0 THEN ',' ELSE '' END + @pk_dtc;
        SET @l_first = 0;
        FETCH NEXT FROM pk_dt INTO @pk_dtc;
    END;
    CLOSE pk_dt; DEALLOCATE pk_dt;

    -- DDL statement: ALTER TABLE [temp_table] DROP (...)
    SET @l_temp_table = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_table_name](@p_table, @p_use_ctas);
    -- Note: Oracle had 'SET UNUSED' option; Azure SQL only supports DROP COLUMN (documented deviation).
    SET @l_sql = 'ALTER TABLE ' + @l_temp_table + ' DROP (';
    SET @l_first = 1;

    DECLARE dt_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name FROM #coldata WHERE method IN ('C','T') ORDER BY col_name;
    OPEN dt_cur;
    FETCH NEXT FROM dt_cur INTO @l_col;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @l_sql = @l_sql + CASE WHEN @l_first = 0 THEN ',' ELSE '' END
            + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_temp_column_name](@l_col, @p_use_ctas);
        SET @l_col_list = @l_col_list + CASE WHEN @l_col_list <> '' THEN ',' ELSE '' END + UPPER(@l_col);
        SET @l_first = 0;
        FETCH NEXT FROM dt_cur INTO @l_col;
    END;
    CLOSE dt_cur; DEALLOCATE dt_cur;

    SET @l_sql = @l_sql + ')';

    IF @p_use_ctas = 1
    BEGIN
        -- Acquire exclusive lock on temp table (equivalent to Oracle LOCK TABLE ... IN EXCLUSIVE MODE)
        BEGIN TRY
            EXEC sp_executesql N'SELECT TOP 0 * FROM ' + @l_temp_table + N' WITH (TABLOCKX, HOLDLOCK)';
        END TRY
        BEGIN CATCH
            -- Non-fatal lock hint failure; continue
        END CATCH;

        -- Count columns NOT in our list -> if 0 then we own the whole table and can DROP it
        SELECT @l_multi = COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @l_temp_table
          AND ',' + @l_col_list + ',' NOT LIKE '%,' + COLUMN_NAME + ',%';

        IF @l_multi = 0
        BEGIN
            -- Drop the whole temp table
            DECLARE @drop_sql NVARCHAR(MAX) = 'DROP TABLE IF EXISTS ' + @l_temp_table;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
                'Dropping Out of place table', @drop_sql;
            BEGIN TRY
                EXEC sp_executesql @drop_sql;
            END TRY
            BEGIN CATCH
                DECLARE @err9 VARCHAR(MAX) = ERROR_MESSAGE();
                EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err9;
                THROW 50099, 'DTL_EXCEPTION raised in drop_tmp (drop table)', 1;
            END CATCH;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
        END;
    END
    ELSE
    BEGIN
        SET @l_multi = 1; -- force DROP COLUMN path
    END;

    IF @p_use_ctas = 0 OR @l_multi > 0
    BEGIN
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
            'Dropping Out of place columns', @l_sql;
        BEGIN TRY
            EXEC sp_executesql @l_sql;
        END TRY
        BEGIN CATCH
            DECLARE @err10 VARCHAR(MAX) = ERROR_MESSAGE();
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err10;
            THROW 50099, 'DTL_EXCEPTION raised in drop_tmp (drop columns)', 1;
        END CATCH;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
    END;
END;
GO

-- ============================================================
-- PROCEDURE: rename_orig
-- Renames _ORIG columns back to their original names.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_rename_orig]
    @p_table VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_col   VARCHAR(30);
    DECLARE @l_meth  CHAR(1);
    DECLARE @l_sql   NVARCHAR(MAX);

    DECLARE ro_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, method FROM #coldata ORDER BY col_name;
    OPEN ro_cur;
    FETCH NEXT FROM ro_cur INTO @l_col, @l_meth;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_meth != 'N'
        BEGIN
            SET @l_sql = 'ALTER TABLE ' + @p_table + ' RENAME COLUMN '
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col)
                + ' TO ' + @l_col;

            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
                'Renaming column ' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col) + '->' + @l_col, @l_sql;
            BEGIN TRY
                EXEC sp_executesql @l_sql;
            END TRY
            BEGIN CATCH
                DECLARE @err11 VARCHAR(MAX) = ERROR_MESSAGE();
                EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err11;
                THROW 50099, 'DTL_EXCEPTION raised in rename_orig', 1;
            END CATCH;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
        END;
        FETCH NEXT FROM ro_cur INTO @l_col, @l_meth;
    END;
    CLOSE ro_cur; DEALLOCATE ro_cur;
END;
GO

-- ============================================================
-- PROCEDURE: modify_types
-- Orchestrates the full column modification workflow:
--   rename orig -> create/populate out-of-place -> modify precisions -> copy back -> drop tmp -> rename
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_modify_types]
    @p_table      VARCHAR(255),
    @p_use_ctas   BIT,
    @p_parallel   INT = 0,
    @p_set_unused BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @l_col                  VARCHAR(30);
    DECLARE @l_method               CHAR(1);
    DECLARE @l_tmp_renamed          CHAR(1);
    DECLARE @l_new_renamed          CHAR(1);
    DECLARE @l_data_type            VARCHAR(15);
    DECLARE @l_data_prec            INT;
    DECLARE @l_data_scl             INT;
    DECLARE @l_tmp_type             VARCHAR(15);
    DECLARE @l_tmp_prec             INT;
    DECLARE @l_tmp_scl              INT;
    DECLARE @l_action               CHAR(1);

    DECLARE @l_use_out_of_place     BIT = 0;
    DECLARE @l_create_out_of_place  BIT = 0;
    DECLARE @l_use_ctas             BIT = 0;
    DECLARE @l_populate_oop         BIT = 1;
    DECLARE @l_null_orig            BIT = 0;
    DECLARE @l_populate_orig        BIT = 1;
    DECLARE @l_tc_action            CHAR(1) = NULL;
    DECLARE @l_sql                  NVARCHAR(MAX);
    DECLARE @l_oop_result           BIT;
    DECLARE @l_orig_result          BIT;

    -- First pass: rename columns that haven't been renamed yet and determine flags
    DECLARE mt_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT col_name, method, tmp_renamed, new_renamed,
               data_type, data_precision_length, data_scale,
               tmp_type, tmp_precision_length, tmp_scale, [action]
        FROM #coldata ORDER BY col_name;

    OPEN mt_cur;
    FETCH NEXT FROM mt_cur INTO @l_col, @l_method, @l_tmp_renamed, @l_new_renamed,
        @l_data_type, @l_data_prec, @l_data_scl,
        @l_tmp_type, @l_tmp_prec, @l_tmp_scl, @l_action;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @l_method != 'N' AND @l_tmp_renamed != 'Y'
        BEGIN
            -- Rename original column to _ORIG
            SET @l_sql = 'ALTER TABLE ' + @p_table + ' RENAME COLUMN '
                + @l_col + ' TO '
                + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col);
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl]
                'Renaming column ' + @l_col + '->' + [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_rename_column_name](@l_col), @l_sql;
            BEGIN TRY
                EXEC sp_executesql @l_sql;
            END TRY
            BEGIN CATCH
                DECLARE @err12 VARCHAR(MAX) = ERROR_MESSAGE();
                EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_error] @err12;
                THROW 50099, 'DTL_EXCEPTION raised in modify_types (rename)', 1;
            END CATCH;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_dtl_success];
        END;

        IF @l_method IN ('C','T')
        BEGIN
            IF @l_new_renamed = 'N'
                SET @l_create_out_of_place = 1;
            SET @l_use_out_of_place = 1;

            -- Check if data type is actually changing (null_orig flag)
            DECLARE @new_dt_mt VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@l_data_type, @l_data_prec, @l_data_scl);
            DECLARE @old_dt_mt VARCHAR(60) = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_data_type](@l_tmp_type, @l_tmp_prec, @l_tmp_scl);
            IF @new_dt_mt != @old_dt_mt
                SET @l_null_orig = 1;

            IF @l_method = 'T'
                SET @l_use_ctas = 1;
        END;

        IF @l_tc_action IS NULL AND @l_method IN ('C','T')
            SET @l_tc_action = @l_action;

        FETCH NEXT FROM mt_cur INTO @l_col, @l_method, @l_tmp_renamed, @l_new_renamed,
            @l_data_type, @l_data_prec, @l_data_scl,
            @l_tmp_type, @l_tmp_prec, @l_tmp_scl, @l_action;
    END;
    CLOSE mt_cur; DEALLOCATE mt_cur;

    -- Apply or Rollback orchestration
    IF ISNULL(@l_tc_action, 'A') = 'A'
    BEGIN
        IF @l_create_out_of_place = 1
        BEGIN
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_create_out_of_place] @p_table;
        END
        ELSE IF @l_use_out_of_place = 1
        BEGIN
            -- Out-of-place table/column already existed; check if populated
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_is_oop_populated]
                @p_table, @l_use_ctas, @p_parallel, @l_oop_result OUTPUT;
            SET @l_populate_oop = CASE WHEN @l_oop_result = 1 THEN 0 ELSE 1 END;
        END;

        IF @l_use_out_of_place = 1 AND @l_populate_oop = 1
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_populate_tmp] @p_table, @l_use_ctas, @p_parallel;

        IF @l_use_out_of_place = 1 AND (@l_create_out_of_place = 1 OR @l_populate_oop = 1 OR @l_null_orig = 1)
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_orig_null] @p_table;
        ELSE IF @l_use_out_of_place = 1
        BEGIN
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_is_orig_populated]
                @p_table, @p_parallel, @l_orig_result OUTPUT;
            SET @l_populate_orig = CASE WHEN @l_orig_result = 1 THEN 0 ELSE 1 END;
        END;

        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_update_decreasing_varchar] @p_table;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_modify_precisions] @p_table;

        IF @l_use_out_of_place = 1
        BEGIN
            IF @l_populate_orig = 1
                EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_populate_orig_from_tmp] @p_table, @l_use_ctas, @p_parallel;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_tmp] @p_table, @l_use_ctas, @p_set_unused;
        END;
    END
    ELSE
    BEGIN
        -- Rolling Back
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_is_orig_populated]
            @p_table, @p_parallel, @l_orig_result OUTPUT;
        IF @l_orig_result = 0
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_populate_orig_from_tmp] @p_table, @l_use_ctas, @p_parallel;

        IF @l_null_orig = 1
        BEGIN
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_update_decreasing_varchar] @p_table;
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_modify_precisions] @p_table;
        END;

        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_tmp] @p_table, @l_use_ctas, @p_set_unused;
    END;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_rename_orig] @p_table;
END;
GO

-- ============================================================
-- PROCEDURE: change_precision_scale  (PUBLIC)
-- Main entry point. Parses change_list, determines method, executes column modification.
-- Converted from Oracle package procedure; nested sub-procs extracted as standalone.
-- Creates #coldata temp table shared with all sub-procedures.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_change_precision_scale]
    @p_table_name   VARCHAR(255),
    @p_change_list  VARCHAR(MAX),
    @p_parallel     INT  = 0,
    @p_increase_only BIT = 0,
    @p_use_ctas     BIT  = 0,
    @p_set_unused   BIT  = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Warm the is_release cache
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_init_is_release];

    DECLARE @is_release BIT = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_get_is_release]();
    DECLARE @l_use_ctas BIT;
    DECLARE @l_parms VARCHAR(MAX) =
        'Table Name: '       + ISNULL(@p_table_name,  'NULL') + CHAR(10)
        + 'Change List: '    + ISNULL(@p_change_list, 'NULL') + CHAR(10)
        + 'Increase only: '  + CASE WHEN @p_increase_only = 1 THEN 'True' ELSE 'False' END
        + ', Use CTAS: '     + CASE WHEN @p_use_ctas      = 1 THEN 'True' ELSE 'False' END;

    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr] 'CHANGE_PRECISION_SCALE', @l_parms;

    -- Create shared #coldata temp table used by all sub-procedures
    CREATE TABLE #coldata (
        col_name               VARCHAR(30)  NOT NULL PRIMARY KEY,
        data_type              VARCHAR(15)  NULL,
        data_precision_length  INT          NULL,
        data_scale             INT          NULL,
        tmp_renamed            CHAR(1)      NULL,   -- N=No, Y=Yes
        tmp_type               VARCHAR(15)  NULL,
        tmp_precision_length   INT          NULL,
        tmp_scale              INT          NULL,
        new_renamed            CHAR(1)      NULL,   -- N=No, C=Column, T=Table
        method                 CHAR(1)      NULL,   -- N=None, I=InPlace, C=OOPColumn, T=OOPTable
        [action]               CHAR(1)      NULL    -- A=Apply, R=Rollback
    );

    -- Resolve whether to use CTAS
    IF @p_use_ctas = 1
    BEGIN
        SET @l_use_ctas = 1;
        -- Verify table has a PK (required for CTAS)
        DECLARE @pk_check INT = 0;
        SELECT @pk_check = COUNT(*)
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_NAME = UPPER(@p_table_name) AND CONSTRAINT_TYPE = 'PRIMARY KEY';
        IF @pk_check = 0
            SET @l_use_ctas = 0; -- No PK -> fall back to column mode
    END
    ELSE
    BEGIN
        SET @l_use_ctas = 0;
    END;

    BEGIN TRY
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_process_change_list] @p_change_list;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_renamed] @p_table_name, @l_use_ctas;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_set_method]  @p_table_name, @p_increase_only, @l_use_ctas, @is_release;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_validate_data] @l_use_ctas;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_modify_types]
            @p_table_name, @l_use_ctas, @p_parallel,
            CASE WHEN @is_release = 1 AND @p_set_unused = 1 THEN 1 ELSE 0 END;
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_success];
    END TRY
    BEGIN CATCH
        DECLARE @err_num  INT          = ERROR_NUMBER();
        DECLARE @err_msg  VARCHAR(MAX) = ERROR_MESSAGE();
        IF @err_num = 50099
        BEGIN
            -- DTL_EXCEPTION: error already logged in debug detail
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_error]
                'See error in pdx_schema_upd_helper_debug_d';
            THROW 50001, 'Error from SQL Execution, Logged in pdx_schema_upd_helper_debug_d', 1;
        END
        ELSE
        BEGIN
            EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_debug_hdr_error] @err_msg;
            THROW 50001, 'Error not involving SQL Execution, Logged in pdx_schema_upd_helper_debug_h', 1;
        END;
    END CATCH;
END;
GO

-- ============================================================
-- PROCEDURE: drop_column  (PUBLIC)
-- For release-based schemas: use SET UNUSED (Oracle) = DROP COLUMN (Azure SQL - deviation documented).
-- For task-based schemas: DROP COLUMN.
-- Note: Azure SQL does not support ALTER TABLE ... SET UNUSED. DROP COLUMN is used for both modes.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_column]
    @p_table_name VARCHAR(255),
    @p_drop_list  VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Warm is_release cache
    EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_init_is_release];

    -- Oracle: release-based uses SET UNUSED, task-based uses DROP.
    -- Azure SQL: SET UNUSED not supported; always use DROP COLUMN (documented deviation in ErrorSheet K).
    DECLARE @l_sql NVARCHAR(MAX) =
        'ALTER TABLE ' + UPPER(@p_table_name) + ' DROP COLUMN ' + @p_drop_list;

    BEGIN TRY
        EXEC sp_executesql @l_sql;
    END TRY
    BEGIN CATCH
        DECLARE @dc_err VARCHAR(MAX) = ERROR_MESSAGE();
        THROW 50001, @dc_err, 1;
    END CATCH;
END;
GO

-- ============================================================
-- PROCEDURE: drop_unused  (PUBLIC)
-- Oracle: iterates user_unused_col_tabs and drops UNUSED columns.
-- Azure SQL: user_unused_col_tabs has no equivalent; this procedure is a no-op stub.
-- The concept of SET UNUSED / DROP UNUSED does not exist in Azure SQL.
-- ============================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_HELPER_drop_unused]
    @p_table_name VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Azure SQL has no concept of SET UNUSED / user_unused_col_tabs.
    -- Columns in Azure SQL are either present or dropped; there is no UNUSED state.
    -- This procedure is intentionally a no-op stub. DBA action required for equivalent cleanup.
    PRINT 'PKG_PDX_SCHEMA_UPDATER_HELPER_drop_unused: no-op in Azure SQL (SET UNUSED not supported).';
END;
GO
