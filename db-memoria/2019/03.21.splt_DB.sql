
-- DROP FUNCTION public."taskPost_json"(bigint, json);
CREATE OR REPLACE FUNCTION public."taskPost_json"(
	_parent_tid bigint,
	_args json)
    RETURNS SETOF json 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
declare
	_tid			bigint;
	_langid			int = (select uid from langs where code2::text = _args->>'lang');
	_actid			bigint = (_args->>'activity')::bigint;
	_taskName 		text = _args->>'taskName';
	
	_start_ts		bigint = (_args->>'startDate')::bigint;
	_stop_ts		bigint = (_args->>'stopDate')::bigint;
	_watch			boolean = (_args->>'watch')::boolean;
	_priority		smallint = (_args->>'priority')::smallint;
	_progress		smallint = (_args->>'progress')::smallint;
	_plannedHours	numeric = (_args->>'plannedHours')::numeric;
	
	_userList	int[] = (
		select array_agg(replace(u::text, '"', '')::int) 
			from json_array_elements(_args->'userList') as u
		);

	_gg_time		double precision;
	_tida			bigint[];
	_usid			int = "get_usid"();
	_eid			bigint;
	
begin
	--perform pg_sleep(10);
	--raise exception 'Qqq %, % %', _progress, _plannedHours, _watch;

	if not "taskCheckNameUnique"(_parent_tid, _taskName) then
		raise exception '%', msg(120);
	end if;

	_tid = "taskNew_00"(_parent_tid, _taskName, _actid, true, _langid);
	_tida = array[_tid];

	if _start_ts is not null then
		_gg_time = "ggJSTimeToFloat"(_start_ts);
		perform "ggSetTaskOffset_a"(_tida, _gg_time);
	end if;

	if _stop_ts is not null then
		_gg_time = "ggJSTimeToFloat"(_stop_ts);
		--perform "ggSetTaskDuration_a"(_tida, _gg_time);
		perform "ggSetTaskStop"(_tid, _gg_time);
	end if;

	if _watch = false then 
		perform "userSetTaskInterrest"(_tid, _usid, 0);
	end if;

	if _priority is not null then 
		 perform "_task_set_priority"(_tid, _priority);
	end if;

	if _progress is not null then 
		perform "updateTaskProgress_00"(_tid, _progress);
	end if;
	
	if _plannedHours is not null then 
		 perform "taskSetPlanned_a"(array[_tid]::bigint[], _plannedHours);
	end if;

	if _userList is not null then
		perform "userAssignmentTask_a"(_tida, _userList, 1);
	end if;

	_eid = "eventNew_00"(
		null
		, _tid
		, "eventTextPlainToHtml"(_args->>'taskDesc')
		, 0 -- defa
		, null --pid bigint,
		, null --work_time integer,
		, _langid
	);

	perform "eventSetFlags"(_eid, 1, 1);

	return query
	select * from "taskQuery_json"(array[_tid]::bigint[]);
end
$BODY$;
