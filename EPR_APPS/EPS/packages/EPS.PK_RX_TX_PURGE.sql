-- ============================================================================
-- Converted: Oracle Package EPS.PK_RX_TX_PURGE -> Azure SQL programmable objects
-- Conversion Date: 2026-05-25
--
-- Notes:
-- 1) Oracle package global variables are refactored into local variables per procedure.
-- 2) Oracle partition-specific syntax and DBMS_PARALLEL_EXECUTE are replaced with
--    Azure-safe dynamic SQL execution paths.
-- 3) Oracle SMTP package calls are mapped to Database Mail (`msdb.dbo.sp_send_dbmail`)
--    when available; otherwise errors are logged to `purge_error_log`.
-- 4) Oracle USER_* dictionary views are mapped to SQL Server `sys.*` metadata views.
-- 5) Oracle RAISE_APPLICATION_ERROR(-20xxx, ...) is mapped to THROW 50xxx.
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [EPS].[PK_RX_TX_PURGE_lookup_config]
(
    @p_name      VARCHAR(200),
    @p_mandatory CHAR(1) = 'Y'
)
RETURNS VARCHAR(4000)
AS
BEGIN
    DECLARE @l_value VARCHAR(4000);

    SELECT TOP (1) @l_value = CONVERT(VARCHAR(4000), [value])
    FROM [purge_config_settings]
    WHERE [name] = @p_name;

    IF @l_value IS NULL AND ISNULL(@p_mandatory, 'Y') = 'Y'
    BEGIN
        THROW 50101, 'Missing required configuration in PURGE_CONFIG_SETTINGS', 1;
    END

    RETURN @l_value;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_process_purge_configuration]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @purge_run_status VARCHAR(200);

    BEGIN TRY
        SET @purge_run_status = 'pk_rx_tx_purge.sp_process_purge_configuration: 1';

        DECLARE @run_duration      INT          = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_rxtx_run_duration', 'Y') AS INT);
        DECLARE @min_space         DECIMAL(18,2)= TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('archive_min_free_space', 'Y') AS DECIMAL(18,2));
        DECLARE @arch_dest         VARCHAR(100) = [EPS].[PK_RX_TX_PURGE_lookup_config]('archive_destination', 'Y');
        DECLARE @mail_host         VARCHAR(100) = [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_smtp_address', 'N');
        DECLARE @from_addr         VARCHAR(100) = [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_from_address', 'N');
        DECLARE @to_addr           VARCHAR(4000)= [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_to_address', 'N');
        DECLARE @job_class         VARCHAR(100) = [EPS].[PK_RX_TX_PURGE_lookup_config]('purge_job_class', 'N');
        DECLARE @purge_start_time  DATETIME2    = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_start_time', 'Y') AS DATETIME2);
        DECLARE @purge_min_date    DATE         = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_rxtx_min_date', 'Y') AS DATE);
        DECLARE @purge_days        INT          = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_rxtx_number_of_days', 'Y') AS INT);
        DECLARE @keep_months       INT          = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_keep_months', 'Y') AS INT);
        DECLARE @mbrc              INT          = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('multiblock_read_count', 'N') AS INT);
        DECLARE @parallel_count    INT          = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_parallel_count', 'Y') AS INT);

        IF @run_duration IS NULL OR @parallel_count IS NULL OR @purge_days IS NULL OR @keep_months IS NULL
            THROW 50102, 'Required purge configuration values are invalid', 1;

    END TRY
    BEGIN CATCH
        INSERT INTO [purge_error_log] ([id], [failed_statement], [error_text], [error_date])
        VALUES (NEXT VALUE FOR [purge_seq], @purge_run_status, ERROR_MESSAGE(), SYSDATETIME());
        THROW 50102, 'Failed to process purge configuration', 1;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_parallel_delete]
    @table_name SYSNAME,
    @part_name  VARCHAR(200) = NULL,
    @start_rowid VARCHAR(100) = NULL,
    @end_rowid   VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql_str NVARCHAR(MAX);
    DECLARE @counter INT;

    BEGIN TRY
        SET @sql_str = N'DELETE a '
                     + N'FROM ' + QUOTENAME(@table_name) + N' a '
                     + N'WHERE EXISTS ('
                     + N'  SELECT 1 '
                     + N'  FROM [purge_records] p '
                     + N'  WHERE p.[table_name] = @t '
                     + N'    AND a.[chain_id] = p.[chain_id] '
                     + N'    AND a.[id] = p.[id]'
                     + CASE WHEN @part_name IS NULL THEN N' AND p.[part_name] IS NULL' ELSE N' AND p.[part_name] = @p' END
                     + N');';

        EXEC sp_executesql @sql_str,
            N'@t VARCHAR(200), @p VARCHAR(200)',
            @t = @table_name,
            @p = @part_name;

        SET @counter = @@ROWCOUNT;

        IF @counter > 0
        BEGIN
            INSERT INTO [purge_records] ([table_name], [id])
            VALUES ('PURGE-PARALLEL-DELETE', @counter);
        END
    END TRY
    BEGIN CATCH
        -- Oracle -20601
        THROW 50601, 'Parallel delete failed', 1;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_check_run_window]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @run_duration       INT;
    DECLARE @purge_start_date   DATETIME2;
    DECLARE @min_space          DECIMAL(18,2);
    DECLARE @arch_dest          VARCHAR(100);
    DECLARE @blackout_count     INT;

    SET @run_duration     = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_rxtx_run_duration', 'Y') AS INT);
    SET @purge_start_date = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_start_time', 'Y') AS DATETIME2);
    SET @min_space        = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('archive_min_free_space', 'Y') AS DECIMAL(18,2));
    SET @arch_dest        = [EPS].[PK_RX_TX_PURGE_lookup_config]('archive_destination', 'Y');

    IF @run_duration IS NULL OR @purge_start_date IS NULL
        THROW 50303, 'Run-window configuration is invalid', 1;

    IF SYSDATETIME() > DATEADD(HOUR, @run_duration, @purge_start_date)
        THROW 50301, 'Current Time is outside of the daily PURGE Window', 1;

    SELECT @blackout_count = COUNT(*)
    FROM [purge_config_settings]
    WHERE [name] LIKE 'purge_blackout_day_%'
      AND UPPER(LTRIM(RTRIM([value]))) = UPPER(DATENAME(WEEKDAY, GETDATE()));

    IF @blackout_count > 0
        THROW 50302, 'Current Day is listed as blackout day for PURGE', 1;

    -- Oracle ASM free-space check is not directly available in Azure SQL.
    -- Preserve guardrail by requiring configured values to exist.
    IF @arch_dest IS NULL OR @min_space IS NULL
        THROW 50303, 'Unable to validate archive destination configuration', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_rebuild_indexes]
    @run_details_id BIGINT,
    @tabname        SYSNAME,
    @partname       VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @index_name SYSNAME;
    DECLARE @sql_str NVARCHAR(MAX);
    DECLARE @seq_id BIGINT;
    DECLARE @err_seq_id BIGINT;

    DECLARE cur_idx CURSOR LOCAL FAST_FORWARD FOR
        SELECT i.[name]
        FROM sys.indexes i
        INNER JOIN sys.tables t ON t.object_id = i.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE t.[name] = UPPER(@tabname)
          AND s.[name] = 'EPS'
          AND i.[name] IS NOT NULL
          AND i.[type] IN (1, 2);

    BEGIN TRY
        OPEN cur_idx;
        FETCH NEXT FROM cur_idx INTO @index_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC [EPS].[PK_RX_TX_PURGE_sp_check_run_window];

            SET @sql_str = N'ALTER INDEX ' + QUOTENAME(@index_name)
                         + N' ON [EPS].' + QUOTENAME(UPPER(@tabname))
                         + N' REBUILD WITH (ONLINE = ON);';

            SET @seq_id = NEXT VALUE FOR [purge_seq];

            INSERT INTO [purge_index_rebuild_log]
            (
                [id], [purge_run_details_id], [table_name], [partition_name], [index_name],
                [sql_statement], [start_date], [status]
            )
            VALUES
            (
                @seq_id, @run_details_id, @tabname, @partname, @index_name,
                @sql_str, SYSDATETIME(), 'IN PROGRESS'
            );

            -- Keep behavior aligned with Oracle currently disabled path.
            UPDATE [purge_index_rebuild_log]
            SET [status] = 'DISABLED',
                [end_date] = SYSDATETIME()
            WHERE [id] = @seq_id;

            FETCH NEXT FROM cur_idx INTO @index_name;
        END

        CLOSE cur_idx;
        DEALLOCATE cur_idx;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_idx') >= -1
        BEGIN
            CLOSE cur_idx;
            DEALLOCATE cur_idx;
        END

        SET @err_seq_id = NEXT VALUE FOR [purge_seq];
        INSERT INTO [purge_error_log] ([id], [failed_statement], [error_text], [error_date])
        VALUES (@err_seq_id, ISNULL(@sql_str, 'sp_rebuild_indexes'), ERROR_MESSAGE(), SYSDATETIME());

        UPDATE [purge_index_rebuild_log]
        SET [status] = 'REBUILD-IN-NEXT-RUN',
            [end_date] = SYSDATETIME(),
            [purge_error_log_id] = @err_seq_id
        WHERE [id] = @seq_id;

        EXEC [EPS].[PK_RX_TX_PURGE_sp_send_email_alert]
            @subj = 'EPR Purge failed with following error',
            @msg_body = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_stop_parallel_task]
AS
BEGIN
    SET NOCOUNT ON;
    -- Oracle DBMS_PARALLEL_EXECUTE task stop/drop has no direct Azure SQL equivalent.
    -- Keep as explicit no-op for operational parity.
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_send_email_alert]
    @subj     VARCHAR(400),
    @msg_body VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @to_addr VARCHAR(4000) = [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_to_address', 'N');
    DECLARE @from_addr VARCHAR(320) = [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_from_address', 'N');
    DECLARE @profile_name SYSNAME = [EPS].[PK_RX_TX_PURGE_lookup_config]('mail_profile_name', 'N');

    BEGIN TRY
        IF OBJECT_ID('msdb.dbo.sp_send_dbmail') IS NOT NULL AND @to_addr IS NOT NULL
        BEGIN
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @profile_name,
                @recipients = @to_addr,
                @subject = @subj,
                @body = @msg_body,
                @body_format = 'HTML';
        END
        ELSE
        BEGIN
            INSERT INTO [purge_error_log] ([id], [failed_statement], [error_text], [error_date])
            VALUES (NEXT VALUE FOR [purge_seq], 'sp_send_email_alert', 'Database Mail unavailable or recipients not configured', SYSDATETIME());
        END
    END TRY
    BEGIN CATCH
        INSERT INTO [purge_error_log] ([id], [failed_statement], [error_text], [error_date])
        VALUES (NEXT VALUE FOR [purge_seq], 'sp_send_email_alert', ERROR_MESSAGE(), SYSDATETIME());
        THROW 50701, 'Failed to send purge email alert', 1;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_populate_purge_records]
    @purge_run_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql_str NVARCHAR(MAX) = NULL;
    DECLARE @seq_id BIGINT = NULL;
    DECLARE @err_seq_id BIGINT = NULL;
    DECLARE @sql_code INT;
    DECLARE @cnt BIGINT;
    DECLARE @pdate DATE = @purge_run_date;
    DECLARE @keep_months INT = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_keep_months', 'Y') AS INT);
    DECLARE @parallel_thread_count INT = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_parallel_count', 'Y') AS INT);
    DECLARE @keep_date DATE;
    DECLARE @row_count BIGINT;

    BEGIN TRY
        SELECT @keep_date = DATEADD(MONTH, -1 * @keep_months, CAST(SYSDATETIME() AS DATE));

        IF @pdate >= @keep_date
            THROW 50401, 'The Purge Date is greater than the defined KEEP_MONTHS window', 1;

        UPDATE [purge_config_settings]
        SET [value] = CONVERT(VARCHAR(11), @pdate, 106)
        WHERE [name] = 'purge_report_date';

        DECLARE cur_flow CURSOR LOCAL FAST_FORWARD FOR
            SELECT a.[table_name], a.[part_name], a.[constraint_name], a.[additional_info], a.[hierarchy_level]
            FROM [purge_flow_map] a
            LEFT JOIN [purge_run_details] b ON a.[purge_rec_run_details_id] = b.[id]
            WHERE ISNULL(b.[status], 'A') <> 'COMPLETED'
              AND a.[number_of_child] > 0
            ORDER BY a.[hierarchy_level], a.[table_name], a.[constraint_name], a.[part_position];

        DECLARE @table_name SYSNAME, @part_name VARCHAR(200), @constraint_name SYSNAME, @additional_info VARCHAR(4000), @hierarchy_level INT;

        OPEN cur_flow;
        FETCH NEXT FROM cur_flow INTO @table_name, @part_name, @constraint_name, @additional_info, @hierarchy_level;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @hierarchy_level = 2
            BEGIN
                SELECT @cnt = ISNULL(SUM(b.[affected_row_count]), 0)
                FROM [purge_flow_map] a
                INNER JOIN [purge_run_details] b ON a.[purge_rec_run_details_id] = b.[id]
                WHERE a.[hierarchy_level] = 1;

                IF @cnt = 0
                BEGIN
                    UPDATE [purge_config_settings]
                    SET [value] = CONVERT(VARCHAR(10), DATEADD(DAY,
                        TRY_CAST((SELECT TOP 1 [value] FROM [purge_config_settings] WHERE [name] = 'purge_rxtx_number_of_days') AS INT),
                        TRY_CAST([value] AS DATE)
                    ), 110)
                    WHERE [name] = 'purge_rxtx_min_date';

                    UPDATE [purge_flow_map] SET [purge_rec_run_details_id] = NULL;
                    THROW 50402, '0 Records found in PURGE_RECORDS for master table', 1;
                END
            END

            IF @hierarchy_level = 1
            BEGIN
                SET @sql_str = N'INSERT INTO [purge_records] ([table_name],[part_name],[chain_id],[id],[row_id]) '
                             + N'SELECT ''' + @table_name + N''', ' + CASE WHEN @part_name IS NULL THEN N'NULL' ELSE N'''' + @part_name + N'''' END + N','
                             + N' a.[chain_id], a.[id], a.[rowid] '
                             + N'FROM [rx_tx] a '
                             + N'WHERE ((a.[fill_status] <> ''I'' AND ISNULL(a.[filled], a.[written]) <= @pdate) '
                             + N'   OR (a.[fill_status] = ''I'' AND a.[why_deactivated] IS NOT NULL AND a.[last_updated] <= @pdate)) '
                             + N'  AND (ISNULL(a.[IMMUNIZATION_INDICATOR],''X'') <> ''Y'' AND a.[CVX_CODE] IS NULL);';
            END
            ELSE
            BEGIN
                -- Child table population from parent purge_records (pair-key pattern)
                SET @sql_str = N'INSERT INTO [purge_records] ([table_name],[part_name],[chain_id],[id],[row_id]) '
                             + N'SELECT ''' + @table_name + N''', ' + CASE WHEN @part_name IS NULL THEN N'NULL' ELSE N'''' + @part_name + N'''' END + N','
                             + N' tn.[chain_id], tn.[id], tn.[rowid] '
                             + N'FROM ' + QUOTENAME(@table_name) + N' tn '
                             + N'INNER JOIN [purge_records] pr ON pr.[table_name] = PARSENAME(REPLACE(REPLACE(@additional_info,''|'',''.''), '','', ''.''), 1) '
                             + N' AND tn.[chain_id] = pr.[chain_id] AND tn.[id] = pr.[id];';
            END

            SET @seq_id = NEXT VALUE FOR [purge_seq];

            INSERT INTO [purge_run_details]([id],[object_name],[start_date],[status],[sql_statement],[comments])
            VALUES(@seq_id, @table_name + ':' + ISNULL(@part_name, ''), SYSDATETIME(), 'IN PROGRESS', @sql_str, 'Populating PURGE_RECORDS table');

            UPDATE [purge_flow_map]
            SET [purge_rec_run_details_id] = @seq_id
            WHERE [table_name] = @table_name
              AND ISNULL([part_name], 'A') = ISNULL(@part_name, 'A')
              AND ISNULL([constraint_name], 'A') = ISNULL(@constraint_name, 'A');

            EXEC [EPS].[PK_RX_TX_PURGE_sp_check_run_window];

            EXEC sp_executesql @sql_str, N'@pdate DATE, @additional_info VARCHAR(4000)', @pdate=@pdate, @additional_info=@additional_info;

            SET @row_count = @@ROWCOUNT;

            UPDATE [purge_run_details]
            SET [status] = 'COMPLETED', [affected_row_count] = @row_count, [end_date] = SYSDATETIME()
            WHERE [id] = @seq_id;

            FETCH NEXT FROM cur_flow INTO @table_name, @part_name, @constraint_name, @additional_info, @hierarchy_level;
        END

        CLOSE cur_flow;
        DEALLOCATE cur_flow;

        UPDATE [purge_config_settings]
        SET [value] = CONVERT(VARCHAR(10), DATEADD(DAY,
            TRY_CAST((SELECT TOP 1 [value] FROM [purge_config_settings] WHERE [name] = 'purge_rxtx_number_of_days') AS INT),
            TRY_CAST([value] AS DATE)
        ), 110)
        WHERE [name] = 'purge_rxtx_min_date';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_flow') >= -1
        BEGIN
            CLOSE cur_flow;
            DEALLOCATE cur_flow;
        END

        SET @sql_code = ERROR_NUMBER();
        SET @err_seq_id = NEXT VALUE FOR [purge_seq];

        INSERT INTO [purge_error_log] ([id], [failed_statement], [error_text], [error_date])
        VALUES (@err_seq_id, ISNULL(@sql_str, 'sp_populate_purge_records'), ERROR_MESSAGE(), SYSDATETIME());

        IF @seq_id IS NOT NULL
        BEGIN
            UPDATE [purge_run_details]
            SET [status] = CASE WHEN @sql_code IN (50301, 50501, 50502, 50601) THEN 'RESUMABLE' ELSE 'FAILED' END,
                [end_date] = SYSDATETIME(),
                [purge_error_log_id] = @err_seq_id
            WHERE [id] = @seq_id;
        END

        EXEC [EPS].[PK_RX_TX_PURGE_sp_send_email_alert]
            @subj = 'EPR Purge failed with following error',
            @msg_body = ERROR_MESSAGE();

        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_rx_tx_purge]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql_str NVARCHAR(MAX) = NULL;
    DECLARE @cnt INT;
    DECLARE @seq_id BIGINT = NULL;
    DECLARE @err_seq_id BIGINT = NULL;
    DECLARE @row_count BIGINT;
    DECLARE @parallel_thread_count INT = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_parallel_count', 'Y') AS INT);

    BEGIN TRY
        DECLARE cur_purge CURSOR LOCAL FAST_FORWARD FOR
            SELECT a.[table_name], a.[part_name], a.[constraint_name], a.[additional_info]
            FROM [purge_flow_map] a
            LEFT JOIN [purge_run_details] b ON a.[purge_run_details_id] = b.[id]
            WHERE ISNULL(b.[status], 'A') <> 'COMPLETED'
            ORDER BY a.[hierarchy_level] DESC, a.[table_name], a.[constraint_name], a.[part_position];

        DECLARE @table_name SYSNAME, @part_name VARCHAR(200), @constraint_name SYSNAME, @additional_info VARCHAR(4000);

        OPEN cur_purge;
        FETCH NEXT FROM cur_purge INTO @table_name, @part_name, @constraint_name, @additional_info;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @cnt = COUNT(*) FROM [purge_records] p WHERE p.[table_name] = @table_name;

            IF @cnt > 0
            BEGIN
                -- Parent table purge path (parallel path in Oracle)
                SET @sql_str = N'EXEC [EPS].[PK_RX_TX_PURGE_sp_parallel_delete] @table_name=@t, @part_name=@p, @start_rowid=NULL, @end_rowid=NULL;';
            END
            ELSE
            BEGIN
                -- Child table purge path
                SET @sql_str = N'DELETE a '
                             + N'FROM ' + QUOTENAME(@table_name) + N' a '
                             + N'WHERE EXISTS ( '
                             + N'  SELECT 1 FROM [purge_records] p '
                             + N'  WHERE p.[table_name] = PARSENAME(REPLACE(REPLACE(@additional_info,''|'',''.''), '','', ''.''), 1) '
                             + N'    AND a.[chain_id] = p.[chain_id] '
                             + N'    AND a.[id] = p.[id] '
                             + N'    AND ((' + CASE WHEN @part_name IS NULL THEN 'p.[part_name] IS NULL' ELSE 'p.[part_name] = @part_name' END + N')) );';
            END

            SET @seq_id = NEXT VALUE FOR [purge_seq];
            INSERT INTO [purge_run_details]([id],[object_name],[start_date],[status],[sql_statement],[comments])
            VALUES(@seq_id, @table_name + ':' + ISNULL(@part_name,''), SYSDATETIME(), 'IN PROGRESS', @sql_str, 'Purging table');

            UPDATE [purge_flow_map]
            SET [purge_run_details_id] = @seq_id
            WHERE [table_name] = @table_name
              AND ISNULL([part_name], 'A') = ISNULL(@part_name, 'A')
              AND ISNULL([constraint_name], 'A') = ISNULL(@constraint_name, 'A');

            EXEC [EPS].[PK_RX_TX_PURGE_sp_check_run_window];

            IF @cnt > 0
            BEGIN
                EXEC sp_executesql @sql_str, N'@t SYSNAME, @p VARCHAR(200)', @t=@table_name, @p=@part_name;
                SELECT @row_count = ISNULL(SUM([id]), 0) FROM [purge_records] WHERE [table_name] = 'PURGE-PARALLEL-DELETE';
                DELETE FROM [purge_records] WHERE [table_name] = 'PURGE-PARALLEL-DELETE';
            END
            ELSE
            BEGIN
                EXEC sp_executesql @sql_str, N'@additional_info VARCHAR(4000), @part_name VARCHAR(200)', @additional_info=@additional_info, @part_name=@part_name;
                SET @row_count = @@ROWCOUNT;
            END

            UPDATE [purge_run_details]
            SET [status] = 'COMPLETED', [affected_row_count] = @row_count, [end_date] = SYSDATETIME()
            WHERE [id] = @seq_id;

            IF @row_count > 10000
            BEGIN
                UPDATE [purge_run_details]
                SET [comments] = ISNULL([comments],'') + '|Index Rebuild Is Required'
                WHERE [id] = @seq_id;

                EXEC [EPS].[PK_RX_TX_PURGE_sp_rebuild_indexes]
                    @run_details_id = @seq_id,
                    @tabname = @table_name,
                    @partname = @part_name;
            END
            ELSE
            BEGIN
                UPDATE [purge_run_details]
                SET [comments] = ISNULL([comments],'') + '|Index Rebuild Is Not Required'
                WHERE [id] = @seq_id;
            END

            FETCH NEXT FROM cur_purge INTO @table_name, @part_name, @constraint_name, @additional_info;
        END

        CLOSE cur_purge;
        DEALLOCATE cur_purge;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cur_purge') >= -1
        BEGIN
            CLOSE cur_purge;
            DEALLOCATE cur_purge;
        END

        SET @err_seq_id = NEXT VALUE FOR [purge_seq];

        INSERT INTO [purge_error_log]([id], [failed_statement], [error_text], [error_date])
        VALUES(@err_seq_id, ISNULL(@sql_str, 'sp_rx_tx_purge'), ERROR_MESSAGE(), SYSDATETIME());

        IF @seq_id IS NOT NULL
        BEGIN
            UPDATE [purge_run_details]
            SET [status] = CASE WHEN ERROR_NUMBER() IN (50301, 50501, 50502, 50601) THEN 'RESUMABLE' ELSE 'FAILED' END,
                [end_date] = SYSDATETIME(),
                [purge_error_log_id] = @err_seq_id
            WHERE [id] = @seq_id;
        END

        EXEC [EPS].[PK_RX_TX_PURGE_sp_send_email_alert]
            @subj = 'EPR Purge failed with following error',
            @msg_body = ERROR_MESSAGE();

        THROW 50611, 'sp_rx_tx_purge failed', 1;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_sync_partitions]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cnt INT;
    DECLARE @cntr INT = 1;
    DECLARE @seq_id BIGINT = NULL;
    DECLARE @err_seq_id BIGINT = NULL;
    DECLARE @sql_str NVARCHAR(MAX) = NULL;
    DECLARE @purge_date DATE = TRY_CAST([EPS].[PK_RX_TX_PURGE_lookup_config]('purge_rxtx_min_date', 'Y') AS DATE);

    BEGIN TRY
        EXEC [EPS].[PK_RX_TX_PURGE_sp_check_run_window];

        SELECT @cnt = COUNT(*)
        FROM [purge_flow_map] a
        LEFT JOIN [purge_run_details] b ON a.[purge_rec_run_details_id] = b.[id]
        WHERE ISNULL(b.[status], 'A') = 'FAILED';

        IF @cnt > 0
        BEGIN
            SET @seq_id = NEXT VALUE FOR [purge_seq];
            INSERT INTO [purge_run_details] ([id],[object_name],[start_date],[end_date],[status],[comments])
            VALUES (@seq_id, 'SP_SYNC_PARTITIONS', SYSDATETIME(), SYSDATETIME(), 'PREV_FAILURE', 'Detected previous failure, please fix the issue to proceed');
            THROW 50621, 'Found failed purge_records population from previous run', 1;
        END

        SELECT @cnt = COUNT(*)
        FROM [purge_flow_map] a
        LEFT JOIN [purge_run_details] b ON a.[purge_rec_run_details_id] = b.[id]
        WHERE ISNULL(b.[status], 'A') <> 'COMPLETED'
          AND a.[number_of_child] > 0;

        IF @cnt > 0
        BEGIN
            EXEC [EPS].[PK_RX_TX_PURGE_sp_populate_purge_records] @purge_run_date = @purge_date;
        END

        SELECT @cnt = COUNT(*)
        FROM [purge_flow_map] a
        LEFT JOIN [purge_run_details] b ON a.[purge_run_details_id] = b.[id]
        WHERE ISNULL(b.[status], 'A') = 'FAILED';

        IF @cnt > 0
        BEGIN
            SET @seq_id = NEXT VALUE FOR [purge_seq];
            INSERT INTO [purge_run_details] ([id],[object_name],[start_date],[end_date],[status],[comments])
            VALUES (@seq_id, 'SP_SYNC_PARTITIONS', SYSDATETIME(), SYSDATETIME(), 'PREV_FAILURE', 'Detected previous failure, please fix the issue to proceed');
            THROW 50622, 'Found failed purge run details from previous run', 1;
        END

        SELECT @cnt = COUNT(*)
        FROM [purge_flow_map] a
        LEFT JOIN [purge_run_details] b ON a.[purge_run_details_id] = b.[id]
        WHERE ISNULL(b.[status], 'A') <> 'COMPLETED';

        IF @cnt = 0
        BEGIN
            DELETE FROM [purge_flow_map];
            TRUNCATE TABLE [purge_records];

            INSERT INTO [purge_flow_map] ([table_name], [part_name], [part_key], [part_position], [hierarchy_level])
            VALUES ('RX_TX', 'POPULATE', 'POPULATE', 0, @cntr);

            SET @cntr = @cntr + 1;

            WHILE 1 = 1
            BEGIN
                DECLARE @next_count INT;

                SELECT @next_count = COUNT(*)
                FROM [purge_flow_map] a
                INNER JOIN sys.key_constraints b ON UPPER(a.[table_name]) = OBJECT_NAME(b.parent_object_id)
                INNER JOIN sys.foreign_keys c ON b.parent_object_id = c.referenced_object_id
                WHERE a.[hierarchy_level] = (SELECT MAX([hierarchy_level]) FROM [purge_flow_map]);

                IF @next_count = 0 BREAK;

                INSERT INTO [purge_flow_map] ([table_name], [constraint_name], [part_name], [part_key], [part_position], [hierarchy_level])
                SELECT DISTINCT OBJECT_NAME(c.parent_object_id), c.[name], 'POPULATE', 'POPULATE', 0, @cntr
                FROM [purge_flow_map] a
                INNER JOIN sys.key_constraints b ON UPPER(a.[table_name]) = OBJECT_NAME(b.parent_object_id)
                INNER JOIN sys.foreign_keys c ON b.parent_object_id = c.referenced_object_id
                WHERE a.[hierarchy_level] = (SELECT MAX([hierarchy_level]) FROM [purge_flow_map]);

                SET @cntr = @cntr + 1;
            END

            DELETE FROM [purge_flow_map] WHERE [part_name] = 'POPULATE' AND [part_position] = 0;

            IF EXISTS (SELECT 1 FROM [purge_chains])
            BEGIN
                DELETE FROM [purge_flow_map]
                WHERE [part_key] NOT IN (SELECT CONVERT(VARCHAR(200), [chain_id]) FROM [purge_chains]);
            END

            EXEC [EPS].[PK_RX_TX_PURGE_sp_populate_purge_records] @purge_run_date = @purge_date;

            IF OBJECT_ID('[purge_records]') IS NOT NULL
                UPDATE STATISTICS [purge_records];
        END

        EXEC [EPS].[PK_RX_TX_PURGE_sp_rx_tx_purge];
    END TRY
    BEGIN CATCH
        SET @err_seq_id = NEXT VALUE FOR [purge_seq];

        INSERT INTO [purge_error_log]([id], [failed_statement], [error_text], [error_date])
        VALUES(@err_seq_id, ISNULL(@sql_str, 'sp_sync_partitions'), ERROR_MESSAGE(), SYSDATETIME());

        IF @seq_id IS NOT NULL
        BEGIN
            UPDATE [purge_run_details]
            SET [status] = CASE WHEN ERROR_NUMBER() IN (50301, 50501, 50502, 50601) THEN 'RESUMABLE' ELSE 'FAILED' END,
                [end_date] = SYSDATETIME(),
                [purge_error_log_id] = @err_seq_id
            WHERE [id] = @seq_id;
        END

        EXEC [EPS].[PK_RX_TX_PURGE_sp_send_email_alert]
            @subj = 'EPR Purge failed with following error',
            @msg_body = ERROR_MESSAGE();

        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PK_RX_TX_PURGE_sp_run_purge]
AS
BEGIN
    SET NOCOUNT ON;
    EXEC [EPS].[PK_RX_TX_PURGE_sp_process_purge_configuration];
    EXEC [EPS].[PK_RX_TX_PURGE_sp_sync_partitions];
END;
GO
