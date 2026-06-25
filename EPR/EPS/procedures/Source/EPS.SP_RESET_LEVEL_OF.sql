
  CREATE OR REPLACE EDITIONABLE PROCEDURE "EPS"."SP_RESET_LEVEL_OF" 
(
	p_chain_id		in		number,
	p_job_class	in		varchar2,
	p_chunk_size	in		number			default 2000,
	p_parallel_cnt	in		number			default 8
)
as
	v_task_name	varchar2(60)	:= null;
	v_nbr_parallel	number		:= p_parallel_cnt; -- This must be less than job_queue_processes parameter
	v_chunk_sql	varchar2(4000)	:= null;
	v_task_sql		varchar2(4000)	:= null;
	v_retries		number		:= 0;
	v_status 		number		:= null;
	v_job_class	varchar2(60)	:= upper(p_job_class);
	v_sqlcode		number		:= null;
	v_sqlerrm		varchar2(4000)	:= null;
	f_chain_name	varchar2(255)	:= null;
	e_Abort	exception;
	e_dup_task	exception;
	pragma exception_init( e_dup_task, -29497 );
	function fn_getChunkSql
	return varchar2
	is
		v_Sql			varchar2(4000)		:= null;
	begin
		v_Sql := 'with temp_ids(v_id) ' ||
			'as ' ||
			'( ' ||
		'select  min(id_patient) as min_id ' ||
			'from tp_link ' ||
			'where chain_id=' || p_chain_id || ' ' ||
		'union all ' ||
		'select  v_id + ' || p_chunk_size || ' ' ||
		'from temp_ids ' ||
		'where v_id < (select max(id_patient) from tp_link where chain_id=' || p_chain_id || ') ' ||
			'), ' ||
			'chunks as ' ||
			'( ' ||
			'select v_id as start_id, ' ||
				'lead(v_id,1,0) over (order by v_id) as end_id, ' ||
				'lag(v_id,1,0) over (order by v_id) as prevr ' ||
			'from temp_ids ' ||
			') ' ||
			'select start_id, ' ||
				'decode( end_id, 0, start_id + ' || p_chunk_size || ', end_id-1 ) as end_id ' ||
			'from chunks ';
		return v_Sql;
	end fn_getChunkSql;
	function fn_getTaskSql
	return varchar2
	is
		v_Sql			varchar2(4000)		:= null;
	begin
		v_Sql := 'declare ' ||
				'begin ' ||
					'update tp_link ' ||
					'set deleted = ''Y'' ' ||
					'where (chain_id, id) in ' ||
						'( ' ||
						'select chain_id, id ' ||
						'from ' ||
							'( ' ||
							'select chain_id, id, ' ||
								'row_number() over (partition by tpl.id_patient order by tpl.last_updated desc) as rank ' ||
							'from tp_link tpl ' ||
							'where chain_id = ' || p_chain_id || ' ' ||
								'and id_patient between :start_id and :end_id ' ||
								'and carrier_id = ''CASH'' ' ||
								'and nvl(deleted,''N'') != ''Y'' ' ||
							') ' ||
						'where rank != 1 ' ||
						'); ' ||
					'delete from tp_link ' ||
					'where chain_id = ' || p_chain_id || ' ' ||
						'and id_patient between :start_id and :end_id ' ||
						'and carrier_id = ''CASH'' ' ||
						'and deleted = ''Y''; ' ||
					'update tp_link ' ||
					'set level_of = 100 ' ||
					'where chain_id = ' || p_chain_id || ' ' ||
						'and id_patient between :start_id and :end_id ' ||
						'and carrier_id = ''CASH'' ' ||
						'and nvl(deleted,''N'') = ''N'' ' ||
						'and nvl(level_of,0) != 100; ' ||
				'exception ' ||
					'when others then ' ||
						'rollback; ' ||
						'raise; ' ||
				'end; ';
		return v_Sql;
	end fn_getTaskSql;
begin
	v_Chunk_sql := fn_getChunkSql;
	v_Task_sql := fn_getTaskSql;
	-- Get the chain name for the passed in chain_id
	select upper(chain_name)
	into f_chain_name
	from eps_sec_chain
	where chain_nhin_id = p_chain_id;
	-- Create a task
	v_task_name := f_chain_name || '_TP_LINK_CLEANUP_' || to_char(sysdate,'ddMONyyyy_hh24_mi');
	begin
		dbms_parallel_execute.create_task( v_task_name );
	exception
		when e_dup_task then
			dbms_parallel_execute.drop_task( v_task_name );
			dbms_parallel_execute.create_task( v_task_name );
		when others then
			v_sqlcode := sqlcode;
			v_sqlerrm := sqlerrm;
			dbms_output.put_line( 'Other error creating task ' || v_task_name );
			raise_application_error( -20001, 'Other error, ' || v_sqlcode || ' - ' || v_sqlerrm || ', creating task ' || v_task_name );
	end;
	-- Chunk the table based on the sql
	begin
		dbms_parallel_execute.create_chunks_by_sql(
			task_name 	=> v_task_name,
			sql_stmt  	=> v_chunk_sql,
			by_rowid  	=> FALSE );
	exception
		when others then
			v_sqlcode := sqlcode;
			v_sqlerrm := sqlerrm;
			dbms_output.put_line( 'Other error chunking by sql with: ' || v_chunk_sql );
			raise_application_error( -20002, 'Other error, ' || v_sqlcode || ' - ' || v_sqlerrm || ', chunking by sql with: ' || v_chunk_sql );
	end;
	
	v_status := dbms_parallel_execute.task_status( v_task_name );
	if( v_status = dbms_parallel_execute.no_chunks ) then
		raise_application_error( -20003, 'No chunks generated with: ' || v_chunk_sql );
	else
		-- Execute the DML in parallel
		begin
			dbms_parallel_execute.run_task(
				task_name 		=> v_task_name,
				sql_stmt 		=> v_task_sql,
				language_flag 	=> DBMS_SQL.NATIVE,
				parallel_level 	=> v_nbr_parallel,
				job_class 		=> v_job_class );
		exception
			when others then
				v_sqlcode := sqlcode;
				v_sqlerrm := sqlerrm;
				dbms_output.put_line( 'Other error executing task with: ' || v_task_sql );
				raise_application_error( -20004, 'Other error, ' || v_sqlcode || ' - ' || v_sqlerrm || ', executing task with: ' || v_task_sql );
		end;
		-- If there is an error, resume task for at most two times
		v_status := dbms_parallel_execute.task_status( v_task_name );
	end if;
	while ( v_retries < 3 and v_status != dbms_parallel_execute.finished and v_status != dbms_parallel_execute.no_chunks ) loop
		if( v_status in ( dbms_parallel_execute.chunked, dbms_parallel_execute.processing, dbms_parallel_execute.processed ) ) then
			null;
		elsif( v_status = dbms_parallel_execute.chunking_failed ) then
			dbms_output.put_line( 'Chunking failed for task ' || v_task_name );
			dbms_output.put_line( 'Chunking Sql: ' || v_chunk_sql );
			raise_application_error( -20005, 'Chunking failed for task ' || v_task_name || ' and chunk sql: ' || v_chunk_sql );
		else
			v_retries := v_retries + 1;
			dbms_output.put_line( 'Resume the task ' || v_task_name || ' with a status of ' || v_status );
			dbms_parallel_execute.resume_task( v_task_name );
		end if;
	
		dbms_lock.sleep(30);
		v_status := dbms_parallel_execute.task_status( v_task_name );
	end loop;
	if( v_status = dbms_parallel_execute.finished ) then
		dbms_parallel_execute.drop_task( v_task_name );
	else
		raise_application_error( -20006, 'Task finished with other than finished status.  Status was ' || v_status );
	end if;
end sp_reset_level_of;
