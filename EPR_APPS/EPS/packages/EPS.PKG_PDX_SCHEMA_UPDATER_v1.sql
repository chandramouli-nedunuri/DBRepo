IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'EPS')
BEGIN
    EXEC(N'CREATE SCHEMA [EPS]');
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_apply]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @l_processed BIT = 0;
    DECLARE @l_skipped BIT = 0;
    DECLARE @l_result BIT = 0;
    DECLARE @l_task NVARCHAR(255) = NULL;
    DECLARE @l_ver NVARCHAR(50) = NULL;
    DECLARE @l_rtn BIT = 1;
    DECLARE @task_proc_ind INT = NULL;

    DECLARE @is_deprecated BIT = 0;
    DECLARE @is_excluded BIT = 0;
    DECLARE @status NVARCHAR(10) = NULL;
    DECLARE @applysprint NVARCHAR(20) = NULL;
    DECLARE @run_rc INT = 0;

    CREATE TABLE #task_list
    (
        file_name NVARCHAR(255) NOT NULL PRIMARY KEY,
        proc_ind INT NOT NULL
    );

    CREATE TABLE #task_ver
    (
        file_name NVARCHAR(255) NOT NULL PRIMARY KEY,
        release_version NVARCHAR(50) NULL
    );

    CREATE TABLE #task_proc
    (
        proc_ind INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        file_name NVARCHAR(255) NOT NULL UNIQUE
    );

    CREATE TABLE #attribcheck
    (
        attrib_line NVARCHAR(MAX) NOT NULL
    );

    ;WITH file_list AS
    (
        SELECT
            file_name,
            CASE file_type WHEN 'R' THEN 'Release' WHEN 'T' THEN 'Task' END AS [type],
            task_version AS info
        FROM [EPS].[pdx_schema_file_taskver]
        WHERE file_type IN ('R','T')
    ),
    task_list_map AS
    (
        SELECT
            f.file_name AS version_file_name,
            UPPER(m.task_version_value) AS task
        FROM [EPS].[pdx_schema_taskver_meta] AS m
        INNER JOIN [EPS].[pdx_schema_file_taskver] AS f
            ON f.task_version = m.task_version
        WHERE m.meta_tag = N'RELEASETASK'
          AND m.task_source = N'B'
    ),
    version_map AS
    (
        SELECT
            t.file_name,
            MIN(v.info) AS release_version
        FROM task_list_map AS l
        INNER JOIN file_list AS t
            ON t.[type] = 'Task'
           AND l.task = t.info
        INNER JOIN file_list AS v
            ON v.[type] = 'Release'
           AND v.file_name = l.version_file_name
        GROUP BY t.file_name
    ),
    base_tasks AS
    (
        SELECT
            f.file_name,
            vm.release_version,
            m.apply_order,
            ROW_NUMBER() OVER (ORDER BY m.apply_order, f.file_name) AS rn
        FROM [EPS].[pdx_schema_file_taskver] AS f
        INNER JOIN [EPS].[schema_updater_sql] AS s1
            ON s1.file_name = f.file_name
        LEFT JOIN [EPS].[pdx_schema_updater_sql] AS s2
            ON s2.file_name = f.file_name
        LEFT JOIN version_map AS vm
            ON vm.file_name = f.file_name
        LEFT JOIN [EPS].[vw_schema_updater_manifest] AS m
            ON m.version = vm.release_version
        WHERE f.file_type = 'T'
          AND (ISNULL(f.action_code, N'R') <> N'A' OR ISNULL(f.status_code, N'S') <> N'S')
          AND (
                s2.file_name IS NULL
                OR ISNULL(CAST(s1.sql AS NVARCHAR(MAX)), N'') <> ISNULL(CAST(s2.sql AS NVARCHAR(MAX)), N'')
              )
    )
    INSERT INTO #task_proc(file_name)
    SELECT bt.file_name
    FROM base_tasks AS bt
    ORDER BY bt.rn;

    ;WITH file_list AS
    (
        SELECT
            file_name,
            CASE file_type WHEN 'R' THEN 'Release' WHEN 'T' THEN 'Task' END AS [type],
            task_version AS info
        FROM [EPS].[pdx_schema_file_taskver]
        WHERE file_type IN ('R','T')
    ),
    task_list_map AS
    (
        SELECT
            f.file_name AS version_file_name,
            UPPER(m.task_version_value) AS task
        FROM [EPS].[pdx_schema_taskver_meta] AS m
        INNER JOIN [EPS].[pdx_schema_file_taskver] AS f
            ON f.task_version = m.task_version
        WHERE m.meta_tag = N'RELEASETASK'
          AND m.task_source = N'B'
    ),
    version_map AS
    (
        SELECT
            t.file_name,
            MIN(v.info) AS release_version
        FROM task_list_map AS l
        INNER JOIN file_list AS t
            ON t.[type] = 'Task'
           AND l.task = t.info
        INNER JOIN file_list AS v
            ON v.[type] = 'Release'
           AND v.file_name = l.version_file_name
        GROUP BY t.file_name
    )
    INSERT INTO #task_ver(file_name, release_version)
    SELECT p.file_name, vm.release_version
    FROM #task_proc AS p
    LEFT JOIN version_map AS vm
        ON vm.file_name = p.file_name;

    INSERT INTO #task_list(file_name, proc_ind)
    SELECT p.file_name, p.proc_ind
    FROM #task_proc AS p;

    SELECT @task_proc_ind = MIN(proc_ind) FROM #task_proc;
    IF @task_proc_ind IS NOT NULL
    BEGIN
        SELECT @l_task = file_name FROM #task_proc WHERE proc_ind = @task_proc_ind;
    END;

    WHILE @task_proc_ind IS NOT NULL
    BEGIN
        SET @is_deprecated = 0;
        SET @is_excluded = 0;
        SET @status = NULL;

        IF EXISTS
        (
            SELECT 1
            FROM [EPS].[pdx_schema_updater_sql] s
            JOIN [EPS].[pdx_schema_file_taskver] f1
              ON f1.file_name = s.file_name
            JOIN [EPS].[pdx_schema_taskver_meta] m
              ON m.meta_tag = 'DEPRECATES'
             AND m.task_source = 'A'
             AND m.task_version = f1.task_version
            JOIN [EPS].[pdx_schema_file_taskver] f2
              ON UPPER(m.task_version_value) = UPPER(f2.task_version)
            WHERE s.action_code = 'A'
              AND s.status_code = 'S'
              AND (f2.file_name = @l_task OR UPPER(f2.task_version) = UPPER(@l_task))
        )
        BEGIN
            SET @is_deprecated = 1;
        END
        ELSE
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM
                (
                    SELECT f1.file_name
                    FROM [EPS].[pdx_schema_file_taskver] f1
                    JOIN [EPS].[pdx_schema_taskver_meta] m
                      ON m.meta_tag = 'DEPRECATES'
                     AND m.task_source = 'B'
                     AND m.task_version = f1.task_version
                    JOIN [EPS].[pdx_schema_file_taskver] f2
                      ON UPPER(m.task_version_value) = UPPER(f2.task_version)
                    WHERE (f2.file_name = @l_task OR UPPER(f2.task_version) = UPPER(@l_task))
                ) b
                JOIN #task_list tl
                  ON tl.file_name = b.file_name
            )
            BEGIN
                SET @is_deprecated = 1;
            END
        END

        IF @is_deprecated = 1
        BEGIN
            SELECT TOP (1) @status = ISNULL(status_code, N'RS')
            FROM [EPS].[pdx_schema_updater_sql]
            WHERE file_name = @l_task
            ORDER BY [version] DESC;

            IF ISNULL(@status, N'RS') IN (N'RS', N'RD')
            BEGIN
                EXEC [EPS].[log_sql]
                    @p_call_id,
                    @p_version_id,
                    @l_task,
                    N'A',
                    N'D',
                    N'Task has been deprecated and will not be applied';
            END;

            DELETE FROM #task_list WHERE file_name = @l_task;
            DELETE FROM #task_ver WHERE file_name = @l_task;
            DELETE FROM #task_proc WHERE proc_ind = @task_proc_ind;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @applysprint = UPPER(m.task_version_value)
            FROM [EPS].[pdx_schema_file_taskver] f
            JOIN [EPS].[pdx_schema_taskver_meta] m
              ON m.task_version = f.task_version
            WHERE f.file_name = @l_task
              AND m.meta_tag = N'APPLYSPRINT'
              AND m.task_source = N'A';

            SET @is_excluded =
                CASE WHEN ISNULL(@applysprint, N'YES') IN (N'FALSE', N'NO') THEN 1 ELSE 0 END;

            IF @is_excluded = 1
            BEGIN
                SELECT TOP (1) @status = ISNULL(status_code, N'RS')
                FROM [EPS].[pdx_schema_updater_sql]
                WHERE file_name = @l_task
                ORDER BY [version] DESC;

                IF ISNULL(@status, N'RS') = N'RS'
                BEGIN
                    EXEC [EPS].[log_sql]
                        @p_call_id,
                        @p_version_id,
                        @l_task,
                        N'A',
                        N'X',
                        N'Task has been excluded and will not be applied';
                END;

                DELETE FROM #task_list WHERE file_name = @l_task;
                DELETE FROM #task_ver WHERE file_name = @l_task;
                DELETE FROM #task_proc WHERE proc_ind = @task_proc_ind;
            END
            ELSE
            BEGIN
                DELETE FROM #attribcheck;

                INSERT INTO #attribcheck(attrib_line)
                SELECT CAST(m.task_version_value AS NVARCHAR(MAX))
                FROM [EPS].[pdx_schema_file_taskver] f
                JOIN [EPS].[pdx_schema_taskver_meta] m
                  ON m.task_version = f.task_version
                WHERE f.file_name = @l_task
                  AND m.meta_tag = N'ATTRIBCHECK'
                  AND m.task_source = N'A';

                IF EXISTS
                (
                    SELECT 1
                    FROM #attribcheck ac
                    WHERE NULLIF(
                              LTRIM(RTRIM(
                                  CASE
                                      WHEN CHARINDEX(N':', ac.attrib_line) > 0
                                          THEN LEFT(ac.attrib_line, CHARINDEX(N':', ac.attrib_line) - 1)
                                      ELSE ac.attrib_line
                                  END
                              )),
                              N''
                          ) IS NOT NULL
                )
                BEGIN
                    SET @l_rtn = 0;

                    EXEC [EPS].[log_sql]
                        @p_call_id,
                        @p_version_id,
                        @l_task,
                        N'A',
                        N'F',
                        N'Task contains invalid metadata ATTRIBCHECK';

                    DELETE FROM #task_list WHERE file_name = @l_task;
                    DELETE FROM #task_ver WHERE file_name = @l_task;
                    DELETE FROM #task_proc WHERE proc_ind = @task_proc_ind;
                END
            END
        END

        SELECT @task_proc_ind = MIN(proc_ind)
        FROM #task_proc
        WHERE proc_ind > @task_proc_ind;

        IF @task_proc_ind IS NOT NULL
        BEGIN
            SELECT @l_task = file_name FROM #task_proc WHERE proc_ind = @task_proc_ind;
        END
    END

    SET @l_processed = 1;
    WHILE EXISTS (SELECT 1 FROM #task_list) AND @l_processed = 1
    BEGIN
        SELECT @task_proc_ind = MIN(proc_ind) FROM #task_proc;
        SELECT @l_task = file_name FROM #task_proc WHERE proc_ind = @task_proc_ind;
        SELECT @l_ver = release_version FROM #task_ver WHERE file_name = @l_task;

        SET @l_processed = 0;
        SET @l_skipped = 0;

        WHILE @task_proc_ind IS NOT NULL
        BEGIN
            IF [EPS].[dependencies_met](@l_task) = 1
            BEGIN
                SET @l_processed = 1;

                EXEC @run_rc = [EPS].[run_sql]
                    @p_call_id,
                    @p_version_id,
                    @l_task,
                    N'A';

                SET @l_result = CASE WHEN ISNULL(@run_rc, 0) = 0 THEN 0 ELSE 1 END;
                IF ISNULL(@l_result, 0) = 0 SET @l_rtn = 0;

                DELETE FROM #task_list WHERE file_name = @l_task;
                DELETE FROM #task_ver WHERE file_name = @l_task;
                DELETE FROM #task_proc WHERE proc_ind = @task_proc_ind;
            END
            ELSE
            BEGIN
                SET @l_skipped = 1;
            END

            SELECT @task_proc_ind = MIN(proc_ind)
            FROM #task_proc
            WHERE proc_ind > @task_proc_ind;

            IF @task_proc_ind IS NULL BREAK;

            SELECT @l_task = file_name FROM #task_proc WHERE proc_ind = @task_proc_ind;

            IF ISNULL((SELECT release_version FROM #task_ver WHERE file_name = @l_task), [EPS].[get_config](N'TASK_VERSION'))
               <> ISNULL(@l_ver, [EPS].[get_config](N'TASK_VERSION'))
            BEGIN
                IF @l_skipped = 1 AND @l_processed = 1 BREAK;
            END

            SELECT @l_ver = release_version FROM #task_ver WHERE file_name = @l_task;
        END
    END

    WHILE EXISTS (SELECT 1 FROM #task_list)
    BEGIN
        SELECT TOP (1) @l_task = file_name
        FROM #task_list
        ORDER BY proc_ind, file_name;

        SET @l_rtn = 0;

        EXEC [EPS].[log_task_history]
            @p_call_id,
            @p_version_id,
            @l_task,
            N'A',
            N'F',
            N'Task cannot be applied as there are missing required tasks';

        DELETE FROM #task_list WHERE file_name = @l_task;
    END

    SET @return_value = ISNULL(@l_rtn, 0);
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_end]
    @p_call_id DECIMAL(38,10),
    @p_rc DECIMAL(38,10),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_call_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_apply_sql]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_filename BIT = NULL,
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.apply_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_refresh_config]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.refresh_config', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_start]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_task_start', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_start]
    @p_call_id DECIMAL(38,10),
    @p_current_version NVARCHAR(4000),
    @p_target_version NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_version_start', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_get_sql]
    @p_fname NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @return_value NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = NULL;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.get_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_get_config]
    @p_key NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = NULL;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.get_config', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_schema]
    @p_target_version NVARCHAR(4000),
    @p_return_code DECIMAL(38,10) OUTPUT,
    @p_allow_downgrade BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.update_schema', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_start]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_sql_start', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_rollback_sql]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.rollback_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_run_sql]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.run_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_process_start]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_process NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_process_start', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_task_based]
    @p_call_id DECIMAL(38,10),
    @p_target_version NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.update_task_based', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_update_release_based]
    @p_call_id DECIMAL(38,10),
    @p_current_version NVARCHAR(4000),
    @p_target_version NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.update_release_based', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_task_based_rollback]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_target_version NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.task_based_rollback', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_schema_version]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.schema_version', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_get_status]
    @p_fname NVARCHAR(4000),
    @return_value NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = NULL;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.get_status', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_version_updater]
    @p_call_id DECIMAL(38,10),
    @p_current_version NVARCHAR(4000),
    @p_target_version NVARCHAR(4000),
    @p_filename NVARCHAR(4000),
    @p_action BIT = NULL,
    @but NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.version_updater', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_call_start]
    @p_target_version NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_call_start', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_create_synonyms_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.create_synonyms_on_own_objs', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_partitionby]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.replace_partitionby', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_sbmo_meijer]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.replace_sbmo_meijer', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_grant_privs_on_own_objs]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.grant_privs_on_own_objs', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_dependencies_met]
    @p_fname NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.dependencies_met', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_dos2unix]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.dos2unix', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sys_sql_end]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_task_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_sys_sql_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_parse_sql]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.parse_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_parms]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.replace_parms', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_replace_tablespace]
    @p_ddl_sql NVARCHAR(MAX) OUTPUT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.replace_tablespace', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_run_statement]
    @p_sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.run_statement', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_updater_version]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.updater_version', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_compare_versions]
    @p_version1 NVARCHAR(4000),
    @p_version2 NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.compare_versions', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_reset_schema]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.reset_schema', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_purge_schema_error_logs]
    @p_until_date DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.purge_schema_error_logs', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_end]
    @p_task_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000),
    @p_action NVARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index DECIMAL(38,10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_sql_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_convert_to_release]
    @p_version NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.convert_to_release', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_is_deprecated]
    @p_filename DECIMAL(38,10),
    @p_task_list NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.is_deprecated', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_is_excluded]
    @p_filename DECIMAL(38,10),
    @is_sprint BIT,
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.is_excluded', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_history]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000),
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index DECIMAL(38,10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_task_history', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_convert_to_task]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.convert_to_task', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_version_end]
    @p_version_id DECIMAL(38,10),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_version_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_rb_dependencies_met]
    @p_fname NVARCHAR(4000),
    @return_value BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.rb_dependencies_met', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql_progress]
    @p_filename NVARCHAR(4000),
    @p_index DECIMAL(38,10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_sql_progress', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_sql]
    @p_call_id DECIMAL(38,10),
    @p_version_id DECIMAL(38,10),
    @p_filename NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000),
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index DECIMAL(38,10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_sql', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_process_end]
    @p_process_id DECIMAL(38,10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_process_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_log_task_end]
    @p_task_id DECIMAL(38,10),
    @p_status NVARCHAR(4000),
    @p_error_record NVARCHAR(4000),
    @p_action NVARCHAR(4000) = NULL,
    @p_sql_text NVARCHAR(MAX) = NULL,
    @p_index DECIMAL(38,10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.log_task_end', 1;
END;
GO

CREATE OR ALTER PROCEDURE [EPS].[PKG_PDX_SCHEMA_UPDATER_get_index]
    @p_fname NVARCHAR(4000),
    @p_action NVARCHAR(4000),
    @return_value DECIMAL(38,10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @return_value = 0;
    THROW 53090, 'Manual conversion required for EPS.PKG_PDX_SCHEMA_UPDATER.get_index', 1;
END;
GO
