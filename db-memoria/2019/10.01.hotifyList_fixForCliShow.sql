-- FUNCTION: public."notifyList"(integer, integer, timestamp with time zone)

-- DROP FUNCTION public."notifyList"(integer, integer, timestamp with time zone);

CREATE OR REPLACE FUNCTION public."notifyList"(
	_scope integer,
	_usid integer,
	_time timestamp with time zone)
    RETURNS SETOF "tNotifyList" 
    LANGUAGE 'sql'

    COST 100
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select
		u.uid
		, u.mtm
		, u.time_to_send
		, u.emailsent
		, u.scope
		, lc.skey::text
		, u.userid
		, l.taskid
		, "eventCheckID"(l.param)
		, (select string_agg(to_hex(uid), ' ') from "taskParentList"(l.taskid) as uid)

	from 
		unemailedtasks as u
		join logs as l on u.logid = l.uid
		join logs_category as lc on lc.uid = l.category
	where 
		u.userid = _usid
		and (lc.api_level = 0 or lc.uid = 2110) -- only OLD Events and client visible
		and u.scope = _scope
		and (
			(u.emailsent is null and (_time is null or u.mtm > _time))
			or (_time is not null and u.emailsent > _time)  -- or change mtm???? 
		)
		and now() > u.time_to_send
		and "perm_IsTaskVisible"(_usid, l.taskid) -- for changed perms!!!
	;
$BODY$;

ALTER FUNCTION public."notifyList"(integer, integer, timestamp with time zone)
    OWNER TO sa;
