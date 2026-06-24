CREATE OR ALTER PROCEDURE EPS.SP_RESET_LEVEL_OF
    @p_chain_id     INT,
    @p_job_class    NVARCHAR(60),
    @p_chunk_size    INT = 2000,
    @p_parallel_cnt  INT = 8
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle procedure SP_RESET_LEVEL_OF uses:
        - DBMS_PARALLEL_EXECUTE
        - ROWID-based chunking
        - nested PL/SQL helper functions
        - dynamic task creation/resume/drop

        Azure SQL does not support DBMS_PARALLEL_EXECUTE or Oracle wrapper logic.
        This version converts the business logic into a set-based cleanup/update
        procedure. If parallel/batch execution is required, orchestrate batching
        from the application layer, Azure Data Factory, or a SQL Agent replacement.
    */

    DECLARE @f_chain_name NVARCHAR(255);
    DECLARE @v_task_name  NVARCHAR(200);

    SELECT @f_chain_name = UPPER(chain_name)
    FROM eps_sec_chain
    WHERE chain_nhin_id = @p_chain_id;

    IF @f_chain_name IS NULL
    BEGIN
        THROW 50001, 'Chain name not found for the supplied chain id.', 1;
    END

    SET @v_task_name = @f_chain_name + N'_TP_LINK_CLEANUP_' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 120), N':', N'_');

    ;WITH ranked_rows AS
    (
        SELECT
            tpl.chain_id,
            tpl.id,
            ROW_NUMBER() OVER
            (
                PARTITION BY tpl.id_patient
                ORDER BY tpl.last_updated DESC
            ) AS rn
        FROM tp_link AS tpl
        WHERE tpl.chain_id = @p_chain_id
          AND tpl.carrier_id = 'CASH'
          AND ISNULL(tpl.deleted, 'N') <> 'Y'
    )
    UPDATE tpl
        SET deleted = 'Y'
    FROM tp_link AS tpl
    INNER JOIN ranked_rows AS r
        ON r.chain_id = tpl.chain_id
       AND r.id = tpl.id
    WHERE r.rn <> 1;

    DELETE FROM tp_link
    WHERE chain_id = @p_chain_id
      AND carrier_id = 'CASH'
      AND deleted = 'Y';

    UPDATE tp_link
        SET level_of = 100
    WHERE chain_id = @p_chain_id
      AND carrier_id = 'CASH'
      AND ISNULL(deleted, 'N') = 'N'
      AND ISNULL(level_of, 0) <> 100;

    RETURN;
END;
GO