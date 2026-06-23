CREATE OR ALTER PROCEDURE EPS.SP_TEST
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle procedure uses DBMS_PARALLEL_EXECUTE to:
        - drop/create a task
        - create chunks by ROWID
        - run a dynamic delete in parallel

        Azure SQL does not support DBMS_PARALLEL_EXECUTE, DBMS_SQL.NATIVE,
        or Oracle ROWID-based chunking. This is converted to a stub.

        If you need the same purge behavior, implement batching outside SQL Server
        or rewrite the logic using a set-based DELETE with a numeric key.
    */

    -- Original Oracle logic:
    -- EXECUTE dynamic procedure against chunks of PURGE_RECORDS
    -- in parallel for RX_TX deletion.

    RETURN;
END;
GO