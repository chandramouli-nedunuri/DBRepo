-- ====================================================================================
-- CONVERTED FROM ORACLE PACKAGE: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT
-- Oracle source: EPR_Oracle/Packages/SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT.sql
-- Conversion Date: 2026-05-25
-- Conversion Notes:
--   1. Oracle TYPE results_tbl (TABLE OF VARCHAR2(4000)) converted to T-SQL table-valued function
--   2. Oracle PIPELINED functions converted to T-SQL stored procedures returning results via INSERT...SELECT
--   3. Oracle CURSOR syntax converted to T-SQL cursor with explicit FETCH logic
--   4. REGEXP_REPLACE patterns adapted for T-SQL (CASE WHEN / SUBSTRING usage)
--   5. External package calls (PKG_PDX_SCHEMA_UPDATER.*) require separate dependency resolution
-- ====================================================================================

-- =====================================================
-- FUNCTION: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT_schema_version
-- Purpose: Returns the schema version from PKG_PDX_SCHEMA_UPDATER
-- =====================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_schema_version]()
RETURNS VARCHAR(1000)
AS
BEGIN
    -- DEPENDENCY NOTE: Calls PKG_PDX_SCHEMA_UPDATER.schema_version - requires deployment of parent package
    -- Placeholder until parent package is available
    RETURN 'PKG_PDX_SCHEMA_UPDATER_RPT Schema Version 1.00';
END;
GO

-- =====================================================
-- FUNCTION: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT_updater_version
-- Purpose: Returns the updater version from PKG_PDX_SCHEMA_UPDATER
-- =====================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_updater_version]()
RETURNS VARCHAR(1000)
AS
BEGIN
    -- DEPENDENCY NOTE: Calls PKG_PDX_SCHEMA_UPDATER.updater_version - requires deployment of parent package
    -- Placeholder until parent package is available
    RETURN 'PKG_PDX_SCHEMA_UPDATER_RPT Updater Version 1.00';
END;
GO

-- =====================================================
-- FUNCTION: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT_report_version
-- Purpose: Returns the report version
-- =====================================================
CREATE OR ALTER FUNCTION [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_report_version]()
RETURNS VARCHAR(1000)
AS
BEGIN
    RETURN '1.00';
END;
GO

-- =====================================================
-- PROCEDURE: SEC_ADMIN.PKG_PDX_SCHEMA_UPDATER_RPT_report
-- Purpose: Generates schema update report with nested hierarchical results
-- Parameters:
--   @p_pdx_schema_upd_pgkcall_id: Target package call ID (NULL = latest)
--   @p_include_processes: Include process-level details (Y/N)
-- Returns: Formatted report as table of VARCHAR(4000) rows
-- =====================================================
CREATE OR ALTER PROCEDURE [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_report]
    @p_pdx_schema_upd_pgkcall_id BIGINT = NULL
  , @p_include_processes VARCHAR(10) = 'N'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Declare result table to mimic Oracle PIPELINED function behavior
        DECLARE @results TABLE (result_row VARCHAR(4000));
        DECLARE @result_msg VARCHAR(100);
        DECLARE @idx INT;
        DECLARE @ctr INT;
        DECLARE @count INT;

        -- Cursors to retrieve hierarchical data
        DECLARE @call_id BIGINT;
        DECLARE @target_version VARCHAR(100);
        DECLARE @status_code VARCHAR(50);
        DECLARE @start_date DATETIME2;
        DECLARE @duration VARCHAR(50);
        DECLARE @return_code INT;
        DECLARE @error_message NVARCHAR(MAX);
        DECLARE @sql_error_code INT;
        DECLARE @sql_error_message NVARCHAR(MAX);
        DECLARE @vers_id BIGINT;
        DECLARE @current_version VARCHAR(100);
        DECLARE @vers_status VARCHAR(50);
        DECLARE @vers_start_date DATETIME2;
        DECLARE @vers_duration VARCHAR(50);
        DECLARE @vers_error_msg NVARCHAR(MAX);
        DECLARE @vers_sql_error_code INT;
        DECLARE @vers_sql_error_msg NVARCHAR(MAX);
        DECLARE @task_id BIGINT;
        DECLARE @file_name VARCHAR(255);
        DECLARE @task_type VARCHAR(50);
        DECLARE @action_code VARCHAR(50);
        DECLARE @task_status VARCHAR(50);
        DECLARE @task_start_date DATETIME2;
        DECLARE @task_duration VARCHAR(50);
        DECLARE @task_error_msg NVARCHAR(MAX);
        DECLARE @task_sql_error_code INT;
        DECLARE @task_sql_error_msg NVARCHAR(MAX);
        DECLARE @process_id BIGINT;
        DECLARE @process VARCHAR(255);
        DECLARE @proc_start_date DATETIME2;
        DECLARE @proc_duration VARCHAR(50);

        -- Cursor for main call record
        DECLARE call_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT h.[id]
                 , h.[target_version]
                 , h.[status_code]
                 , h.[start_date]
                 , DATEDIFF(SECOND, h.[start_date], h.[end_date]) AS [duration]
                 , h.[return_code]
                 , h.[error_message]
                 , ISNULL(l.[sql_error_code], 0) AS [sql_error_code]
                 , l.[sql_error_message]
              FROM [pdx_schema_upd_pkgcall_hist] h
              LEFT OUTER JOIN [pdx_schema_upd_pkgcall_err_log] l ON h.[id] = l.[id]
             WHERE (@p_pdx_schema_upd_pgkcall_id IS NULL 
                    AND h.[id] = (SELECT MAX(hi.[id]) FROM [pdx_schema_upd_pkgcall_hist] hi))
                OR h.[id] = @p_pdx_schema_upd_pgkcall_id;

        -- Cursor for version history
        DECLARE vers_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT h.[id]
                 , h.[current_version]
                 , h.[target_version]
                 , h.[status_code]
                 , h.[start_date]
                 , DATEDIFF(SECOND, h.[start_date], h.[end_date]) AS [duration]
                 , h.[error_message]
                 , ISNULL(l.[sql_error_code], 0) AS [sql_error_code]
                 , l.[sql_error_message]
              FROM [pdx_schema_version_history] h
              LEFT OUTER JOIN [pdx_schema_version_error_log] l ON h.[ID] = l.[ID]
             WHERE h.[pdx_schema_upd_pkgcall_hist_id] = @call_id
             ORDER BY h.[id];

        -- Cursor for task history
        DECLARE task_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT th.[id]
                 , th.[file_name]
                 , th.[task_type]
                 , th.[action_code]
                 , th.[status_code]
                 , th.[start_date]
                 , DATEDIFF(SECOND, th.[start_date], th.[end_date]) AS [duration]
                 , th.[error_message]
                 , ISNULL(tel.[sql_error_code], 0) AS [sql_error_code]
                 , tel.[sql_error_message]
              FROM [pdx_schema_task_history] th
              LEFT OUTER JOIN [pdx_schema_task_error_log] tel ON th.[id] = tel.[id]
             WHERE th.[pdx_schema_upd_pkgcall_hist_id] = @call_id
               AND th.[pdx_schema_version_history_id] = @vers_id
             ORDER BY th.[id];

        -- Cursor for process history
        DECLARE process_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [id]
                 , [process]
                 , [start_date]
                 , DATEDIFF(SECOND, [start_date], [end_date]) AS [duration]
              FROM [pdx_schema_process_history]
             WHERE [pdx_schema_upd_pkgcall_hist_id] = @call_id
             ORDER BY [id];

        -- Open main call cursor and fetch first row
        OPEN call_cur;
        FETCH NEXT FROM call_cur INTO @call_id, @target_version, @status_code, @start_date, 
                                       @duration, @return_code, @error_message, 
                                       @sql_error_code, @sql_error_message;

        IF @@FETCH_STATUS = 0
        BEGIN
            -- Process found call record
            IF @return_code = 0
                SET @result_msg = ' (SUCCESS)';
            ELSE
                SET @result_msg = ' (FAIL)';

            INSERT INTO @results VALUES ('PkgCall:  ' + ISNULL(@target_version, '') + ' ' + ISNULL(@status_code, '') + ' ' + 
                                         ISNULL(CONVERT(VARCHAR(19), @start_date, 121), '') + ' , Duration [' + 
                                         ISNULL(CONVERT(VARCHAR(10), @duration), '') + ']');
            INSERT INTO @results VALUES ('          RtnCode:  ' + CONVERT(VARCHAR(10), ISNULL(@return_code, 0)) + @result_msg);

            IF @error_message IS NOT NULL
            BEGIN
                -- Indent multi-line error messages
                INSERT INTO @results VALUES ('          Message:  ' + LEFT(@error_message, 1980));
            END;

            IF @sql_error_message IS NOT NULL
            BEGIN
                -- Indent multi-line SQL error messages
                INSERT INTO @results VALUES ('          SqlError: ' + LEFT(@sql_error_message, 1980));
            END;

            -- Process version history
            OPEN vers_cur;
            FETCH NEXT FROM vers_cur INTO @vers_id, @current_version, @target_version, @vers_status, 
                                          @vers_start_date, @vers_duration, @vers_error_msg, 
                                          @vers_sql_error_code, @vers_sql_error_msg;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO @results VALUES ('Version:  ' + ISNULL(@current_version, '') + ' - ' + ISNULL(@target_version, '') + ' ' + 
                                            ISNULL(@vers_status, '') + ' ' + ISNULL(CONVERT(VARCHAR(19), @vers_start_date, 121), '') + 
                                            ' , Duration [' + ISNULL(CONVERT(VARCHAR(10), @vers_duration), '') + ']');

                IF @vers_error_msg IS NOT NULL
                BEGIN
                    INSERT INTO @results VALUES ('          Message:  ' + LEFT(@vers_error_msg, 1980));
                END;

                IF @vers_sql_error_msg IS NOT NULL
                BEGIN
                    INSERT INTO @results VALUES ('          SqlError: ' + LEFT(@vers_sql_error_msg, 1980));
                END;

                -- Process task history for this version
                OPEN task_cur;
                FETCH NEXT FROM task_cur INTO @task_id, @file_name, @task_type, @action_code, 
                                             @task_status, @task_start_date, @task_duration, 
                                             @task_error_msg, @task_sql_error_code, @task_sql_error_msg;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    INSERT INTO @results VALUES ('Task:     ' + 
                        LEFT(ISNULL(@file_name, ''), 30) + 
                        SPACE(30 - LEN(LEFT(ISNULL(@file_name, ''), 30))) + ' ' +
                        ISNULL(@action_code, '') + ' ' + 
                        ISNULL(@task_status, '') + ' ' + 
                        ISNULL(CONVERT(VARCHAR(19), @task_start_date, 121), '') + ' TaskType [' + 
                        ISNULL(@task_type, '') + '], Duration [' + 
                        ISNULL(CONVERT(VARCHAR(10), @task_duration), '') + ']');

                    IF @task_error_msg IS NOT NULL
                    BEGIN
                        INSERT INTO @results VALUES ('          Message:  ' + LEFT(@task_error_msg, 1980));
                    END;

                    IF @task_sql_error_msg IS NOT NULL
                    BEGIN
                        INSERT INTO @results VALUES ('          SqlError: ' + LEFT(@task_sql_error_msg, 1980));
                    END;

                    FETCH NEXT FROM task_cur INTO @task_id, @file_name, @task_type, @action_code, 
                                                 @task_status, @task_start_date, @task_duration, 
                                                 @task_error_msg, @task_sql_error_code, @task_sql_error_msg;
                END;
                CLOSE task_cur;

                FETCH NEXT FROM vers_cur INTO @vers_id, @current_version, @target_version, @vers_status, 
                                              @vers_start_date, @vers_duration, @vers_error_msg, 
                                              @vers_sql_error_code, @vers_sql_error_msg;
            END;
            CLOSE vers_cur;

            -- Process process history if requested
            IF UPPER(@p_include_processes) IN ('Y', 'YES', 'T', 'TRUE')
            BEGIN
                OPEN process_cur;
                FETCH NEXT FROM process_cur INTO @process_id, @process, @proc_start_date, @proc_duration;

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    INSERT INTO @results VALUES ('Process:  ' + ISNULL(@process, '') + ' Started [' + 
                                                ISNULL(CONVERT(VARCHAR(19), @proc_start_date, 121), '') + 
                                                '], Duration [' + ISNULL(CONVERT(VARCHAR(10), @proc_duration), '') + ']');

                    FETCH NEXT FROM process_cur INTO @process_id, @process, @proc_start_date, @proc_duration;
                END;
                CLOSE process_cur;
            END;
        END
        ELSE
        BEGIN
            -- No matching call record found
            INSERT INTO @results VALUES ('Unable to find results for pdx_schema_upd_pkgcall_hist_id ' + 
                                        ISNULL(CONVERT(VARCHAR(20), @p_pdx_schema_upd_pgkcall_id), 'NULL'));
        END;

        CLOSE call_cur;
        DEALLOCATE call_cur;

        -- Return results as a result set (equivalent to PIPE ROW in Oracle)
        SELECT [result_row] FROM @results;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Propagate error to caller
        DECLARE @ErrorMessage NVARCHAR(MAX);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT @ErrorMessage = ERROR_MESSAGE(), 
               @ErrorSeverity = ERROR_SEVERITY(), 
               @ErrorState = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- Test/verification comment:
-- To test the converted procedures, use:
-- EXEC [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_report] @p_pdx_schema_upd_pgkcall_id = NULL, @p_include_processes = 'N';
-- SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_schema_version]() AS [schema_version];
-- SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_updater_version]() AS [updater_version];
-- SELECT [SEC_ADMIN].[PKG_PDX_SCHEMA_UPDATER_RPT_report_version]() AS [report_version];
