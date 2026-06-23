CREATE OR ALTER PROCEDURE EPS.RESUME_TASK
AS
BEGIN
    SET NOCOUNT ON;

    /*
        Oracle DBMS_PARALLEL_EXECUTE.RESUME_TASK('EPR-PURGE')
        has no direct Azure SQL equivalent.

        Azure SQL does not support DBMS_PARALLEL_EXECUTE.
        If task/resume behavior is required, implement it in the
        application/orchestration layer (for example Azure Data Factory,
        Logic Apps, a job runner, or custom application logic).
    */

    RETURN;
END;
GO