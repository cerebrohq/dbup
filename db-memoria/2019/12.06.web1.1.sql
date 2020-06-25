

-- FUNCTION: public."statusXPM"(bigint)
CREATE OR REPLACE FUNCTION public."statusHashOrXPM"(_uid bigint)
    RETURNS text LANGUAGE 'sql' COST 100 
		STABLE SECURITY DEFINER 
AS $BODY$
	select 
		coalesce(icon_hash, icon_xpm)
		from status
		where 
			uid = _uid 
			-- and "isUserInUniverse"("getUserID_bySession"(), unid) -- skip AUTH for GET req
			and (flags & 1)=0 -- show deleted?
$BODY$;

CREATE OR REPLACE FUNCTION "statusQuery_json"(_uid bigint, _flags integer) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
declare
	_r		status;
begin
	select * into _r from status where uid = _uid;

	if _r.uid is not null
	then
		return row_to_json(ss.*)
		from (select
			_r.uid::text
			, _r.name
			, _r.order_no
			, _r.color
			, _r.mtm as mtm_at
			, (_r.flags | (case when coalesce(_r.icon_xpm, _r.icon_hash, '') != '' then (1<<16) else 0 end)) as flags
			, _r.unid::text
		) as ss;
	else
		return row_to_json(ss.*)
		from (select
			'0'::text as uid
			, null as name
			, 0 as order_no
			, null as color
			, 0 as flags
			, null as mtm_at
			, _uid::text as unid
		) as ss;
	end if;
end
$$;

CREATE OR REPLACE FUNCTION public."navigationMarkTask_json"(_uid bigint, _unseen_limit integer, _flags integer)
    RETURNS json LANGUAGE 'plpgsql' COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
-- _flags
-- b24..b?? => VERSION

Declare
	_user_id	int = "get_usid"();
	_histo		text;
	_ret		record;
	_version int = (_flags >> 24);

begin
	CREATE TEMP TABLE tt_histo
	(
	   mtm_at timestamp with time zone NOT NULL,
	   uid bigint NOT NULL, 
	   CONSTRAINT pk_tt_dup_tasks PRIMARY KEY (uid)
	) ON COMMIT DROP;
	CREATE INDEX ix_tt_histo_mtm ON tt_histo(mtm_at);

	insert into tt_histo(mtm_at, uid)
		select (histo->>'mtm_at')::timestamp with time zone, (histo->>'uid')::bigint
			from (
				select json_array_elements(val::json) as histo
					from attrib_user where key = 301 and usid = _user_id
			) as histo;

	if exists (select 1 from tt_histo where uid = _uid)
	then
		update tt_histo set mtm_at = now() where uid = _uid;
	else
		insert into tt_histo(mtm_at, uid) values(now(), _uid);
	end if;

	_histo = (select json_agg(row_to_json(r.*)) from
		(select * from tt_histo order by mtm_at desc limit 25) as r
	);

	perform "attributeUserSet"("get_usid"(), 301, _histo);

	select
		-- (select array_agg(h) from  "navigationHistory_json"(_flags) as h) as history  -- history is LARGE! Refresh it on every click is not good
		(select array_agg(s) from "notifyEventSeenMarkTaskId"(_uid, _unseen_limit, _flags) as s) as "notifySeenArray"
	into _ret;

	return row_to_json(_ret);
end
$BODY$;


-- FUNCTION: public."taskQueryMessage_jsonb"(integer, tasks, events, integer)
-- DROP FUNCTION public."taskQueryMessage_jsonb"(integer, tasks, events, integer);
CREATE OR REPLACE FUNCTION public."taskQueryMessage_jsonb"(_user_id integer, t tasks, e events, _flags integer)
    RETURNS jsonb LANGUAGE 'plpgsql' COST 50
    STABLE SECURITY DEFINER 
AS $BODY$
declare
-- _flags: full description see taskQuery
--    b7 - skip event text
--    b8 - REMOVED - fill UNWATCH status
--    b9 - fill File array

	_perm 	bigint		= "perm"(_user_id, t.uid, 0);
	_allow_8 boolean	= "perm_Task"(_perm, _user_id, t.uid, 8);
	_r		record;
begin
	SELECT into _r
		e.mtm as mtm_at
		, e.uid::text
		, e.parentEventID::text as parentid
		, e.taskid::text
		, e.tag
		, "userNameDisplay"(_user_id, e.creatoruserid) as creator_name
		, (select avatar_hash from users where uid = e.creatoruserid) as creator_hash
		, (select coalesce(ldap_email, email) from users where uid = e.creatoruserid) as creator_email
		, e.creationTime as created_at
		, (case when not (_user_id = e.creatoruserid or _user_id = e.muid or _allow_8 ) then null::integer else e.workTime end)::int as workTime
		, (case when (_flags & (1<<7)) = 0 then e.text else null::text end) as text_html_plain
		, (case when not (_user_id = e.creatoruserid or _user_id = e.muid or _allow_8)
			then null
			else (case when (e.tag=2 or e.tag=5) and e.workTime is not null
				then "getEventApprovedTime"(e.uid, "getProjectApproveMode_byTaskID"(e.taskID))
				else 0
				end)
			end)::int as approved_time
		, (e.flags 
			| (case when e.creatoruserid = _user_id then 4 else 0 end) 
			| (case when "perm_IsEventEditable"(e.uid) then 8 else 0 end) 
			| (case when e.del!=0 then 16 else 0 end)) 
			as flags
		, "userNameDisplay"(_user_id, e.muid) as modified_name
		, e.xmtm as modifyTime_at
		, e.creatoruserid::text as creator_uid
		, e.muid::text as modified_uid
		, e.statusid::text
		-- , e.langid
		, "htAggregateEvent_ex"(e.uid, 2) as htags
		, e.rating
		--, null::json[] as files

		, null::text as log_id
		, null::text as uml_id
		, null::boolean unsent
	;

	if (_flags & (1<<9)) != 0
	then
		--_r.files = (
		--	select array_agg("taskQueryFile_jsonb"(_user_id, t, e, a, _flags))
		--		from attachments as a 
		--		where eventID = e.uid and del=0
		--);			
	end if;

	return to_jsonb(_r);
end
$BODY$;

GRANT EXECUTE ON FUNCTION public."taskQueryMessage_jsonb"(integer, tasks, events, integer) TO sa;
REVOKE ALL ON FUNCTION public."taskQueryMessage_jsonb"(integer, tasks, events, integer) FROM PUBLIC;

-- FUNCTION: public."taskQueryFile_jsonb"(integer, tasks, events, attachments, integer)
-- DROP FUNCTION public."taskQueryFile_jsonb"(integer, tasks, events, attachments, integer);
CREATE OR REPLACE FUNCTION public."taskQueryFile_jsonb"(_user_id integer, t tasks, e events, a attachments, _flags integer)
    RETURNS jsonb LANGUAGE 'sql' COST 50 
		STABLE SECURITY DEFINER 
AS $BODY$
-- _flags: full description see taskQuery
--	b20 - fill LastReview
--	b21 - fill perm_IsEventEditable flag
--	b22 - fill thumbHash

	select to_jsonb(r.*)
		from (select 
			a.uid::text
			, t.uid::text as taskid
			, t.prj_id::text
			, a.eventid::text
			, a.groupid::text

			, a.tag
			, a.creationtime as created_at
			, e.creatoruserid::text as creator_uid -- FAKE!
			, a.hash
			, a.originalfilename as filename
			, a.filesize
			, a.flags 
				| (case when "perm_IsEventEditable"(e.uid) then (1<<17) else 0 end)
				as flags 

			, "htAggregateAttachment_ex"(a.uid, 2) as htags
			, a.description as file_comment

			, (case when (_flags & (1<<20)) != 0 and a.tag = 0 
				then (select hash from attachments as aa 
						where a.eventid = aa.eventid and a.groupid = aa.groupid 
						and aa.tag = 6
						and aa.del = 0
						limit 1) -- review
				else null
			end)::text as hash_review

			, (case when (_flags & (1<<22)) != 0 and a.tag = 0 
				then "taskQueryFileThumb"(a.eventid, a.groupid)
				else null
			end)::text as "thumbHash"
		) as r;
$BODY$;

GRANT EXECUTE ON FUNCTION public."taskQueryFile_jsonb"(integer, tasks, events, attachments, integer) TO sa;
REVOKE ALL ON FUNCTION public."taskQueryFile_jsonb"(integer, tasks, events, attachments, integer) FROM PUBLIC;

-- FUNCTION: public."taskQuery_jsonb"(bigint[], integer)
-- DROP FUNCTION public."taskQuery_jsonb"(bigint[], integer);
CREATE OR REPLACE FUNCTION public."taskQuery_jsonb"(task_uid bigint[], _flags integer)
    RETURNS SETOF jsonb LANGUAGE 'plpgsql' COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
DECLARE
--	WAS b0 - skip events & files
--	WAS b1 - skip workers
--	WAS b2 - skip subscribers

-- flags:
-- listProjects & taskListTree
--  b0	show deleted
--  b3	show nav links

-- taskQueryMessage:
--  b7 - skip event text
--  b8 - 
--  b9 - fill File array

-- taskQueryNotify && taskQuery
--	b10 - skip events & files (ShortList)
--	b11 - skip workers
--	b12 - skip subscribers (ShortList)
--  b13 - skip status object + (skip uploadSites for listProjects)
--  b14 - include notifyPerms
--  b15 - extended data "notifyData_json" -> taskLog
--  b16 - mobile-short data (TaskLists)

-- taskQueryFile:
--	b20 - fill Review
--	b21 - fill perm_IsEventEditable flag
--	b22 - fill thumbHash

-- GENERIC
-- b24..b?? => VERSION
--   v. 01:  Skip User details (UserObj, _hash, _name, _email), omit ActivityName, omit Creator & Modifier user

	_user_id 	integer = "get_usid"();
	_allow_12	boolean;
	_allow_30	boolean;

	_res		record;
	_rec		record;
	_r			jsonb;
	_uids		jsonb[];
	_q			jsonb;
	_visible_events bigint[];
	_disable_perms boolean = false;
	
	_version int = (_flags >> 24);
begin
	--perform pg_sleep(2);

	_uids = _uids || (select array_agg(to_jsonb(t.*)) from 
		(select uid, mtm, parentid as pid, taskid as tid, "name", seq_order, 'cc_url' as cc_url, "perm"(_user_id, taskid, 0) as perm
			from nav_links where uid = any(task_uid) and (_disable_perms or ("perm"(_user_id, taskid, 0) & 1) != 0)
		) as t);

	_uids = _uids || (select array_agg(to_jsonb(t.*)) from 
		(select uid, mtm, lnk_front_parent as pid, uid as tid, "name", seq_order, cc_url as cc_url, "perm"(_user_id, uid, 0) as perm
			from tasks where uid = any(task_uid) and (_disable_perms or ("perm"(_user_id, uid, 0) & 1) != 0)
		) as t);
		
	--raise notice 'rr %', _uids;
	--for _q in (select q from unnest(_uids) as q)
	--loop 
	--	raise notice 'q %', _q->>'mtm';
	--end loop;

	for _res in 
		(select
			  (uids->>'uid')::text as uid 
			, (uids->>'tid')::text as task_id -- could be different for nav_links
			, (uids->>'mtm') as mtm_at
			, t.mtm as task_mtm_at
			
			, (uids->>'pid')::text as parent_uid
			, prj_id::text
			, coalesce(uids->>'name', t.name) as name
			, (uids->>'cc_url') as parent_path

			, prj.unid::text as unid
			, (uids->>'perm')::text as perm_bits
			, (uids->>'seq_order')::numeric as seq_order
 
			, status::text as human_status_id
			, cc_status::text as status_uid
			, cc_status_stat
		
			, t.creationTime::timestamp with time zone as created_at
			, t.xmtm as modifytime_at
		 	, t.priority::smallint 
			, t.cc_thumbnailes as thumb

			, t.activityid::text 
			, act.name  as activity 
			, act.color as activity_color

 			, "taskFlagsMobile"(t.uid, t, _user_id, _flags) as flags

		 	-- EXTENDED --
			, (case when "isTaskInterrsted"(_user_id, t.uid) then 1 else 0 end) as interest

		 	, cp_cc_reserve as planned
			, (cp_cc_declared_total/60.0)::real as declared
			, (cp_cc_approved_total/60.0)::real as approved
			, (resource_declared_total/60.0)::real as resource_declared
			, (resource_approved_total/60.0)::real as resource_approved

			, costs as self_costs
			, cc_pays as self_pays
			, cc_costs as costs
			, cc_pays_total as pays
			
		 	, t.creatoruserid::text as creator_uid
		 	, t.muid::text as modified_uid
		 	, (case when _version=0 then "userNameDisplay"(_user_id, t.creatoruserid) else null end) as creator_name
			, (case when _version=0 then (select avatar_hash from users where uid = t.creatoruserid) else null end) as creator_hash

			, "ggFloatToTimeStamp"("ggGlobalOffset"(t.uid)) as tg_cc_start_at
			, "ggFloatToTimeStamp"(coalesce(tg_stop, "ggGlobalOffset"(t.uid) + tg_cc_dur)) as tg_cc_stop_at
			, tg_cc_dur as tg_cc_duration
			, "ggFloatToTimeStamp"(tg_offset) as human_start_at
			, "ggFloatToTimeStamp"(tg_stop) as human_stop_at
			
			, "htAggregateTask_ex"(t.uid, 2) as htags
		 
		 	, (select "ellipsizeMsg"(e.text, 250) from events as e where e.taskid = t.uid and e.del = 0 and coalesce(e.text, '')!=''  order by e.uid asc  limit 1) as first_message_html_plain
		 	, (select "ellipsizeMsg"(e.text, 250) from events as e where e.taskid = t.uid and e.del = 0 and coalesce(e.text, '')!='' order by e.uid desc limit 1) as last_message_html_plain

		from
		 	--tt_uids as uids 
		 	unnest(_uids) as uids
		 		join tasks as t on t.uid = (uids->>'tid')::bigint
		 		join projects as prj on t.prj_id = prj.uid
		 		join activitytypes as act on act.uid = t.activityid 
		 	--order by uids.uid
		)
	loop
		_r = to_jsonb(_res);
		
		if (_flags & (1<<16)) != 0  -- Mobile-short ShortData
		then
			_r = _r -
				'{ creator_name, creator_hash
				, first_message, last_message
				, planned, declared, approved, resource_declared, resource_approved
				, self_costs, self_pays, costs, pays
				, tg_cc_start_at, tg_cc_stop_at, tg_cc_duration, human_start_at, human_stop_at
				, htags }'::text[];
			
			return next _r;			
		else
			_allow_12 = "perm_Task"(_res.perm_bits::bigint, _user_id, _res.task_id::bigint, 12);
			_allow_30 = "perm_Task"(_res.perm_bits::bigint, _user_id, _res.task_id::bigint, 30);

			if not _allow_12 then
				_r = _r - '{ planned, declared, approved, resource_declared, resource_approved }'::text[];
			end if;

			if not _allow_30 then
				_r = _r - '{ self_costs, self_pays, costs, pays }'::text[];
			end if;
			
		 	-- SUPER EXTENDED --
			if (_flags & (1<<11)) = 0 --	b11 - skip workers
			then
				if _version = 0 -- OLD user style
				then 
					_q = (select jsonb_agg("taskQueryUser_json"(_user_id, users, _flags))
						from users_tasks 
							join users on users_tasks.userID = users.uid
						where 
							users_tasks.taskID = _res.task_id::bigint
							and (users_tasks.assigned_perc is not null) -- or interrest
							and users.del = 0
							and ("perm_IsUserVisible"(_user_id, users.uid, 1) > 0 or (ad_sid is not null))
					);

					_r = _r || jsonb_build_object('workers', _q);
				else
					_q = (select jsonb_agg(users_tasks.userid)
						from users_tasks
						where users_tasks.taskID = _res.task_id::bigint
							-- and do NOT test visibility for userid
					);

					_r = _r || jsonb_build_object('workers_usid', _q);
				end if;
			end if;

		 	if (_flags & (1<<12)) = 0 --	b12 - skip subscribers
			then
				if _version = 0 -- OLD user style
				then
					_q = (select jsonb_agg("taskQueryUser_json"(_user_id, users, _flags))
						from "interrestUsersTask"(_res.task_id::bigint) as iu 
							join users on iu = users.uid
					 );

					_r = _r || jsonb_build_object('subscribers', _q);
				else				
					_q = (select jsonb_agg(iu) from "interrestUsersTask"(_res.task_id::bigint) as iu);
					_r = _r || jsonb_build_object('subscribers_usid', _q);
				end if;
			end if;

			-- events
		 	if (_flags & (1<<10)) = 0 -- b10 - skip events & files
			then
				select into _rec
					jsonb_agg("taskQueryMessage_jsonb"(_user_id, t, e, _flags) ORDER BY e.uid DESC) as events
					, array_agg(e.uid) as visible_events
				
					from events as e 
						join tasks as t on t.uid = e.taskID
					WHERE
						e.taskid = _res.task_id::bigint						  	
						and e.del = 0
						and "perm_IsEventVisble"(_user_id, e.uid)
				;
				
				_r = _r || jsonb_build_object('events', coalesce(_rec.events, '[]'::jsonb));
			
				-- files
				_q = (
					select jsonb_agg("taskQueryFile_jsonb"(_user_id, t, e, a, _flags))
					from attachments as a 
					  	join events as e on a.eventID = e.uid 
					  	join tasks  as t on t.uid = e.taskID
					where
						e.taskID = _res.task_id::bigint
						and e.del = 0 and a.del = 0
						and e.uid = any(_rec.visible_events)  --and "perm_IsEventVisble"(_user_id, e.uid)
				);

				_r = _r || jsonb_build_object('files', coalesce(_q, '[]'::jsonb));
			end if;

			if (_flags & (1<<13)) = 0 --  b13 - skip status object
			then
				_q = "statusQuery_json"(_res.status_uid::bigint, _flags);
				_r = _r || jsonb_build_object('status', _q);
			end if;

			if (_flags & (1<<14)) != 0 --b14 - include notifyPerms
			then
				_q = "notifyPerms"(_user_id, _res.task_id::bigint, _res.unid::int);
				_r = _r || jsonb_build_object('notifyPerms', _q);
			end if;
		end if;
		
		if _version = 0
		then
			return next _r;
		else
			return next jsonb_strip_nulls(_r);
		end if;		
	end loop;
end
$BODY$;

-----------------------------------------------------
CREATE OR REPLACE FUNCTION public."taskPost_json"(_parent_tid bigint, _args json, _flags int)
    RETURNS SETOF json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER ROWS 1000
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
	_status			bigint = (_args->>'status')::bigint;
	
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
	
	if _status is not null then 
		 perform "taskSetStatus_a"(array[_tid]::bigint[], (case when _status = 0 then null else _status end) );
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
	select * from "taskQuery_json"(array[_tid]::bigint[], _flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPost_json"(_parent_tid bigint, _args json)
    RETURNS SETOF json LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER ROWS 1000
AS $BODY$
	select "taskPost_json"(_parent_tid, _args, 0);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPostReview_json"(_report_id bigint, _text text, _status_id bigint, _work_minutes integer, _flags int)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_ret 		record;
	_tid		bigint = "getTaskID_byEventID"(_report_id);
	_event_uid	bigint;
	_status		bigint = (case when _status_id > 0 then _status_id else null end);
begin

	if coalesce(_text, '') != ''
	then
		_event_uid = "eventNew"(
		  null -- user_id integer
		  , _tid
		  , "eventTextPlainToHtml"(_text)
		  , 1 -- Review
		  , _report_id --parenteventid
		  , _work_minutes
		);

		perform "eventSetFlags"(_report_id, 0, 2);    		
	else
		-- approve Hours
		-- raise exception 'dfdsf';
		perform "eventSetFlags"(_report_id, 2, 2);    		
	end if;

    if _status is distinct from (select status from tasks where uid = _tid)
    then
		perform "taskSetStatus_a"(array[ _tid ]::bigint[], _status);
	end if;

	select _event_uid::text as new_event_uid, task.*
		into _ret 
		from "taskQuery_json"(array[_tid]::bigint[], _flags) as task;

	return row_to_json(_ret);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPostReview_json"(_report_id bigint, _text text, _status_id bigint, _work_minutes integer)
    RETURNS json LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER
AS $BODY$
	select "taskPostReview_json"(_report_id, _text, _status_id, _work_minutes, 0);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPostMessage_json"(_tid bigint, _text text, _parent_event bigint, _flags int)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_ret 		record;
	_event_uid	bigint = "eventGetConcatMessageID"(_tid);
	_compo_text	text;
	_langid		integer;
begin
	--perform pg_sleep(10);

	if _event_uid is not null 
	then
		select text, langid into _compo_text, _langid from events where uid = _event_uid;

		_compo_text = (case 
			when coalesce(_compo_text, '') = '' 
				then ''
				else _compo_text || '<br>' 
			end)
			|| "eventTextPlainToHtml"(_text);

		perform "eventSetText"(_event_uid, _compo_text, _langid);
	else
		_event_uid = "eventNew"(
		  null -- user_id integer
		  , _tid
		  , "eventTextPlainToHtml"(_text)
		  , 3 -- note=message
		  , _parent_event
		  , null -- _work_minutes
		);
	end if;
	
	return "taskQuery_json"(array[_tid]::bigint[], _flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPostMessage_json"(_tid bigint, _text text, _parent_event bigint)
    RETURNS json LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER
AS $BODY$
	select "taskPostMessage_json"(_tid, _text, _parent_event, 0);
$BODY$;


CREATE OR REPLACE FUNCTION public."taskPostReport_json"(_tid bigint, _text text, _status_id bigint, _work_minutes integer, _flags int)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_ret 		record;
	_event_uid	bigint;
	_status		bigint = (case when _status_id > 0 then _status_id else null end);
begin
    _event_uid = "eventNew"(
      null -- user_id integer
      , _tid
      , "eventTextPlainToHtml"(_text)
      , 2 -- REPORT 
      , null --parenteventid
      , _work_minutes
    );

    if _status is distinct from (select status from tasks where uid = _tid)
    then
		perform "taskSetStatus_a"(array[ _tid ]::bigint[], _status);
	end if;
	
	select _event_uid::text as new_event_uid, task.*
		into _ret 
		from "taskQuery_json"(array[_tid]::bigint[], _flags) as task;

	return row_to_json(_ret);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskPostReport_json"(_tid bigint, _text text, _status_id bigint, _work_minutes integer)
    RETURNS json LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER
AS $BODY$
	select "taskPostReport_json"(_tid, _text, _status_id, _work_minutes, 0);
$BODY$;

CREATE OR REPLACE FUNCTION public."userSetAssignment_a_json"(_user_ids integer[], _tids bigint[], _assign boolean, _flags int)
    RETURNS jsonb LANGUAGE 'sql' 
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	--perform pg_sleep(10);
	select "userAssignmentTask_a"(_tids, _user_ids, (case when _assign then 1 else 0 end));
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."userSetTaskInterrest_a_json"(_user_ids integer[], _tids bigint[], _assign integer, _flags int)
    RETURNS jsonb LANGUAGE 'sql' 
		COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "userSetTaskInterrest_a"(_tids, coalesce(_user_ids, array[get_usid()]), _assign);
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskSetActivity_a_json"(_tids bigint[], _activity_id bigint, _flags int)
    RETURNS jsonb LANGUAGE 'sql' COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select  "taskSetActivity_a"(_tids, _activity_id);
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskSetStatus_a_json"(_tids bigint[], _status_id bigint, _flags int)
    RETURNS jsonb LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "taskSetStatus_a"(_tids, (case when _status_id = 0 then null else _status_id end) );
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskSetPriority_a_json"(_tids bigint[], _priority integer, _flags int)
    RETURNS jsonb LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "taskSetPriority_a"(_tids, _priority::smallint);
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskSetName_json"(_tid bigint, _name text, _flags int)
    RETURNS jsonb LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "taskSetName"(_tid, _name);
	select "taskQuery_jsonb"(array[_tid]::bigint[], _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."taskRelink_a_json"(_tids bigint[], _new_parent_uid bigint, _flags integer)
    RETURNS jsonb LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "taskRelinkMulti"(_tids, _new_parent_uid);
	select "taskQuery_jsonb"(_tids, _flags);
$BODY$;

-- FUNCTION: public."taskCopy_json"(bigint, bigint, integer)

-- DROP FUNCTION public."taskCopy_json"(bigint, bigint, integer);

CREATE OR REPLACE FUNCTION public."taskCopy_a_json"(_tids bigint[], _new_parent_uid bigint, _flags integer)
    RETURNS jsonb LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_names 	text[] = (select array_agg(name) from tasks where uid = any(_tids));
	_res	  bigint[];

	__flags int = coalesce(_flags,  
		1   -- sub tasks
		| 2   -- tags
		| 4   -- assigned users
		| 8   -- events (by default only null parented)
				--16 	-  full event copy
		| 32 	-- atachments
	);
begin
	
	_res = (select array_agg(d) 
		from 
		 "dupVTask"(
			_tids
			, _names
			, _new_parent_uid
			, __flags
			, null) as d
	);

	return "taskQuery_jsonb"(_res, _flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."eventSetText_json"(_eventid bigint, _text text, _lang text, _flags int)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_tid bigint = "getTaskID_byEventID"(_eventid);
	_langid	int = coalesce(
		(select uid from langs where code2::text = _lang)
		, "ftsUniLang_byTask"(_tid));
	
begin
	perform "eventSetText"(_eventid, "eventTextPlainToHtml"(_text), _langid);
	return "taskQuery_json"(array[_tid]::bigint[], _flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."eventSetText_json"(_eventid bigint, _text text, _lang text)
    RETURNS json LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER
AS $BODY$
	select "eventSetText_json"(_eventid, _text, _lang, 0);
$BODY$;


CREATE OR REPLACE FUNCTION public."eventDelete_json"(_event_uid bigint, _flags integer)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_del smallint = (case when (_flags & 1)!=0 then 1 else 0 end);
	_tid bigint = "getTaskID_byEventID"(_event_uid);
begin
	perform _event_update(_event_uid, _del, null, null);
	return "taskQuery_json"(array[_tid]::bigint[], _flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."eventSetFlags_json"(_eventid bigint, _flags integer, _mask integer, _query_flags integer)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_tid bigint = "getTaskID_byEventID"(_eventid);
begin
	perform "eventSetFlags"(_eventid, _flags, _mask);
	return "taskQuery_json"(array[_tid]::bigint[], _query_flags);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."attachSetFlags_json"(_id bigint, _flags integer, _mask integer, _query_flags integer)
    RETURNS jsonb LANGUAGE 'sql'
    COST 100 VOLATILE SECURITY DEFINER 
AS $BODY$
	select "attachSetFlagsMulti"(array[_id], _flags, _mask);
	select "taskQuery_jsonb"(array["getTaskID_byEventID"((select eventid from attachments where uid = _id))]::bigint[], _query_flags);
$BODY$;

-- DROP FUNCTION public."searchQueryText_json"(text, integer[], text, integer, integer);
CREATE OR REPLACE FUNCTION public."searchQueryText_json"(	_query text, _unid_filter integer[], _url_prefix text, _search_flags integer, _query_flags integer)
    RETURNS json LANGUAGE 'plpgsql'
    COST 100 STABLE SECURITY DEFINER 
AS $BODY$
-- _search_flags - not used
-- _query_flags see "taskQuery_json"

declare
	_user_id	int = "get_usid"();
	_langid		int = "userLang"(_user_id);
	-- _history	json = "searchHistoryUpdate_json"(_query, _lang); -- VOLATILE !

	_conf regconfig = (select fts_conf from langs where uid = _langid);
	-- _limit int = 10;  --(case when __limit < 100 then __limit else 100 end);

	_query_ts		tsquery;
	_query_ilike	text = replace(replace(lower(_query), '%', '\%'), '_', '\_') || '%';

	_ht				bigint[]; -- Hash tags	
	_unids			int[];
	_url_like		text;

	_tk				"tSearchKey"[];
	_ek				"tSearchKey"[];
	_ak				"tSearchKey"[];
	_tids			bigint[];
	_mids			bigint[];
	_fids			bigint[];
	_id				bigint;

	_r				record;
Begin
	--perform pg_sleep(5);
	
	_url_like = (
		case when _url_prefix != '' 
		then (replace(replace(_url_prefix, '%', '\%'), '_', '\_') || '%') 
		else null end
	);

	_unids = (
		select array_agg(u.uid)
		from universes as u join users_universes as uu on uu.unid = u.uid
		where uu.userid = _user_id and "isUserInUniverse"(_user_id, u.uid) 
			and coalesce(not u.uid = any(_unid_filter), true)
	);

	BEGIN
		if _conf is null
		then
			_query_ts = to_tsquery(_query);
		else
			_query_ts = to_tsquery(_conf, _query);
		end if;
	EXCEPTION
	WHEN syntax_error THEN
		if _conf is null
		then
			_query_ts = plainto_tsquery(_query);
		else
			_query_ts = plainto_tsquery(_conf, _query);
		end if;
	END;

	_ht = (
		select array_agg(s.uid)
		from ht_schema as s 
		where lower(s.name) = lower(_query) and s.unid = any(_unids)
	);

	select array_agg(t.*) into _tk
	from (
		select q.uid, q.tid, max(rank), max(mtm), string_agg(headline_html_plain, e'\n')
		from "searchKey_FtsTasks"(_query_ts, _query_ilike, _unids, _url_like, _ht, _search_flags) as q
		group by q.uid, q.tid
		order by max(rank) desc, max(mtm) desc
		--limit _limit
	) as t;

	select array_agg(t.*) into _ek
	from (
		select q.uid, q.tid, max(rank), max(mtm), string_agg(headline_html_plain, e'\n')
		from "searchKey_FtsMessages"(_query_ts, _query_ilike, _unids, _url_like, _ht, _search_flags) as q
		group by q.uid, q.tid
		order by max(rank) desc, max(mtm) desc
		--limit _limit
	) as t;

	select array_agg(t.*) into _ak
	from (
		select q.uid, q.tid, max(rank), max(mtm), string_agg(headline_html_plain, e'\n')
		from "searchKey_FtsAttach"(_query_ts, _query_ilike, _unids, _url_like, _ht, _search_flags) as q
		group by q.uid, q.tid
		order by max(rank) desc, max(mtm) desc
		--limit _limit
	) as t;

	select array_agg(distinct(id.tid)) into _tids
		from (
			select k.tid from unnest(_tk) as k
			union select k.tid from unnest(_ek) as k
			union select k.tid from unnest(_ak) as k
		) as id
	;

	_mids = array_cat(
		(select array_agg(k.uid) from unnest(_ek) as k)
		, (select array_agg(eventid)
			from attachments 
			where uid in (select k.uid from unnest(_ak) as k)
		)
	);

	_fids = array_cat(
		(select array_agg(k.uid) from unnest(_ak) as k)
		, (select array_agg(uid)
			from attachments 
			where del = 0 and eventid in (select k.uid from unnest(_ak) as k)
		)
	);
	
	-- raise notice 'query_ts %, query_ilike %, unids %, url_like %', _query_ts, _query_ilike, _unids, _url_like;
	-- raise notice 'tids %', _tids;
	-- raise notice 'fids %', _fids;

	select 
		(select array_agg("taskQueryShort"(k, _query_flags | (1 << 13), _user_id, NULL)) --from "taskQuery_json"(_tids, -1) as q)
			from unnest(_tids) as k
		)as tasks
		, (select array_agg("taskQueryMessage_jsonb"(_user_id, t, e, _query_flags)) -- | (1<<7) | (1<<8)
			from events as e join tasks as t on e.taskid = t.uid
			where e.uid in (select distinct(k) from unnest(_mids) as k)
			--where e.uid in (select k.uid from unnest(_ek) as k)
		) as events
		, (select array_agg("taskQueryFile_jsonb"(_user_id, t, e, a, _query_flags))
			from attachments as a join events as e on a.eventID = e.uid join tasks as t on e.taskid = t.uid
			where a.uid in (select distinct(k) from unnest(_fids) as k)
				--(select k.uid from unnest(_ak) as k)
		) as files
		
		, "searchKeyAdopt"(_tk, _search_flags) as tkyes
		, "searchKeyAdopt"(_ek, _search_flags) as ekyes
		, "searchKeyAdopt"(_ak, _search_flags) as akyes
	into _r;

	return row_to_json(_r);
End
$BODY$;


/*
select * from "listProjects2_json"(null, 0);
*/