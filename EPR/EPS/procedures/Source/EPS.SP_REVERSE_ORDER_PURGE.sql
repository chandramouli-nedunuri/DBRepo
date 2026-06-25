
  CREATE OR REPLACE EDITIONABLE PROCEDURE "EPS"."SP_REVERSE_ORDER_PURGE" (tab_name varchar2)
as
sql_str varchar2(4000);
purge_keep_date date;
purge_run_status varchar2(4000);
err_code varchar2(100);
err_text varchar2(4000);
par_tab_cnt number;
run_seq number;
row_count number;
table_name varchar2(30);

begin

table_name := upper(tab_name);

select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, table_name, 'START PURGE', 'Starting Prescription Purge', NULL, NULL, sysdate);
commit;

purge_run_status := 'Starting Purge for table ' || table_name;
dbms_application_info.set_client_info (purge_run_status);

execute immediate 'alter session enable parallel dml';
execute immediate 'alter session set nls_date_format=''mm-dd-yyyy''';
execute immediate 'alter session set db_file_multiblock_read_count=64';

--Get the current day - 36 months date for purge
select to_char(add_months(sysdate, -36), 'mm-dd-yyyy') into purge_keep_date from dual;

if (purge_keep_date is null) then
	raise_application_error(-20001, 'Purge Keep Date can not be NULL');
end if;

select count(*) into par_tab_cnt from all_tables where table_name in ('RX_TX_OLD') and owner = 'EPS';

--Truncate the new table before dumping rows
IF (TABLE_NAME = 'TX_TP') THEN

	--Check if the table has already been purged
	select count(*) into row_count from all_tables where table_name in ('TX_TP_OLD') and owner = 'EPS';
	IF (row_count > 0 ) then
		raise_application_error (-20005, 'TX_TP has already been purged!');
	END IF;
	--Check if the parent table has already been purged
	IF (par_tab_cnt = 0 ) then
		raise_application_error (-20005, 'Parent table (RX_TX) has not been purged yet!');
	END IF;
	--Truncate the new table
	execute immediate 'truncate table tx_tp_n';

ELSIF (TABLE_NAME = 'RX_TX_DIAGNOSIS_CODES') THEN

	--Check if the table has already been purged
	select count(*) into row_count from all_tables where table_name in ('RX_TX_DIAGNOSIS_CODES_OLD') and owner = 'EPS';
	IF (row_count > 0 ) then
		raise_application_error (-20003, 'RX_TX_DIAGNOSIS_CODES has already been purged!');
	END IF;
	--Check if the parent table has already been purged
	IF (par_tab_cnt = 0 ) then
		raise_application_error (-20003, 'Parent table (RX_TX) has not been purged yet!');
	END IF;
	--Truncate the new table
	execute immediate 'truncate table RX_TX_DIAGNOSIS_CODES_N';

ELSIF (TABLE_NAME = 'TX_CRED') THEN

	--Check if the table has already been purged
	select count(*) into row_count from all_tables where table_name in ('TX_CRED_OLD') and owner = 'EPS';
	IF (row_count > 0 ) then
		raise_application_error (-20004, 'TX_CRED has already been purged!');
	END IF;
	--Check if the parent table has already been purged
	IF (par_tab_cnt = 0 ) then
		raise_application_error (-20004, 'Parent table (RX_TX) has not been purged yet!');
	END IF;
	--Truncate the new table
	execute immediate 'truncate table tx_cred_n';

ELSIF (TABLE_NAME = 'RX_TX') THEN

    --Check if the table has already been purged
    IF (par_tab_cnt > 0 ) then
	raise_application_error (-20007, 'RX_TX table has already been purged!');
    END IF;
    --Truncate the new table
    execute immediate 'truncate table rx_tx_n';

ELSIF (TABLE_NAME = 'PA_NUM') THEN

	--Check if the table has already been purged
	select count(*) into row_count from all_tables where table_name in ('PA_NUM_OLD') and owner = 'EPS';
	IF (row_count > 0 ) then
		raise_application_error (-20005, 'PA_NUM has already been purged!');
	END IF;
	--Check if the parent table has already been purged
	select count(*) into par_tab_cnt from all_tables where table_name in ('TX_TP_OLD') and owner = 'EPS';
	IF (par_tab_cnt = 0 ) then
		raise_application_error (-20005, 'Parent table (TX_TP) has not been purged yet!');
	END IF;
	--Truncate the new table
        execute immediate 'truncate table pa_num_n';

ELSIF (TABLE_NAME is NULL) THEN
	raise_application_error (-20006, 'Table Name must be passed as a parameter');
ELSE
	raise_application_error (-20007, 'Table ' || table_name || ' is not a candidate of prescription purge');
END IF;


for rec in (select PARTITION_NAME from all_tab_partitions where table_owner = 'EPS' and table_name = 'RX_TX' order by partition_position) loop

IF (table_name = 'RX_TX') THEN

/*
REM This is the actual SQL used below in dynamic SQL to purge RX_TX

--Insert /*+ APPEND PARALLEL(32) / into RX_TX_N
(
select r.*
from rx_tx r
where
	(
	case
		when r.filled is null and r.written is null then r.last_updated
		when r.filled is null and r.written is not null then r.written
		when r.filled is not null and r.written is null then r.filled
		when r.filled is not null and r.written is not null then greatest(r.filled, r.written)
	end >= purge_keep_date
	)
	OR
	(
	  r.rx_status = 'I' and r.why_deactivated is null
	)
);
*/


sql_str := 'Insert /*+ APPEND PARALLEL(32) */ into RX_TX_N (select r.* from rx_tx partition(' || rec.partition_name || ') r where (case when r.filled is null and r.written is null then r.last_updated when r.filled is null and r.written is not null then r.written when r.filled is not null and r.written is null then r.filled when r.filled is not null and r.written is not null then greatest(r.filled, r.written) end >= ''' || purge_keep_date || ''') OR (r.rx_status = ''I'' and r.why_deactivated is null))';

select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, 'RX_TX_N', rec.partition_name, 'Populating table RX_TX_N partition ' || rec.partition_name || ' for date: ' || purge_keep_date, 'In Progress', sql_str, sysdate);

commit;

execute immediate sql_str;
row_count := sql%rowcount;

commit;

update purge_ledger set action_status = 'Completed', end_date = sysdate, rows_affected = row_count, sql_text = sql_str where id = run_seq;

commit;

ELSIF (table_name = 'RX_TX_DIAGNOSIS_CODES') then

/*
REM This is the actual SQL used below in dynamic SQL to purge RX_TX_DIAGNOSIS_CODES

--insert /*+ APPEND PARALLEL(32) / into RX_TX_DIAGNOSIS_CODES_N
select p.* from RX_TX_DIAGNOSIS_CODES partition(<partition_name>) p, rx_tx partition(<partition_name>) t
where
p.id_rx_tx = t.id
and p.chain_id = t.chain_id;
*/

select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, 'RX_TX_DIAGNOSIS_CODES_N', rec.partition_name, 'Populating RX_TX_DIAGNOSIS_CODES_N table for partition ' || rec.partition_name, 'In Progress', sql_str, sysdate);

commit;

sql_str := 'insert /*+ APPEND PARALLEL(32) */ into RX_TX_DIAGNOSIS_CODES_N (select p.* from RX_TX_DIAGNOSIS_CODES partition(' || rec.partition_name || ') p, rx_tx partition (' || rec.partition_name || ') t where p.id_rx_tx = t.id and p.chain_id = t.chain_id)';

execute immediate sql_str;
row_count := sql%rowcount;

commit;

update purge_ledger set action_status = 'Completed', end_date = sysdate, rows_affected = row_count where id = run_seq;

commit;

ELSIF (table_name = 'TX_CRED') then

/*
REM This is the actual SQL used below in dynamic SQL to purge TX_CRED

--insert /*+ APPEND PARALLEL(32) / into TX_CRED_N
select p.* from TX_CRED partition(<partition_name>) p, rx_tx partition(<partition_name>) t
where
p.id_rx_tx = t.id
and p.chain_id = t.chain_id;
*/

select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, 'TX_CRED_N', rec.partition_name, 'Populating TX_CRED_N table for partition ' || rec.partition_name, 'In Progress', sql_str, sysdate);

commit;

sql_str := 'insert /*+ APPEND PARALLEL(32) */ into TX_CRED_N (select p.* from TX_CRED partition(' || rec.partition_name || ') p, rx_tx partition (' || rec.partition_name || ') t where p.id_rx_tx = t.id and p.chain_id = t.chain_id)';

execute immediate sql_str;
row_count := sql%rowcount;

commit;

update purge_ledger set action_status = 'Completed', end_date = sysdate, rows_affected = row_count where id = run_seq;

commit;

ELSIF (table_name = 'TX_TP') THEN

/*
REM This is the actual SQL used below in dynamic SQL to purge TX_CRED

--insert /*+ APPEND PARALLEL(32) / into TX_TP_N
select p.* from TX_TP partition(<partition_name>) p, rx_tx partition(<partition_name>) t
where
p.id_rx_tx = t.id
and p.chain_id = t.chain_id;
*/

sql_str := 'insert /*+ APPEND PARALLEL(32) */ into TX_TP_N (select /*+ FULL(t) */ p.* from TX_TP partition(' || rec.partition_name || ') p, rx_tx partition (' || rec.partition_name || ') t where p.id_rx_tx = t.id and p.chain_id = t.chain_id)';

select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, 'TX_TP_N', rec.partition_name, 'Populating TX_TP_N table for partition ' || rec.partition_name, 'In Progress', sql_str, sysdate);

commit;

execute immediate sql_str;
row_count := sql%rowcount;

commit;

update purge_ledger set action_status = 'Completed', end_date = sysdate, rows_affected = row_count where id = run_seq;

commit;


ELSIF (table_name = 'PA_NUM') THEN

/*
REM This is the actual SQL used below in dynamic SQL to purge PA_NUM

--insert /*+ APPEND PARALLEL(32) / into pa_num_n
select p.* from pa_num partition(<partition_name>) p, tx_tp partition (<partition_name>) t
where
p.id_tx_tp = t.id
and p.chain_id = t.chain_id;
*/

select purge_seq.nextval into run_seq from dual;

sql_str := 'insert /*+ APPEND PARALLEL(32) */ into pa_num_n (select /*+ FULL(p) */ p.* from pa_num partition(' || rec.partition_name || ') p, tx_tp partition (' || rec.partition_name || ') t where p.id_tx_tp = t.id and p.chain_id = t.chain_id)';

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, 'PA_NUM_N', rec.partition_name, 'Populating PA_NUM_N table for partition ' || rec.partition_name, 'In Progress', sql_str, sysdate);

commit;


execute immediate sql_str;
row_count := sql%rowcount;

commit;

update purge_ledger set action_status = 'Completed', end_date = sysdate, rows_affected = row_count where id = run_seq;

commit;

END IF;


END LOOP;


select purge_seq.nextval into run_seq from dual;

insert into purge_ledger (id, table_name, subobject_name, action_detail, action_status, sql_text, start_date) values (run_seq, table_name, 'END PURGE', 'Finished Prescription Purge', NULL, NULL, sysdate);
commit;


EXCEPTION

when others then

err_code := sqlcode;
err_text := sqlerrm;

update purge_ledger set action_status = 'Failed', end_date = sysdate, rows_affected = 0, sql_text = sql_str, error_text = err_code || ' ==> ' || err_text where id = run_seq;

commit;
RAISE;

end sp_reverse_order_purge;