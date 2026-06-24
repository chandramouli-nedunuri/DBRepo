-- ============================================================================
-- Converted: Oracle Package EPS.PKG_PDX_SCHEMA_UPDATER_RPT -> Azure SQL
-- Conversion Date: 2026-05-25
--
-- DBA IMPLEMENTATION NOTES:
-- 1) Oracle PIPELINED function report(...) is converted to a multi-statement
--    table-valued function that returns one row per report line.
-- 2) Oracle regex-based true/yes parsing for include_processes is mapped to
--    case-insensitive checks against Y/YES/T/TRUE.
-- 3) Message indentation from Oracle REGEXP_REPLACE is approximated by prefixing
--    continuation lines with fixed spaces and replacing CR/LF with indented CR/LF.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_RPT_schema_version]()
RETURNS VARCHAR(100)
AS
BEGIN
    RETURN [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]();
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_RPT_updater_version]()
RETURNS VARCHAR(100)
AS
BEGIN
    RETURN [EPS].[PKG_PDX_SCHEMA_UPDATER_updater_version]();
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_RPT_report_version]()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN '1.00';
END;
GO

CREATE OR ALTER FUNCTION [EPS].[PKG_PDX_SCHEMA_UPDATER_RPT_report]
(
    @p_pdx_schema_upd_pgkcall_id BIGINT = NULL,
    @p_include_processes VARCHAR(20) = 'N'
)
RETURNS @results TABLE
(
    [line_no] INT IDENTITY(1,1) NOT NULL,
    [line_text] VARCHAR(4000) NOT NULL
)
AS
BEGIN
    DECLARE @call_id BIGINT;
    DECLARE @target_version VARCHAR(255);
    DECLARE @status_code VARCHAR(100);
    DECLARE @start_date DATETIME2(6);
    DECLARE @end_date DATETIME2(6);
    DECLARE @duration_text VARCHAR(100);
    DECLARE @return_code INT;
    DECLARE @error_message VARCHAR(MAX);
    DECLARE @sql_error_message VARCHAR(MAX);
    DECLARE @result_msg VARCHAR(20);

    SELECT TOP (1)
        @call_id = h.[id],
        @target_version = CONVERT(VARCHAR(255), h.[target_version]),
        @status_code = CONVERT(VARCHAR(100), h.[status_code]),
        @start_date = h.[start_date],
        @end_date = h.[end_date],
        @return_code = h.[return_code],
        @error_message = CONVERT(VARCHAR(MAX), l.[error_message]),
        @sql_error_message = CONVERT(VARCHAR(MAX), l.[sql_error_message])
    FROM [pdx_schema_upd_pkgcall_hist] h
    LEFT JOIN [pdx_schema_upd_pkgcall_err_log] l ON l.[id] = h.[id]
    WHERE (@p_pdx_schema_upd_pgkcall_id IS NULL AND h.[id] = (SELECT MAX(hi.[id]) FROM [pdx_schema_upd_pkgcall_hist] hi))
       OR h.[id] = @p_pdx_schema_upd_pgkcall_id
    ORDER BY h.[id] DESC;

    IF @call_id IS NULL
    BEGIN
        INSERT INTO @results([line_text])
        VALUES ('Unable to find results for pdx_schema_upd_pkgcall_hist_id ' + COALESCE(CONVERT(VARCHAR(30), @p_pdx_schema_upd_pgkcall_id), 'NULL'));
        RETURN;
    END

    SET @duration_text = COALESCE(CONVERT(VARCHAR(100), DATEADD(SECOND, DATEDIFF(SECOND, @start_date, @end_date), CAST('00:00:00' AS TIME(0)))), '00:00:00');
    SET @result_msg = CASE WHEN ISNULL(@return_code, 1) = 0 THEN ' (SUCCESS)' ELSE ' (FAIL)' END;

    INSERT INTO @results([line_text])
    VALUES ('PkgCall:  ' + COALESCE(@target_version, '') + ' ' + COALESCE(@status_code, '') + ' ' + COALESCE(CONVERT(VARCHAR(30), @start_date, 121), '') + ' , Duration [' + @duration_text + ']');

    INSERT INTO @results([line_text])
    VALUES ('          RtnCode:  ' + COALESCE(CONVERT(VARCHAR(30), @return_code), 'NULL') + @result_msg);

    IF @error_message IS NOT NULL
    BEGIN
        INSERT INTO @results([line_text])
        VALUES ('          Message:  ' + REPLACE(REPLACE(@error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));
    END

    IF @sql_error_message IS NOT NULL
    BEGIN
        INSERT INTO @results([line_text])
        VALUES ('          SqlError: ' + REPLACE(REPLACE(@sql_error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));
    END

    DECLARE
        @vers_id BIGINT,
        @vers_current_version VARCHAR(255),
        @vers_target_version VARCHAR(255),
        @vers_status_code VARCHAR(100),
        @vers_start_date DATETIME2(6),
        @vers_end_date DATETIME2(6),
        @vers_error_message VARCHAR(MAX),
        @vers_sql_error_message VARCHAR(MAX),
        @vers_duration_text VARCHAR(100);

    DECLARE vers_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            h.[id],
            CONVERT(VARCHAR(255), h.[current_version]),
            CONVERT(VARCHAR(255), h.[target_version]),
            CONVERT(VARCHAR(100), h.[status_code]),
            h.[start_date],
            h.[end_date],
            CONVERT(VARCHAR(MAX), l.[error_message]),
            CONVERT(VARCHAR(MAX), l.[sql_error_message])
        FROM [pdx_schema_version_history] h
        LEFT JOIN [pdx_schema_version_error_log] l ON l.[id] = h.[id]
        WHERE h.[pdx_schema_upd_pkgcall_hist_id] = @call_id
        ORDER BY h.[id];

    OPEN vers_cur;
    FETCH NEXT FROM vers_cur INTO
        @vers_id,
        @vers_current_version,
        @vers_target_version,
        @vers_status_code,
        @vers_start_date,
        @vers_end_date,
        @vers_error_message,
        @vers_sql_error_message;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @vers_duration_text = COALESCE(CONVERT(VARCHAR(100), DATEADD(SECOND, DATEDIFF(SECOND, @vers_start_date, @vers_end_date), CAST('00:00:00' AS TIME(0)))), '00:00:00');

        INSERT INTO @results([line_text])
        VALUES ('Version:  ' + COALESCE(@vers_current_version, '') + ' - ' + COALESCE(@vers_target_version, '') + ' ' + COALESCE(@vers_status_code, '') + ' ' + COALESCE(CONVERT(VARCHAR(30), @vers_start_date, 121), '') + ' , Duration [' + @vers_duration_text + ']');

        IF @vers_error_message IS NOT NULL
            INSERT INTO @results([line_text])
            VALUES ('          Message:  ' + REPLACE(REPLACE(@vers_error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));

        IF @vers_sql_error_message IS NOT NULL
            INSERT INTO @results([line_text])
            VALUES ('          SqlError: ' + REPLACE(REPLACE(@vers_sql_error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));

        DECLARE
            @task_id BIGINT,
            @task_file_name VARCHAR(400),
            @task_type VARCHAR(100),
            @task_action_code VARCHAR(100),
            @task_status_code VARCHAR(100),
            @task_start_date DATETIME2(6),
            @task_end_date DATETIME2(6),
            @task_error_message VARCHAR(MAX),
            @task_sql_error_message VARCHAR(MAX),
            @task_duration_text VARCHAR(100);

        DECLARE task_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                t.[id],
                CONVERT(VARCHAR(400), t.[file_name]),
                CONVERT(VARCHAR(100), t.[task_type]),
                CONVERT(VARCHAR(100), t.[action_code]),
                CONVERT(VARCHAR(100), t.[status_code]),
                t.[start_date],
                t.[end_date],
                CONVERT(VARCHAR(MAX), e.[error_message]),
                CONVERT(VARCHAR(MAX), e.[sql_error_message])
            FROM [pdx_schema_task_history] t
            LEFT JOIN [pdx_schema_task_error_log] e ON e.[id] = t.[id]
            WHERE t.[pdx_schema_upd_pkgcall_hist_id] = @call_id
              AND t.[pdx_schema_version_history_id] = @vers_id
            ORDER BY t.[id];

        OPEN task_cur;
        FETCH NEXT FROM task_cur INTO
            @task_id,
            @task_file_name,
            @task_type,
            @task_action_code,
            @task_status_code,
            @task_start_date,
            @task_end_date,
            @task_error_message,
            @task_sql_error_message;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @task_duration_text = COALESCE(CONVERT(VARCHAR(100), DATEADD(SECOND, DATEDIFF(SECOND, @task_start_date, @task_end_date), CAST('00:00:00' AS TIME(0)))), '00:00:00');

            INSERT INTO @results([line_text])
            VALUES ('Task:     ' + LEFT(COALESCE(@task_file_name, '') + REPLICATE(' ', 30), 30)
                  + ' ' + COALESCE(@task_action_code, '')
                  + ' ' + COALESCE(@task_status_code, '')
                  + ' ' + COALESCE(CONVERT(VARCHAR(30), @task_start_date, 121), '')
                  + ' TaskType [' + COALESCE(@task_type, '') + '], Duration [' + @task_duration_text + ']');

            IF @task_error_message IS NOT NULL
                INSERT INTO @results([line_text])
                VALUES ('          Message:  ' + REPLACE(REPLACE(@task_error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));

            IF @task_sql_error_message IS NOT NULL
                INSERT INTO @results([line_text])
                VALUES ('          SqlError: ' + REPLACE(REPLACE(@task_sql_error_message, CHAR(13) + CHAR(10), CHAR(13) + CHAR(10) + '                    '), CHAR(10), CHAR(10) + '                    '));

            FETCH NEXT FROM task_cur INTO
                @task_id,
                @task_file_name,
                @task_type,
                @task_action_code,
                @task_status_code,
                @task_start_date,
                @task_end_date,
                @task_error_message,
                @task_sql_error_message;
        END

        CLOSE task_cur;
        DEALLOCATE task_cur;

        FETCH NEXT FROM vers_cur INTO
            @vers_id,
            @vers_current_version,
            @vers_target_version,
            @vers_status_code,
            @vers_start_date,
            @vers_end_date,
            @vers_error_message,
            @vers_sql_error_message;
    END

    CLOSE vers_cur;
    DEALLOCATE vers_cur;

    IF UPPER(LTRIM(RTRIM(COALESCE(@p_include_processes, 'N')))) IN ('Y', 'YES', 'T', 'TRUE')
    BEGIN
        INSERT INTO @results([line_text])
        SELECT
            'Process:  '
            + COALESCE(CONVERT(VARCHAR(255), p.[process]), '')
            + ' Started [' + COALESCE(CONVERT(VARCHAR(30), p.[start_date], 121), '') + '], Duration ['
            + COALESCE(CONVERT(VARCHAR(100), DATEADD(SECOND, DATEDIFF(SECOND, p.[start_date], p.[end_date]), CAST('00:00:00' AS TIME(0)))), '00:00:00')
            + ']'
        FROM [pdx_schema_process_history] p
        WHERE p.[pdx_schema_upd_pkgcall_hist_id] = @call_id
        ORDER BY p.[id];
    END

    RETURN;
END;
GO
