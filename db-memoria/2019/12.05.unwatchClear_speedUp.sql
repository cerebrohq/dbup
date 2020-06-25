--drop FUNCTION public."taskChildrenList"(_tid bigint, _list_deleted boolean)
CREATE OR REPLACE FUNCTION public."taskChildrenList"(_tid bigint, _list_deleted boolean)
    RETURNS  bigint[] LANGUAGE 'plpgsql'
    COST 100 STABLE STRICT SECURITY DEFINER
AS $_$
declare
	_task_url character varying;
	_prj_id bigint;
	usid integer = "get_usid"();	
begin	
	select prj_id, cc_url || "name" into _prj_id, _task_url  from tasks where uid = _tid;
	--raise notice '% %', _prj_id, _task_url;
	
	return array_agg(t.uid)
	FROM tasks as t
	WHERE
		t.prj_id = _prj_id
		AND t.cc_url like (_task_url || '/%')
		AND ($2 or t.del = 0)
	;
end
$_$;

CREATE OR REPLACE FUNCTION public."notifyClear"(_user_id integer, _tid_no_refs bigint[])
    RETURNS void LANGUAGE 'plpgsql' COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
begin
	--raise notice 'notifyClear % %', _user_id, array_length(_tid_no_refs, 1);
	
	if _user_id is null
	then		
		delete from unemailedtasks 
			where logid in (select uid from logs where logs.taskid = any(_tid_no_refs));
	elsif _tid_no_refs is null
	then		
		delete from unemailedtasks where userid = _user_id;
	else		
		delete from unemailedtasks where 
			userid = _user_id 
			and logid in (select uid from logs where logs.taskid = any(_tid_no_refs));
	end if;
end
$BODY$;

CREATE OR REPLACE FUNCTION public."unwatchResetDeep_a"(user_id integer, tid bigint[])
	RETURNS void LANGUAGE 'plpgsql' COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare 
	_tid 		bigint;
	_reset_tid	bigint[];
begin

	if(array_dims(tid) is not NULL)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_tid = "refResolve"(tid[i]);
			if _tid is not null then
				_reset_tid = array_append(coalesce("taskChildrenList"(_tid, false), array[]::bigint[]), _tid);
			end if;
		end loop;
	end if;

	raise notice 'unwatchResetDeep for usid:% and % tasks', user_id, array_length(_reset_tid, 1);
	
	perform "notifyClear"(user_id, _reset_tid);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."unwatchResetDeep"(user_id integer, tid bigint)
    RETURNS void LANGUAGE 'sql' COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "unwatchResetDeep_a"(user_id, array[tid]::bigint[]);
$BODY$;

CREATE OR REPLACE FUNCTION public."unwatchClear"(_userid integer, _tid bigint)
    RETURNS void LANGUAGE 'sql' COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
	select "notifyClear"(_userid, array[_tid]);
$BODY$;

CREATE OR REPLACE FUNCTION public."unwatchClear"(in_tid bigint[])
    RETURNS void LANGUAGE 'sql' COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
	select "notifyClear"(get_usid(), in_tid);
$BODY$;

CREATE OR REPLACE FUNCTION public."unwatchClear"(tid bigint)
    RETURNS void LANGUAGE 'sql' COST 100 VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
	select "notifyClear"(get_usid(), array[tid]);
$BODY$;

CREATE OR REPLACE FUNCTION public._task_relink_tree_update(_parent bigint, _new_prj_id bigint)
    RETURNS void LANGUAGE 'plpgsql' COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_tid bigint;
begin	
	--perform "unwatchClear"(_parent); -- moved to taskRelinkMulti
	UPDATE tasks 
	SET 
		cc_url	= 	("queryTaskParentInfo"(false, lnk_front_parent, 0, '', null, null))._url 
		, cc_level	= (("getTaskLevel"(lnk_front_parent, null))."level")+1
		, prj_id	= _new_prj_id
	WHERE 
		uid=_parent;

	perform _task_relink_tree_update(uid, _new_prj_id) from tasks where lnk_front_parent=_parent;	
end
$BODY$;

-- DROP FUNCTION public."taskRelinkMulti"(bigint[], bigint, integer);
CREATE OR REPLACE FUNCTION public."taskRelinkMulti"(tid bigint[], _new_parent bigint, _flags integer) 
    RETURNS void LANGUAGE 'plpgsql' COST 100 VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
-- _flags:
--      b0 : relink and make reference in old position
--
declare
	_old_parent_touch int = 2 + 4 + 16 + 262144;
	_task_touch int = 4;
	_touch_tid bigint[] = tid;
	_seq_no double precision;
	_old_pid bigint;
begin
	if (array_dims(tid) is not NULL)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_touch_tid = array_append(tid, 
				(case when "refIs"(tid[i]) 
					then "refParent"(tid[i])
					else "taskParent"(tid[i])
				end));
		end loop;

		perform "unwatchResetDeep_a"(null, tid);

		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			if (_flags & 1) != 0
			then
				if "refIs"(tid[i])
				then
					raise exception '%', msg(115);
				end if;

				select seq_order, lnk_front_parent into _seq_no, _old_pid from tasks where uid=tid[i];
				
				perform "refNewDo"(_old_pid, tid[i], _seq_no);
			end if;
			
			perform "taskRelinkDo"(tid[i], _new_parent, _old_parent_touch, _task_touch, _flags);
		end loop;

		perform "ggSolveMulti"(_touch_tid, 0);
		perform "touchTask"(_new_parent, _old_parent_touch, null);
	end if;
end;
$BODY$;





-- select array_append(coalesce(null, array[]::bigint[]), 20::bigint);

--select * from tasks where uid < 10000
--select * from projects
-- select count(1), prj_id from tasks group by prj_id;
-- select array_length("taskChildrenList"(416500, true), 1);
--select "unwatchClear"(null, 29275357)

--select prj_id, cc_url || "name"  from tasks where uid = 416500;

/*
select name, cc_url
	FROM tasks as t
	WHERE
		t.prj_id = 416499
		AND t.cc_url like ('/Cerebro Demo project' || '/%')
	;
*/

/*
select "unwatchResetDeep"(null, 416500);
select "unwatchResetDeep"(3, null);
select "unwatchResetDeep"(3, 416500);

select "unwatchClear"(3, 416500);
select "unwatchClear"(array[416500]::bigint[]);
select "unwatchClear"(416500);
*/
