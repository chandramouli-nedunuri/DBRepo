CREATE OR ALTER PROCEDURE EPS.STOPJOB
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle DBMS_PARALLEL_EXECUTE.STOP_TASK and DROP_TASK
        have no direct Azure SQL equivalent.

        Azure SQL does not support DBMS_PARALLEL_EXECUTE, so this
        procedure is converted to a stub/no-op.
        Task stop/drop cleanup must be handled outside the database
        by the application or orchestration layer.
    */

    RETURN;
END;
GO