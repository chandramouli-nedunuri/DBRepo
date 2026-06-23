CREATE OR ALTER PROCEDURE EPS.SP_REVERSE_ORDER_PURGE
    @tab_name NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle procedure converted to Azure SQL.

        Key Oracle features not supported in Azure SQL:
        - EXECUTE IMMEDIATE
        - partition-qualified dynamic SQL as written in Oracle
        - DBMS_APPLICATION_INFO
        - sequence NEXTVAL syntax
        - Oracle-specific date/session commands
        - implicit COMMIT inside procedure flow

        This version keeps the purge business rules and ledger tracking
        using static T-SQL where possible.
    */

    DECLARE @table_name NVARCHAR(30) = UPPER(@tab_name);
    DECLARE @purge_keep_date DATE = DATEADD(MONTH, -36, CAST(GETDATE() AS DATE));
    DECLARE @run_seq BIGINT;
    DECLARE @row_count BIGINT = 0;
    DECLARE @err_code NVARCHAR(100);
    DECLARE @err_text NVARCHAR(4000);
    DECLARE @sql_str NVARCHAR(MAX);

    IF @table_name IS NULL
    BEGIN
        THROW 50001, 'Table Name must be passed as a parameter', 1;
    END

    SELECT @run_seq = NEXT VALUE FOR EPS.purge_seq;

    INSERT INTO EPS.purge_ledger
        (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date)
    VALUES
        (@run_seq, @table_name, 'START PURGE', 'Starting Prescription Purge', NULL, NULL, SYSDATETIME());

    DECLARE @par_tab_cnt INT = 0;
    DECLARE @row_exists INT = 0;

    SELECT @par_tab_cnt = COUNT(*)
    FROM sys.tables
    WHERE name = 'RX_TX_OLD'
      AND SCHEMA_NAME(schema_id) = 'EPS';

    IF (@table_name = 'TX_TP')
    BEGIN
        SELECT @row_exists = COUNT(*)
        FROM sys.tables
        WHERE name = 'TX_TP_OLD'
          AND SCHEMA_NAME(schema_id) = 'EPS';

        IF (@row_exists > 0)
            THROW 50005, 'TX_TP has already been purged!', 1;

        IF (@par_tab_cnt = 0)
            THROW 50005, 'Parent table (RX_TX) has not been purged yet!', 1;

        TRUNCATE TABLE EPS.TX_TP_N;
    END
    ELSE IF (@table_name = 'RX_TX_DIAGNOSIS_CODES')
    BEGIN
        SELECT @row_exists = COUNT(*)
        FROM sys.tables
        WHERE name = 'RX_TX_DIAGNOSIS_CODES_OLD'
          AND SCHEMA_NAME(schema_id) = 'EPS';

        IF (@row_exists > 0)
            THROW 50003, 'RX_TX_DIAGNOSIS_CODES has already been purged!', 1;

        IF (@par_tab_cnt = 0)
            THROW 50003, 'Parent table (RX_TX) has not been purged yet!', 1;

        TRUNCATE TABLE EPS.RX_TX_DIAGNOSIS_CODES_N;
    END
    ELSE IF (@table_name = 'TX_CRED')
    BEGIN
        SELECT @row_exists = COUNT(*)
        FROM sys.tables
        WHERE name = 'TX_CRED_OLD'
          AND SCHEMA_NAME(schema_id) = 'EPS';

        IF (@row_exists > 0)
            THROW 50004, 'TX_CRED has already been purged!', 1;

        IF (@par_tab_cnt = 0)
            THROW 50004, 'Parent table (RX_TX) has not been purged yet!', 1;

        TRUNCATE TABLE EPS.TX_CRED_N;
    END
    ELSE IF (@table_name = 'RX_TX')
    BEGIN
        IF (@par_tab_cnt > 0)
            THROW 50007, 'RX_TX table has already been purged!', 1;

        TRUNCATE TABLE EPS.RX_TX_N;
    END
    ELSE IF (@table_name = 'PA_NUM')
    BEGIN
        SELECT @row_exists = COUNT(*)
        FROM sys.tables
        WHERE name = 'PA_NUM_OLD'
          AND SCHEMA_NAME(schema_id) = 'EPS';

        IF (@row_exists > 0)
            THROW 50005, 'PA_NUM has already been purged!', 1;

        SELECT @par_tab_cnt = COUNT(*)
        FROM sys.tables
        WHERE name = 'TX_TP_OLD'
          AND SCHEMA_NAME(schema_id) = 'EPS';

        IF (@par_tab_cnt = 0)
            THROW 50005, 'Parent table (TX_TP) has not been purged yet!', 1;

        TRUNCATE TABLE EPS.PA_NUM_N;
    END
    ELSE
    BEGIN
        THROW 50007, CONCAT('Table ', @table_name, ' is not a candidate of prescription purge'), 1;
    END

    BEGIN TRY
        IF (@table_name = 'RX_TX')
        BEGIN
            INSERT INTO EPS.RX_TX_N
            SELECT r.*
            FROM EPS.RX_TX AS r
            WHERE (
                    CASE
                        WHEN r.filled IS NULL AND r.written IS NULL THEN r.last_updated
                        WHEN r.filled IS NULL AND r.written IS NOT NULL THEN r.written
                        WHEN r.filled IS NOT NULL AND r.written IS NULL THEN r.filled
                        ELSE CASE WHEN r.filled > r.written THEN r.filled ELSE r.written END
                    END >= @purge_keep_date
                  )
               OR (r.rx_status = 'I' AND r.why_deactivated IS NULL);

            SET @row_count = @@ROWCOUNT;
        END
        ELSE IF (@table_name = 'RX_TX_DIAGNOSIS_CODES')
        BEGIN
            INSERT INTO EPS.RX_TX_DIAGNOSIS_CODES_N
            SELECT p.*
            FROM EPS.RX_TX_DIAGNOSIS_CODES AS p
            INNER JOIN EPS.RX_TX AS t
                ON p.id_rx_tx = t.id
               AND p.chain_id = t.chain_id;

            SET @row_count = @@ROWCOUNT;
        END
        ELSE IF (@table_name = 'TX_CRED')
        BEGIN
            INSERT INTO EPS.TX_CRED_N
            SELECT p.*
            FROM EPS.TX_CRED AS p
            INNER JOIN EPS.RX_TX AS t
                ON p.id_rx_tx = t.id
               AND p.chain_id = t.chain_id;

            SET @row_count = @@ROWCOUNT;
        END
        ELSE IF (@table_name = 'TX_TP')
        BEGIN
            INSERT INTO EPS.TX_TP_N
            SELECT p.*
            FROM EPS.TX_TP AS p
            INNER JOIN EPS.RX_TX AS t
                ON p.id_rx_tx = t.id
               AND p.chain_id = t.chain_id;

            SET @row_count = @@ROWCOUNT;
        END
        ELSE IF (@table_name = 'PA_NUM')
        BEGIN
            INSERT INTO EPS.PA_NUM_N
            SELECT p.*
            FROM EPS.PA_NUM AS p
            INNER JOIN EPS.TX_TP AS t
                ON p.id_tx_tp = t.id
               AND p.chain_id = t.chain_id;

            SET @row_count = @@ROWCOUNT;
        END

        UPDATE EPS.purge_ledger
        SET action_status = 'Completed',
            end_date = SYSDATETIME(),
            rows_affected = @row_count
        WHERE id = @run_seq;

        SELECT @run_seq = NEXT VALUE FOR EPS.purge_seq;

        INSERT INTO EPS.purge_ledger
            (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date)
        VALUES
            (@run_seq, @table_name, 'END PURGE', 'Finished Prescription Purge', NULL, NULL, SYSDATETIME());
    END TRY
    BEGIN CATCH
        SET @err_code = CONVERT(NVARCHAR(100), ERROR_NUMBER());
        SET @err_text = ERROR_MESSAGE();

        UPDATE EPS.purge_ledger
        SET action_status = 'Failed',
            end_date = SYSDATETIME(),
            rows_affected = 0,
            sql_text = @sql_str,
            error_text = @err_code + N' ==> ' + @err_text
        WHERE id = @run_seq;

        THROW;
    END CATCH
END;
GO