
  CREATE OR REPLACE EDITIONABLE PROCEDURE "EPS"."STOPJOB" 
as
begin
dbms_parallel_execute.stop_task('EPR-PURGE');
dbms_parallel_execute.DROP_task('EPR-PURGE');
END;