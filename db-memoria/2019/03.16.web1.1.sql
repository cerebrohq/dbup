CREATE OR REPLACE FUNCTION public."ggFloatToTimeStamp"(ofs double precision)
    RETURNS timestamp with time zone
    LANGUAGE 'plpgsql'
    IMMUTABLE  STRICT SECURITY DEFINER
    PARALLEL UNSAFE
    COST 100
AS $BODY$
begin
	--select ('2000-01-01T00:00:00+00'::timestamp with time zone) + ($1 * interval '1 day')
	return ('2000-01-01T00:00:00+00'::timestamp with time zone) + (round($1*86400) * interval '1 sec');
end
$BODY$;

CREATE OR REPLACE FUNCTION public."ellipsizeMsg"(_msg text, _len_max int)
    RETURNS text
    LANGUAGE 'plpgsql'
    IMMUTABLE  STRICT SECURITY DEFINER
    PARALLEL UNSAFE
    COST 100
AS $BODY$
declare
	--ln1		int = strpos(_msg, '</p>');
	--ln2		int = strpos(_msg, '<br');
	--len		int = strlen(_msg);
	_trunc text = substring(left(_msg || ' ', _len_max) from '.*\s');
begin
	return _msg;
	
	if length(_trunc) < _len_max / 2
	then
		return left(_msg, _len_max);
	elsif length(_trunc) <  length(_msg)
	then
		return trim(_trunc) || '...';
	else
		return trim(_msg);
	end if;
end
$BODY$;

--drop function "shortMsg"(text) ('_msg lkj    lkj lkj lk jtext');

--drop FUNCTION public."htAggregateAttachment_text"(_id bigint);
CREATE OR REPLACE FUNCTION public."htAggregateAttachment_ex"(_id bigint, _flags int)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
AS $BODY$
BEGIN
	-- b0: H:<id>
	-- b1: text
	return string_agg(
		(case _flags
		 	when 1 then 'H:' || to_hex(tagid)
		 	when 2 then ht_schema.name
		 	when 3 then 'H:' || to_hex(tagid) || ' ' || ht_schema.name
		 	else null
		end), ' ')
		from ht_attachment join ht_schema on tagid = ht_schema.uid
		where attachmentid = _id;
END
$BODY$;

--drop FUNCTION public."htAggregateEvent_text"(_id bigint)
CREATE OR REPLACE FUNCTION public."htAggregateEvent_ex"(_id bigint, _flags int)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
AS $BODY$
BEGIN
	-- b0: H:<id>
	-- b1: text
	return string_agg(
		(case _flags
		 	when 1 then 'H:' || to_hex(tagid)
		 	when 2 then ht_schema.name
		 	when 3 then 'H:' || to_hex(tagid) || ' ' || ht_schema.name
		 	else null
		end), ' ')
		from ht_event join ht_schema on tagid = ht_schema.uid
		where eventid = _id;
END
$BODY$;

--drop FUNCTION public."htAggregateTask_text"(_id bigint)
CREATE OR REPLACE FUNCTION public."htAggregateTask_ex"(_id bigint, _flags int)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
AS $BODY$
BEGIN
	-- b0: H:<id>
	-- b1: text
	return string_agg(
		(case _flags
		 	when 1 then 'H:' || to_hex(tagid)
		 	when 2 then ht_schema.name
		 	when 3 then 'H:' || to_hex(tagid) || ' ' || ht_schema.name
		 	else null
		end), ' ')
		from ht_task join ht_schema on tagid = ht_schema.uid
		where taskid = _id;
END
$BODY$;

-- FUNCTION: public."userQueryShort_json"(integer)
CREATE OR REPLACE FUNCTION public."userQueryShort_json"(_usid integer)
    RETURNS json
    LANGUAGE 'sql'
    COST 100
    STABLE SECURITY DEFINER 
AS $BODY$
	select row_to_json(q) from (
		select 
			users.uid::text as uid
			, "getUserName_byID"(users.uid) as name
			, (case when "perm_IsUserVisible"(get_usid(), uid, 0)>=2 then users.email else null end)
			, avatar_hash
			, coalesce(ldap_email, email) as email
		from users
		where 
			uid = _usid
			and "perm_IsUserVisible"(get_usid(), _usid) > 0
	) as q;
$BODY$;

CREATE OR REPLACE FUNCTION public."taskQueryUser_json"(_user_id integer, u users, _flags integer)
    RETURNS json LANGUAGE 'sql' COST 50 STABLE SECURITY DEFINER 
AS $BODY$
-- _flags: full description see taskQuery
--  at this time not used
	SELECT row_to_json(ut.*)
		from (select 
			u.uid::text as uid
			, "userNameDisplay"(_user_id, u.uid) as name
			, u.avatar_hash
			, coalesce(u.ldap_email, u.email) as email
			-- , firstname, lastname
			-- from users as _u
			--where 
			-- u.del = 0 
			-- and _u.uid = _uid
			-- and ("perm_IsUserVisible"(_user_id, u.uid, 1) > 0 or (u.ad_sid is not null))
		) as ut;
$BODY$;

ALTER FUNCTION public."taskQueryUser_json"(integer, users, integer) OWNER TO sa;
GRANT EXECUTE ON FUNCTION public."taskQueryUser_json"(integer, users, integer) TO sa;
REVOKE ALL ON FUNCTION public."taskQueryUser_json"(integer, users, integer) FROM PUBLIC;


CREATE OR REPLACE FUNCTION public."taskQueryFileThumb"(_eventid bigint, _groupid integer)
    RETURNS text
    LANGUAGE 'sql'
    COST 50
    STABLE SECURITY DEFINER 
AS $BODY$
	select coalesce(
		(select hash::text from attachments where tag = 2 and del = 0 and eventid = _eventid and groupid = _groupid),
		(select hash::text from attachments where tag = 1 and del = 0 and eventid = _eventid and groupid = _groupid)
	);
$BODY$;
GRANT EXECUTE ON FUNCTION public."taskQueryFileThumb"(_eventid bigint, _groupid integer) TO sa;
REVOKE ALL ON FUNCTION public."taskQueryFileThumb"(_eventid bigint, _groupid integer) FROM PUBLIC;


-- FUNCTION: public."taskQueryMessage_json"(integer, tasks, events, integer)
CREATE OR REPLACE FUNCTION public."taskQueryMessage_jsonb"(_user_id integer, t tasks, e events, _flags integer)
    RETURNS jsonb
    LANGUAGE 'plpgsql'

    COST 50
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


-- FUNCTION: public."taskQueryFile_json"(integer, tasks, events, attachments, integer)
CREATE OR REPLACE FUNCTION public."taskQueryFile_jsonb"(_user_id integer, t tasks, e events, a attachments, _flags integer)
    RETURNS jsonb
    LANGUAGE 'sql'

    COST 50
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

/*
select q --count(q)
	from "taskQueryShort_json"(
	(select array_agg(uid) from tasks where uid < 1500),
	0, 
	3,
	null) as q;
*/


-----------------------
CREATE OR REPLACE FUNCTION public."taskListTree2_json"(_parent bigint, _flags integer)
    RETURNS SETOF jsonb
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
-- _flags: full description see taskQuery
-- b0	show deleted
-- b3	show nav links
DECLARE	
	_user_id integer = "get_usid"();
	_tids	bigint[];
	_limit	int = 1000;
	_query_flags int = _flags | (1 << 10) | (1 << 12);
	
begin
	-- URGENT need SPEED UP!!!

	--perform pg_sleep(10);
	if _parent = -1
	then
		raise exception 'ASSERT: _task_list_00 _parent=-1';
	end if;

	_tids = (select array_agg(tl.uid)
		from "taskListTree"(_user_id, _parent, _flags, _limit) as tl
		--order by tl.seq_order
	);
	
	return query
	select t from "taskQuery_jsonb"(_tids, _query_flags) as t;
end
$BODY$;

-- DROP FUNCTION public."listProjects_jsonb"(integer[], integer);
-- select "listProjects_jsonb"(null, 0);
CREATE OR REPLACE FUNCTION public."listProjects2_json"(_unids integer[], _flags integer)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    STABLE SECURITY DEFINER 
AS $BODY$
-- _flags: full description see taskQuery
--	b0 - show with deleted
DECLARE
	_user_id integer = "get_usid"();
	--_r	 	record;
	--_ret	record;
	_query_flags int = _flags | (1 << 10) | (1 << 12);
	_prjs 	jsonb;
	_tasks 	jsonb;
	_tids	bigint[];

begin
	-- need SPEED UP!!!
	_prjs = (select jsonb_agg(p) 
		from (
			select
				projects.uid::text as prj_id
				, projects.root_task::text as root_task_uid
				, unid::text
				-- , (select jsonb_agg(u) from "listProjectUploadStores_json"(projects.uid, _flags) as u) as upload_stores

			from projects
				join tasks on tasks.uid = projects.root_task
			where
				tasks.uid > 0
				and coalesce(unid = any(_unids), true)
				and (tasks.del=0 or (_flags & 1) != 0)
				and "perm_IsTaskVisible"(_user_id, projects.root_task)
			order by tasks.name
		)
	as p);
	
	_tids = (select array_agg((p->>'root_task_uid')::bigint) from jsonb_array_elements(_prjs) as p);
	
	_tasks = (select jsonb_agg(t) from "taskQuery_jsonb"(_tids, _query_flags) as t);

	return jsonb_build_object(
		'prjs', _prjs,
		'tasks', _tasks
	);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskListTreeForAllParents2_json"(_parent bigint, _flags integer)
    RETURNS SETOF jsonb
    LANGUAGE 'plpgsql'
    COST 100
    STABLE SECURITY DEFINER STRICT
    ROWS 1000
AS $BODY$
declare
	_row 	record;
	_pid	bigint = coalesce(_parent, 0);

begin
	while (_pid >= 0)
	loop
	
		select _pid::text as pid, array_agg(q) as records 
			into _row 
			from "taskListTree2_json"(_pid, _flags) as q;
			
		return next to_jsonb(_row);
		_pid = (select lnk_front_parent from tasks where tasks.uid = _pid);
	end loop;
end
$BODY$;

--select '{"a":1}'::jsonb
--select ARRAY_CAT(null::jsonb[], array['{"a":1}']::jsonb[] );
--select null::jsonb[] || array['{"a":1}']::jsonb[];
--select array['{"a":1}']::jsonb[] || null::jsonb[];
--select '{"a": "b", "b": "d", "c": "d"}'::jsonb - '{a,c}'::text[]

--drop FUNCTION "taskQuery_jsonb"(task_uid bigint[], _flags integer)
CREATE OR REPLACE FUNCTION public."taskQuery_jsonb"(task_uid bigint[], _flags integer)
    RETURNS SETOF jsonb
    LANGUAGE 'plpgsql'
    COST 100
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
--	b10 - skip events & files
--	b11 - skip workers
--	b12 - skip subscribers
--  b13 - skip status object + (skip uploadSites for listProjects)
--  b14 - include notifyPerms
--  b15 - extended data "notifyData_json" -> taskLog
--  b16 - mobile-short data (TaskLists)

-- taskQueryFile:
--	b20 - fill Review
--	b21 - fill perm_IsEventEditable flag
--	b22 - fill thumbHash

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
			, cp_cc_reserve as planned
			, (cp_cc_declared_total/60.0)::real as declared
			, (cp_cc_approved_total/60.0)::real as approved
			, (resource_declared_total/60.0)::real as resource_declared
			, (resource_approved_total/60.0)::real as resource_approved

			, costs as self_costs
			, cc_pays as self_pays
			, cc_costs as costs
			, cc_pays_total as pays
			
		 	, "userNameDisplay"(_user_id, t.creatoruserid) as creator_name
			, (select avatar_hash from users where uid = t.creatoruserid) as creator_hash
			, (case when "isTaskInterrsted"(_user_id, t.uid) then 1 else 0 end) as interest

			, "ggFloatToTimeStamp"("ggGlobalOffset"(t.uid)) as tg_cc_start_at
			, "ggFloatToTimeStamp"(coalesce(tg_stop, "ggGlobalOffset"(t.uid) + tg_cc_dur)) as tg_cc_stop_at
			, tg_cc_dur as tg_cc_duration
			, "ggFloatToTimeStamp"(tg_offset) as human_start_at
			, "ggFloatToTimeStamp"(tg_stop) as human_stop_at
			
			, "htAggregateTask_ex"(t.uid, 2) as htags
		 
		 	, (select "ellipsizeMsg"(e.text, 250) from events as e where e.taskid = t.uid and e.del = 0 and coalesce(e.text, '')!=''  order by e.uid asc  limit 1) as first_message_html_plain
		 	, (select "ellipsizeMsg"(e.text, 250) from events as e where e.taskid = t.uid and e.del = 0  and coalesce(e.text, '')!='' order by e.uid desc limit 1) as last_message_html_plain

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
				raise notice '_flags % ', (_flags & (1<<11));
				
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
			end if;

		 	if (_flags & (1<<12)) = 0 --	b12 - skip subscribers
			then
				_q = (select jsonb_agg("taskQueryUser_json"(_user_id, users, _flags))
					from "interrestUsersTask"(_res.task_id::bigint) as iu 
						join users on iu = users.uid
					where (_flags & (1<<12)) = 0
				 );
				
				_r = _r || jsonb_build_object('subscribers', _q);
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
		
		return next _r;
	end loop;
end
$BODY$;


-- DROP FUNCTION public."taskQuery_json"(bigint[], integer);
CREATE OR REPLACE FUNCTION public."taskQuery_json"(task_uid bigint[], _flags integer)
    RETURNS SETOF json 
    LANGUAGE 'sql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
	select to_json(q) from "taskQuery_jsonb"(task_uid, _flags) as q;
$BODY$;

-- DROP FUNCTION public."taskPost_json"(bigint, json);
CREATE OR REPLACE FUNCTION public."taskPost_json"(_parent_tid bigint, _args json)
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
	select * from "taskQuery_json"(array[_tid]::bigint[]);
end
$BODY$;

/*
select e.uid, array_agg(a.uid)
	from attachments as a 
		join events as e on a.eventID = e.uid 
		join tasks  as t on t.uid = e.taskID
	where
		e.del = 0 and a.del = 0
	group by e.uid
	having not "perm_IsEventVisble"(29, e.uid)
*/

--select 1;

-- FUNCTION: public."taskResolveUID_json"(bigint, integer)

-- DROP FUNCTION public."taskResolveUID_json"(bigint, integer);

CREATE OR REPLACE FUNCTION public."taskResolveUID2_json"(_id bigint, _browse_uid bigint, _flags integer)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    STABLE SECURITY DEFINER 
AS $BODY$
declare
	_tid 			bigint;
	_browse_path	jsonb;
begin
	--perform pg_sleep(3);
	
	_tid = "refResolve"(_id);

	if _tid is null then
		_tid = "getTaskID_byEventID"(_id);
	end if;

	if _tid is null then
		_tid = (select taskid from events 
			where uid = (select eventid from attachments where uid = _id));
	end if;
	
	_browse_path = (case when _id is distinct from _browse_uid
		then (select jsonb_agg(p) from "taskListTreeForAllParents2_json"(_browse_uid, _flags) as p)
		else null 
	end);
	
	
	if _tid is null and _browse_path is null
	then
		return null;
	end if;
	
	return jsonb_build_object(
		'task', "taskQuery_jsonb"(array[_tid]::bigint[], _flags),
		'task_path', (select jsonb_agg(p) from "taskListTreeForAllParents2_json"(_tid, _flags) as p),
		'browse_path', _browse_path
	);	
end
$BODY$;


-- FUNCTION: public."userList_json"(integer)

-- DROP FUNCTION public."userList_json"(integer);

CREATE OR REPLACE FUNCTION public."userList_json"(
	_flags integer)
    RETURNS json
    LANGUAGE 'plpgsql'

    COST 100
    STABLE SECURITY DEFINER 
AS $BODY$
declare
	_usid int = "getUserID_bySession"();
	_uni_list int[] = (select array_agg(uid) from "uniUserList_00"(_usid));
begin
	return row_to_json(g.*) from 
	(select
		-- users
		(select array_agg(t.*)
			from (select 
				u.uid::text
				, "userNameDisplay"(u.uid) as name
				, avatar_hash
				, coalesce(ldap_email, email) as email

				, u.flags
				, (select array_agg(unid::text) 
					from users_universes 
					where userid = u.uid and del = 0
				) as unids
				
				, (select array_agg(activityid::text) 
					from users_activities join activitytypes on uid = activityid
					where userid = u.uid and del=0
				) as activities
				
				, (select array_agg(groupid::text) 
					from users_groups join groups on uid = groupid
					where userid = u.uid and del=0
				) as groups
				
				from "userList"() as ul join users as u on ul.uid = u.uid
			) as t
		) as users
		
		-- groups
		, (select array_agg(t.*)
			from (select 
				g.uid::text
				, g.name as name
				, g.flags
				, g.unid::text
				from groups as g
				where unid = any(_uni_list)
			) as t
		) as groups
	) as g;
end
$BODY$;

CREATE OR REPLACE FUNCTION public."taskFavoriteList_json"(_flags integer)
    RETURNS SETOF json 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
DECLARE	
	_user_id integer = "get_usid"();
	_tids	bigint[];
	_limit	int = 1000;
	_query_flags int = _flags | (1 << 10) | (1 << 12);
	
begin
	_tids = (
		select array_agg(ut.taskid order by t.cc_url || t.name)
			from users_tasks as ut join tasks as t on ut.taskid = t.uid
			where
				userid = _user_id
				and (ut.flags & 1) != 0
				and (t.flags & 1) = 0			
	);

	return query
	select to_json(t) from "taskQuery_jsonb"(_tids, _query_flags) as t;

	/*
	select row_to_json(t.taskShort) from (
		 select "taskQueryShort"(ut.taskid
					, _flags | (1<<13) -- no Status
					, "get_usid"(), NULL) as taskShort
			from (
				select  ut.taskid
				from users_tasks as ut join tasks as t on ut.taskid=t.uid
				where
					userid = "get_usid"()
					and (ut.flags & 1) != 0
					and (t.flags & 1 ) = 0
				order by t.cc_url || t.name 
			) as ut
	) as t;*/
end
$BODY$;


CREATE OR REPLACE FUNCTION public."navigationHistory_json"(_flags integer)
    RETURNS SETOF json LANGUAGE 'plpgsql' COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
declare
	_user_id	int = "get_usid"();
	_r			record;
	_res		record;
	_query_flags int = _flags | (1 << 10) | (1 << 12) | (1<<13); -- 13 no Status
begin
	for _r in (
		select val.uid, val.nav_mtm_at
		from (
			select ((j.val)->>'uid')::bigint as uid, ((j.val)->>'mtm_at')::timestamp with time zone as nav_mtm_at
			from (
				select json_array_elements(val::json) as val
					from attrib_user 
					where key = 301 and usid = _user_id
				) as j
			) as val
		where
			"refResolve"(val.uid) is not null
			and "perm_IsTaskVisible"(_user_id, val.uid)
			and (select (flags & 1) = 0 from tasks where uid = val.uid)
	) loop
		return next to_json(t || jsonb_build_object('nav_mtm_at', _r.nav_mtm_at) )
			from "taskQuery_jsonb"(array[_r.uid], _query_flags) as t;
		
		/*select t.*, _r.nav_mtm_at
			from "taskQueryShort"(_r.uid
				, _flags 
				, _user_id, NULL) as t
			into _res;
		return next row_to_json(_res);*/
	end loop;
end
$BODY$;


CREATE OR REPLACE FUNCTION public."taskMyList_json"(_flags integer)
    RETURNS SETOF json LANGUAGE 'plpgsql' COST 100 STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
declare
	_uids		bigint[];
	_q_flags	integer = _flags 
		--| (1<<10) -- skip files and msg
		--| (1<<11) -- skip workers 
		| (1<<12) -- skip subscribe
		| (1<<13) -- skip status object
		| (1<<14) -- include notifyPerms
		-- DO NOT DO | (1<<16) -- Mobile-short ShortData
	;
begin
	select array_agg(q.uid)
	into _uids
	from (
		select ut.taskid as uid
		from users_tasks as ut join tasks as t on ut.taskid = t.uid
		where
			userid = "get_usid"()
			and ut.mtm > now() - '1 year'::interval
			and ut.assigned_perc is not null
			and (t.flags & 1) = 0
			order by ut.mtm desc --t.cc_url || t.name
		limit 500
	) as q;

	return query
	select to_json(q) from "taskQuery_jsonb"(_uids, _q_flags) as q;
end
$BODY$;



CREATE OR REPLACE FUNCTION public."userSetAssignment_a_json"(_user_ids integer[], _tid bigint, _assign boolean)
    RETURNS jsonb LANGUAGE 'sql' COST 100 
	VOLATILE SECURITY DEFINER 
AS $BODY$
	--perform pg_sleep(10);
	select "userAssignmentTask_a"(array[_tid], _user_ids, (case when _assign then 1 else 0 end));
	select "taskQuery_jsonb"(array[_tid]::bigint[], 0);
$BODY$;

-- FUNCTION: public."userSetTaskInterrest_json"(integer, bigint, integer)

-- DROP FUNCTION public."userSetTaskInterrest_json"(integer, bigint, integer);

CREATE OR REPLACE FUNCTION public."userSetTaskInterrest_a_json"(_user_ids integer[], _tid bigint, _assign integer)
    RETURNS jsonb LANGUAGE 'sql' COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
	--perform pg_sleep(10);
	select "userSetTaskInterrest_a"(array[_tid], coalesce(_user_ids, array[get_usid()]), _assign);
	select "taskQuery_jsonb"(array[_tid], 0);
$BODY$;


CREATE OR REPLACE FUNCTION public."taskCopy_json"(_tid bigint, _new_parent_uid bigint, _flags integer)
    RETURNS json
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_name 	text = (select name from tasks where uid = _tid);
	_res	bigint[];

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
			array[_tid]::bigint[]
			, array[_name]::text[]
			, _new_parent_uid
			, __flags
			, null) as d
	);

	return "taskQuery_jsonb"(_res, 0);
end
$BODY$;
