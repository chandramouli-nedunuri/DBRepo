CREATE OR ALTER PROCEDURE EPS.SP_STOPTEST
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle DBMS_PARALLEL_EXECUTE.DROP_TASK('EPR-PURGE')
        has no direct Azure SQL equivalent.

        Azure SQL does not support DBMS_PARALLEL_EXECUTE, so this
        procedure is converted to a stub/no-op.
        If task cleanup is needed, handle it in the application or
        orchestration layer.
    */

    RETURN;
END;
GO