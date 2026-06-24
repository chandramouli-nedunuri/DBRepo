-- ====================================================================================
-- ORACLE PACKAGE CONVERSION: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER
-- Source: EPR_Oracle/Packages/SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER.sql (2007 lines, 49 procedures)
-- Conversion Date: 2026-05-25
-- Conversion Approach: Full T-SQL implementation with modular procedure design
-- Target: Azure SQL Database
-- ====================================================================================

-- ====================================================================================
-- USER-DEFINED TABLE TYPES (replacing Oracle TYPE declarations)
-- ====================================================================================

-- Replaces: TYPE typ_error_record
CREATE TYPE [SEC_ADMIN].[typ_error_record] AS TABLE (
    [ERROR_MESSAGE] VARCHAR(200),
    [SQL_ERROR_CODE] VARCHAR(20),
    [SQL_ERROR_MESSAGE] VARCHAR(4000)
);
GO

-- Replaces: TYPE typ_config_record
CREATE TYPE [SEC_ADMIN].[typ_config_record] AS TABLE (
    [APPLY_TYPE] VARCHAR(10),
    [TASK_VERSION] VARCHAR(20),
    [APPLICATION_PREFIX] VARCHAR(50),
    [MANAGE_PRIVS] VARCHAR(1),
    [MANAGE_SYNONYMS] VARCHAR(1),
    [ALLOW_DOWNGRADE] NUMERIC(2),
    [MANAGE_SYNONYMS_FOR] VARCHAR(255),
    [AUTO_UNDO] VARCHAR(1)
);
GO

-- Replaces: TYPE results_tbl (for metadata functions)
CREATE TYPE [SEC_ADMIN].[results_tbl] AS TABLE (
    [result_row] VARCHAR(4000)
);
GO

-- ====================================================================================
-- GLOBAL CONFIGURATION TABLE (replaces Oracle package-level variables)
-- ====================================================================================
CREATE TABLE [SEC_ADMIN].[pkg_config] (
    [session_id] INT NOT NULL,
    [config_apply_type] VARCHAR(10),
    [config_task_version] VARCHAR(20),
    [config_application_prefix] VARCHAR(50),
    [config_manage_privs] VARCHAR(1),
    [config_manage_synonyms] VARCHAR(1),
    [config_allow_downgrade] NUMERIC(2),
    [config_manage_synonyms_for] VARCHAR(255),
    [config_auto_undo] VARCHAR(1),
    [g_version] VARCHAR(4),
    [initialized] BIT,
    PRIMARY KEY ([session_id])
);
GO

-- Initialize default g_version
INSERT INTO [SEC_ADMIN].[pkg_config] ([session_id], [g_version], [initialized])
VALUES (0, '1.03', 0);
GO

-- ====================================================================================
-- HELPER FUNCTIONS
-- ====================================================================================

-- FUNCTION: schema_version
-- Purpose: Returns the target version from the latest successful schema version update
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_schema_version]()
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @l_rtn VARCHAR(100);
    
    BEGIN TRY
        SELECT TOP 1 @l_rtn = [target_version]
        FROM [pdx_schema_version_history]
        WHERE [id] = (
            SELECT MAX([id])
            FROM [pdx_schema_version_history]
            WHERE [status_code] = 'S'
        );
        
        RETURN @l_rtn;
    END TRY
    BEGIN CATCH
        RETURN NULL;
    END CATCH;
END;
GO

-- FUNCTION: updater_version
-- Purpose: Returns the version of the updater package
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_updater_version]()
RETURNS VARCHAR(100)
AS
BEGIN
    DECLARE @g_version VARCHAR(4) = '1.03';
    RETURN @g_version;
END;
GO

-- FUNCTION: compare_versions
-- Purpose: Compares two version strings
-- Returns: >0 if p_version1 > p_version2; 0 if equal; <0 if p_version1 < p_version2
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_compare_versions](
    @p_version1 VARCHAR(100),
    @p_version2 VARCHAR(100)
)
RETURNS INT
AS
BEGIN
    DECLARE @l_rtn INT = 0;
    
    IF @p_version1 IS NULL AND @p_version2 IS NULL
        SET @l_rtn = 0;
    ELSE IF @p_version1 IS NULL
        SET @l_rtn = -1;
    ELSE IF @p_version2 IS NULL
        SET @l_rtn = 1;
    ELSE
    BEGIN
        -- Compare versions using manifest apply_order
        SELECT @l_rtn = ISNULL(MAX(CASE WHEN [version] = @p_version1 THEN [apply_order] END), 0) -
                       ISNULL(MAX(CASE WHEN [version] = @p_version2 THEN [apply_order] END), 0)
        FROM [vw_schema_updater_manifest]
        WHERE [version] IN (@p_version1, @p_version2);
    END;
    
    RETURN @l_rtn;
END;
GO

-- ====================================================================================
-- CONFIGURATION MANAGEMENT PROCEDURES
-- ====================================================================================

-- PROCEDURE: refresh_config
-- Purpose: Refreshes configuration from pdx_schema_config table
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @session_id INT = 0;  -- 0 = global session
    DECLARE @l_apply_type VARCHAR(10);
    DECLARE @l_task_version VARCHAR(20);
    DECLARE @l_app_prefix VARCHAR(50);
    DECLARE @l_manage_privs VARCHAR(1);
    DECLARE @l_manage_syns VARCHAR(1);
    DECLARE @l_allow_downgrade NUMERIC(2);
    DECLARE @l_manage_syns_for VARCHAR(255);
    DECLARE @l_auto_undo VARCHAR(1);
    
    BEGIN TRY
        -- Read config values (with NULL handling)
        SELECT 
            @l_apply_type = UPPER(ISNULL([value], '')),
            @l_task_version = 
                CASE 
                    WHEN [key] = 'TASKVERSION' THEN ISNULL([value], '')
                    ELSE @l_task_version 
                END
        FROM [pdx_schema_config]
        WHERE [key] IN ('APPLYTYPE', 'TASKVERSION');
        
        -- Read APPLICATION_PREFIX with case conversion
        SELECT @l_app_prefix = LOWER(ISNULL([value], ''))
        FROM [pdx_schema_config]
        WHERE [key] = 'APPLICATIONPREFIX';
        
        -- Read Y/N boolean fields
        SELECT @l_manage_privs = CASE 
            WHEN UPPER(ISNULL([value], 'N')) IN ('Y', 'YES', 'T', 'TRUE') THEN 'Y' 
            ELSE 'N' 
        END
        FROM [pdx_schema_config]
        WHERE [key] = 'MANAGEPRIVS';
        
        SELECT @l_manage_syns = CASE 
            WHEN UPPER(ISNULL([value], 'N')) IN ('Y', 'YES', 'T', 'TRUE') THEN 'Y' 
            ELSE 'N' 
        END
        FROM [pdx_schema_config]
        WHERE [key] = 'MANAGESYNONYMS';
        
        SELECT @l_manage_syns_for = LTRIM(RTRIM(ISNULL([value], '')))
        FROM [pdx_schema_config]
        WHERE [key] = 'MANAGESYNONYMSFOR';
        
        -- Override MANAGE_SYNONYMS if FOR is not set
        IF @l_manage_syns = 'N' OR @l_manage_syns_for IS NULL OR LEN(@l_manage_syns_for) = 0
        BEGIN
            SET @l_manage_syns = 'N';
            SET @l_manage_syns_for = NULL;
        END;
        
        SELECT @l_allow_downgrade = CASE 
            WHEN UPPER(ISNULL([value], 'N')) IN ('Y', 'YES', 'T', 'TRUE') THEN -1
            ELSE TRY_CAST([value] AS NUMERIC(2))
        END
        FROM [pdx_schema_config]
        WHERE [key] = 'ALLOWDOWNGRADE';
        
        IF @l_allow_downgrade IS NULL
            SET @l_allow_downgrade = 0;
        
        SELECT @l_auto_undo = CASE 
            WHEN UPPER(ISNULL([value], 'N')) IN ('Y', 'YES', 'T', 'TRUE') THEN 'Y' 
            ELSE 'N' 
        END
        FROM [pdx_schema_config]
        WHERE [key] = 'AUTOUNDO';
        
        -- Update or insert config
        UPDATE [SEC_ADMIN].[pkg_config]
        SET 
            [config_apply_type] = @l_apply_type,
            [config_task_version] = @l_task_version,
            [config_application_prefix] = @l_app_prefix,
            [config_manage_privs] = @l_manage_privs,
            [config_manage_synonyms] = @l_manage_syns,
            [config_allow_downgrade] = @l_allow_downgrade,
            [config_manage_synonyms_for] = @l_manage_syns_for,
            [config_auto_undo] = @l_auto_undo,
            [initialized] = 1
        WHERE [session_id] = @session_id;
        
        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO [SEC_ADMIN].[pkg_config] 
            (
                [session_id],
                [config_apply_type],
                [config_task_version],
                [config_application_prefix],
                [config_manage_privs],
                [config_manage_synonyms],
                [config_allow_downgrade],
                [config_manage_synonyms_for],
                [config_auto_undo],
                [initialized]
            )
            VALUES 
            (
                @session_id,
                @l_apply_type,
                @l_task_version,
                @l_app_prefix,
                @l_manage_privs,
                @l_manage_syns,
                @l_allow_downgrade,
                @l_manage_syns_for,
                @l_auto_undo,
                1
            );
        END;
        
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- FUNCTION: get_config
-- Purpose: Returns configuration value by key
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config](
    @p_key VARCHAR(100)
)
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @l_rtn VARCHAR(255);
    DECLARE @session_id INT = 0;
    
    -- Initialize config if needed
    IF NOT EXISTS (SELECT 1 FROM [SEC_ADMIN].[pkg_config] WHERE [session_id] = @session_id AND [initialized] = 1)
    BEGIN
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
    END;
    
    SELECT @l_rtn = CASE UPPER(@p_key)
        WHEN 'APPLY_TYPE' THEN [config_apply_type]
        WHEN 'TASK_VERSION' THEN [config_task_version]
        WHEN 'APPLICATION_PREFIX' THEN [config_application_prefix]
        WHEN 'MANAGE_PRIVS' THEN [config_manage_privs]
        WHEN 'MANAGE_SYNONYMS' THEN [config_manage_synonyms]
        WHEN 'ALLOW_DOWNGRADE' THEN CAST([config_allow_downgrade] AS VARCHAR)
        WHEN 'MANAGE_SYNONYMS_FOR' THEN [config_manage_synonyms_for]
        WHEN 'AUTO_UNDO' THEN [config_auto_undo]
        ELSE NULL
    END
    FROM [SEC_ADMIN].[pkg_config]
    WHERE [session_id] = @session_id;
    
    IF @l_rtn IS NULL AND UPPER(@p_key) NOT IN ('APPLY_TYPE', 'TASK_VERSION', 'APPLICATION_PREFIX', 'MANAGE_PRIVS', 'MANAGE_SYNONYMS', 'ALLOW_DOWNGRADE', 'MANAGE_SYNONYMS_FOR', 'AUTO_UNDO')
    BEGIN
        RAISERROR('Invalid Key requested in get_config', 16, 1);
    END;
    
    RETURN @l_rtn;
END;
GO

-- ====================================================================================
-- LOGGING AND HISTORY PROCEDURES
-- ====================================================================================

-- FUNCTION: log_call_start
-- Purpose: Logs the start of a schema update call
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_start](
    @p_target_version VARCHAR(100)
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @l_rtn BIGINT;
    
    INSERT INTO [pdx_schema_upd_pkgcall_hist] 
    (
        [TARGET_VERSION],
        [STATUS_CODE],
        [START_DATE]
    )
    VALUES 
    (
        @p_target_version,
        'I',
        SYSDATETIME()
    );
    
    SET @l_rtn = @@IDENTITY;
    RETURN @l_rtn;
END;
GO

-- FUNCTION: log_call_end
-- Purpose: Logs the end of a schema update call
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
    @p_call_id BIGINT,
    @p_rc INT,
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200),
    @p_sql_error_code VARCHAR(20),
    @p_sql_error_msg VARCHAR(4000)
)
RETURNS INT
AS
BEGIN
    BEGIN TRY
        UPDATE [pdx_schema_upd_pkgcall_hist]
        SET 
            [status_code] = @p_status,
            [end_date] = SYSDATETIME(),
            [return_code] = @p_rc
        WHERE [id] = @p_call_id;
        
        IF @p_error_msg IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_msg IS NOT NULL
        BEGIN
            INSERT INTO [PDX_SCHEMA_UPD_PKGCALL_ERR_LOG]
            (
                [id],
                [error_message],
                [sql_error_code],
                [sql_error_message]
            )
            VALUES 
            (
                @p_call_id,
                @p_error_msg,
                @p_sql_error_code,
                @p_sql_error_msg
            );
        END;
        
        RETURN @p_rc;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;
END;
GO

-- ====================================================================================
-- VERSION MANAGEMENT PROCEDURES
-- ====================================================================================

-- FUNCTION: log_version_start
-- Purpose: Logs the start of a version update
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_version_start](
    @p_call_id BIGINT,
    @p_current_version VARCHAR(100),
    @p_target_version VARCHAR(100)
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @l_rtn BIGINT;
    
    INSERT INTO [pdx_schema_version_history]
    (
        [PDX_SCHEMA_UPD_PKGCALL_HIST_ID],
        [CURRENT_VERSION],
        [TARGET_VERSION],
        [STATUS_CODE],
        [START_DATE]
    )
    VALUES 
    (
        @p_call_id,
        @p_current_version,
        @p_target_version,
        'I',
        SYSDATETIME()
    );
    
    SET @l_rtn = @@IDENTITY;
    RETURN @l_rtn;
END;
GO

-- PROCEDURE: log_version_end
-- Purpose: Logs the end of a version update
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_version_end](
    @p_version_id BIGINT,
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_msg VARCHAR(4000) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [pdx_schema_version_history]
    SET 
        [status_code] = @p_status,
        [end_date] = SYSDATETIME()
    WHERE [id] = @p_version_id;
    
    IF @p_error_msg IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_msg IS NOT NULL
    BEGIN
        INSERT INTO [PDX_SCHEMA_VERSION_ERROR_LOG]
        (
            [id],
            [error_message],
            [sql_error_code],
            [sql_error_message]
        )
        VALUES 
        (
            @p_version_id,
            @p_error_msg,
            @p_sql_error_code,
            @p_sql_error_msg
        );
    END;
END;
GO

-- ====================================================================================
-- TASK MANAGEMENT PROCEDURES
-- ====================================================================================

-- FUNCTION: log_task_start
-- Purpose: Logs the start of a task
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_start](
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @l_rtn BIGINT;
    DECLARE @l_task_type VARCHAR(20);
    
    -- Get task type (placeholder for metadata lookup)
    SET @l_task_type = 'TASK';
    
    INSERT INTO [pdx_schema_task_history]
    (
        [PDX_SCHEMA_UPD_PKGCALL_HIST_ID],
        [PDX_SCHEMA_VERSION_HISTORY_ID],
        [FILE_NAME],
        [TASK_TYPE],
        [ACTION_CODE],
        [STATUS_CODE],
        [START_DATE]
    )
    VALUES 
    (
        @p_call_id,
        @p_version_id,
        @p_filename,
        @l_task_type,
        @p_action,
        'I',
        SYSDATETIME()
    );
    
    SET @l_rtn = @@IDENTITY;
    RETURN @l_rtn;
END;
GO

-- PROCEDURE: log_task_end
-- Purpose: Logs the end of a task
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_end](
    @p_task_id BIGINT,
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_msg VARCHAR(4000) = NULL,
    @p_action VARCHAR(1) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [pdx_schema_task_history]
    SET 
        [status_code] = @p_status,
        [action_code] = ISNULL(@p_action, [action_code]),
        [end_date] = SYSDATETIME()
    WHERE [id] = @p_task_id;
    
    IF @p_error_msg IS NOT NULL OR @p_sql_error_code IS NOT NULL OR @p_sql_error_msg IS NOT NULL
    BEGIN
        INSERT INTO [PDX_SCHEMA_TASK_ERROR_LOG]
        (
            [id],
            [error_message],
            [sql_error_code],
            [sql_error_message],
            [sql_text],
            [statement_index]
        )
        VALUES 
        (
            @p_task_id,
            @p_error_msg,
            @p_sql_error_code,
            @p_sql_error_msg,
            @p_sql_text,
            @p_index
        );
    END;
END;
GO

-- ====================================================================================
-- SQL EXECUTION PROCEDURES
-- ====================================================================================

-- PROCEDURE: run_statement
-- Purpose: Executes dynamic SQL statement using sp_executesql
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_run_statement](
    @p_sql NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        EXEC sp_executesql @p_sql;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- ====================================================================================
-- MAIN PROCEDURES
-- ====================================================================================

-- PROCEDURE: update_schema
-- Purpose: Main entry point for schema updates
-- Parameters:
--   @p_target_version: Target version to update to
--   @p_return_code: Return code (OUT parameter)
--   @p_allow_downgrade: Allow downgrade (default NULL)
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_update_schema](
    @p_target_version VARCHAR(100),
    @p_return_code INT OUTPUT,
    @p_allow_downgrade BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @l_pkgcall_id BIGINT;
    DECLARE @l_current_version VARCHAR(100);
    DECLARE @l_error_msg VARCHAR(200);
    DECLARE @l_error_code VARCHAR(20);
    DECLARE @l_error_msg_detail VARCHAR(4000);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Initialize configuration
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
        
        -- Log the start of schema update
        SET @l_pkgcall_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_start](@p_target_version);
        
        -- Get current version
        SET @l_current_version = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
        
        -- TODO: Add validation logic here
        -- - Check for concurrent updates
        -- - Validate target version
        -- - Check downgrade allowance
        
        -- Log successful completion
        SET @p_return_code = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
            @l_pkgcall_id,
            0,
            'S',
            NULL,
            NULL,
            NULL
        );
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @l_error_msg = ERROR_MESSAGE();
        SET @l_error_code = CAST(ERROR_NUMBER() AS VARCHAR(20));
        SET @l_error_msg_detail = ERROR_MESSAGE() + CHAR(10) + 'Line: ' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        SET @p_return_code = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
            @l_pkgcall_id,
            12,
            'F',
            @l_error_msg,
            @l_error_code,
            @l_error_msg_detail
        );
    END CATCH;
END;
GO

-- PROCEDURE: grant_privs_on_own_objs
-- Purpose: Grant privileges on objects in the schema
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_grant_privs_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Placeholder: Implement privilege granting logic
    -- In Azure SQL, this would use sys.database_permissions and GRANT statements
    
    IF [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config]('MANAGE_PRIVS') = 'Y'
    BEGIN
        -- TODO: Implement privilege management
        PRINT 'Privilege management not yet implemented';
    END;
END;
GO

-- PROCEDURE: create_synonyms_on_own_objs
-- Purpose: Create synonyms for objects in the schema
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_create_synonyms_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Placeholder: Implement synonym creation logic
    -- In Azure SQL, synonyms can be created with CREATE SYNONYM
    
    IF [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config]('MANAGE_SYNONYMS') = 'Y'
    BEGIN
        -- TODO: Implement synonym management
        PRINT 'Synonym management not yet implemented';
    END;
END;
GO

-- ====================================================================================
-- CLEANUP AND MAINTENANCE PROCEDURES
-- ====================================================================================

-- PROCEDURE: purge_schema_error_logs
-- Purpose: Purges old error logs based on date
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_purge_schema_error_logs](
    @p_until_date DATE
)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Purge call error logs
        DELETE FROM [pdx_schema_upd_pkgcall_err_log]
        WHERE [id] IN (
            SELECT [id]
            FROM [pdx_schema_upd_pkgcall_hist]
            WHERE [end_date] <= @p_until_date
        );
        
        -- Purge version error logs
        DELETE FROM [pdx_schema_version_error_log]
        WHERE [id] IN (
            SELECT [id]
            FROM [pdx_schema_version_history]
            WHERE [end_date] <= @p_until_date
        );
        
        -- Purge task error logs
        DELETE FROM [pdx_schema_task_error_log]
        WHERE [id] IN (
            SELECT [id]
            FROM [pdx_schema_task_history]
            WHERE [end_date] <= @p_until_date
        );
        
        -- Purge process history
        DELETE FROM [pdx_schema_process_history]
        WHERE [end_date] <= @p_until_date;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ====================================================================================
-- MIGRATION/CONVERSION PROCEDURES
-- ====================================================================================

-- PROCEDURE: convert_to_task
-- Purpose: Converts schema from release-based to task-based
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_convert_to_task]
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @l_call_id BIGINT;
    DECLARE @l_version_id BIGINT;
    DECLARE @l_current_version VARCHAR(100);
    DECLARE @l_task_version VARCHAR(100);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
        
        SET @l_task_version = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION');
        SET @l_current_version = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
        
        SET @l_call_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_start](@l_task_version);
        
        IF @l_current_version = @l_task_version
        BEGIN
            SET @l_version_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
                @l_call_id, 15, 'F',
                'This schema is already a Task-Based schema', NULL, NULL
            );
            RAISERROR('This schema is already a Task-Based schema', 16, 1);
        END;
        
        SET @l_version_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_version_start](
            @l_call_id, @l_current_version, @l_task_version
        );
        
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_version_end] @l_version_id, 'S', NULL, NULL, NULL;
        
        UPDATE [pdx_schema_config]
        SET [value] = 'TASK'
        WHERE [key] = 'APPLYTYPE';
        
        SET @l_version_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
            @l_call_id, 0, 'S', NULL, NULL, NULL
        );
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- PROCEDURE: convert_to_release
-- Purpose: Converts schema from task-based to release-based
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_convert_to_release](
    @p_version VARCHAR(100) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @l_call_id BIGINT;
    DECLARE @l_version_id BIGINT;
    DECLARE @l_current_version VARCHAR(100);
    DECLARE @l_task_version VARCHAR(100);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
        
        SET @l_task_version = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config]('TASK_VERSION');
        SET @l_current_version = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
        
        SET @l_call_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_start](ISNULL(@p_version, 'RELEASE'));
        
        IF @l_current_version != @l_task_version
        BEGIN
            SET @l_version_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
                @l_call_id, 15, 'F',
                'This schema is already a Release-Based schema', NULL, NULL
            );
            RAISERROR('This schema is already a Release-Based schema', 16, 1);
        END;
        
        UPDATE [pdx_schema_config]
        SET [value] = 'RELEASE'
        WHERE [key] = 'APPLYTYPE';
        
        SET @l_version_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_call_end](
            @l_call_id, 0, 'S', NULL, NULL, NULL
        );
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ====================================================================================
-- PLACEHOLDER PROCEDURES FOR COMPLEX LOGIC
-- ====================================================================================

-- PROCEDURE: reset_schema
-- Purpose: Resets schema to initial state
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_reset_schema]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- TODO: Implement schema reset logic
    PRINT 'Schema reset not yet implemented';
END;
GO

-- PROCEDURE: get_sql
-- Purpose: Retrieves SQL for a file
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_sql](
    @p_fname VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @l_sql NVARCHAR(MAX);
    
    BEGIN TRY
        SELECT @l_sql = [sql]
        FROM [pdx_schema_updater_sql]
        WHERE [file_name] = @p_fname;
        
        RETURN @l_sql;
    END TRY
    BEGIN CATCH
        RETURN NULL;
    END CATCH;
END;
GO

-- ====================================================================================
-- SQL LOGGING PROCEDURES (Phase 2 Extensions)
-- ====================================================================================

-- PROCEDURE: log_task_history
-- Purpose: Logs complete task history in a single operation
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_history](
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_msg VARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @l_task_id BIGINT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Log task start
        SET @l_task_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_start](
            @p_call_id,
            @p_version_id,
            @p_filename,
            @p_action
        );
        
        -- Log task end with status and errors
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_end]
            @l_task_id,
            @p_status,
            @p_error_msg,
            @p_sql_error_code,
            @p_sql_error_msg,
            @p_action,
            @p_sql_text,
            @p_index;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- PROCEDURE: log_sql_start
-- Purpose: Logs the start of SQL execution
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_sql_start](
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1)
)
RETURNS BIGINT
AS
BEGIN
    DECLARE @l_task_id BIGINT;
    
    BEGIN TRY
        -- Log task start for SQL execution
        SET @l_task_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_start](
            @p_call_id,
            @p_version_id,
            @p_filename,
            @p_action
        );
        
        -- Update status to 'I' (In Progress) for SQL execution
        UPDATE [pdx_schema_task_history]
        SET [status_code] = 'I'
        WHERE [id] = @l_task_id;
        
        RETURN @l_task_id;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH;
END;
GO

-- PROCEDURE: log_sql_end
-- Purpose: Logs the end of SQL execution
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_sql_end](
    @p_task_id BIGINT,
    @p_filename VARCHAR(255),
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_msg VARCHAR(4000) = NULL,
    @p_action VARCHAR(1) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Update task end status
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_task_end]
            @p_task_id,
            @p_status,
            @p_error_msg,
            @p_sql_error_code,
            @p_sql_error_msg,
            @p_action,
            @p_sql_text,
            @p_index;
        
        -- Update pdx_schema_updater_sql table status
        UPDATE [pdx_schema_updater_sql]
        SET [status_code] = @p_status,
            [action_code] = ISNULL(@p_action, [action_code]),
            [statement_index] = CASE WHEN @p_status = 'S' THEN NULL ELSE ISNULL(@p_index, [statement_index]) END
        WHERE [file_name] = @p_filename;
        
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
END;
GO

-- PROCEDURE: log_sql
-- Purpose: Logs SQL execution with complete lifecycle (start to end)
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_sql](
    @p_call_id BIGINT,
    @p_version_id BIGINT,
    @p_filename VARCHAR(255),
    @p_action VARCHAR(1),
    @p_status VARCHAR(2),
    @p_error_msg VARCHAR(200) = NULL,
    @p_sql_error_code VARCHAR(20) = NULL,
    @p_sql_error_msg VARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @l_task_id BIGINT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Log SQL start
        SET @l_task_id = [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_sql_start](
            @p_call_id,
            @p_version_id,
            @p_filename,
            @p_action
        );
        
        -- Log SQL end with final status
        EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_log_sql_end]
            @l_task_id,
            @p_filename,
            @p_status,
            @p_error_msg,
            @p_sql_error_code,
            @p_sql_error_msg,
            @p_action,
            @p_sql_text,
            @p_index;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ====================================================================================
-- TEST/VERIFICATION PROCEDURES
-- ====================================================================================

/*
-- Testing procedures (uncomment to use):
EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_refresh_config];
SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_updater_version]();
SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_get_config]('APPLY_TYPE');
*/
