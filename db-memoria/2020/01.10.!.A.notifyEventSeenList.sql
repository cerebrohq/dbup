DROP FUNCTION public."notifyEventSeenMarkLogId"(bigint, integer, integer);
DROP FUNCTION public."notifyEventSeenMarkTaskId"(bigint, integer, integer);
DROP FUNCTION public."notifyEventRemove"(bigint[], integer, integer);
DROP FUNCTION public."notifyEventSeenList"(integer, integer);
DROP TYPE public."tNotifySeenList";

CREATE TYPE public."tNotifySeenList" AS
(
	taskid text,
	param text,
	lid text,
	uurl text,
	cat text,
	
	unid text,
	prj_id text,
	task_pid text,
	mtm_at_js double precision
);

CREATE OR REPLACE FUNCTION public."notifyEventSeenList"(_unseen_limit integer, _flags integer)
    RETURNS SETOF "tNotifySeenList" LANGUAGE 'sql' COST 100 
		STABLE SECURITY DEFINER ROWS 1000
AS $BODY$
	select 
		t.uid::text
		, l.param::text
		, l.uid::text
		, p.unid::text || t.cc_url || t.name
		, lc.skey::text as cat

		, p.unid::text
		, p.uid::text
		, lnk_front_parent::text
		, (EXTRACT(EPOCH FROM l.mtm)*1000)::double precision
	from unemailedtasks as uml 
		join logs as l on uml.logid = l.uid
		join tasks as t on t.uid = l.taskid
		join projects as p on p.uid = t.prj_id
		join logs_category as lc on lc.uid = l.category
	where 
		uml.scope = 100 
		and uml.userid = "get_usid"() 
		and uml.emailsent is null
	order by uml.logid desc
	limit least(_unseen_limit+1, 999);
$BODY$;

CREATE OR REPLACE FUNCTION public."notifyEventSeenMarkTaskId"(
	_tid bigint,
	_unseen_limit integer,
	_flags integer)
    RETURNS SETOF "tNotifySeenList" 
    LANGUAGE 'sql'

    COST 100
    VOLATILE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select "notifyEventSent"(q.uid)
		from (
			select uml.uid 
				from unemailedtasks as uml join logs as l on uml.logid = l.uid
				where l.taskid = _tid and uml.userid = "get_usid"()
		) as q;

	select "notifyEventSeenList"(_unseen_limit, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."notifyEventRemove"(
	_lid bigint[],
	_unseen_limit integer,
	_flags integer)
    RETURNS SETOF "tNotifySeenList" 
    LANGUAGE 'sql'

    COST 100
    VOLATILE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	delete from unemailedtasks where logid = any(_lid) and userid = "get_usid"();
	select "notifyEventSeenList"(_unseen_limit, _flags);
$BODY$;

CREATE OR REPLACE FUNCTION public."notifyEventSeenMarkLogId"(
	_lid bigint,
	_unseen_limit integer,
	_flags integer)
    RETURNS SETOF "tNotifySeenList" 
    LANGUAGE 'sql'

    COST 100
    VOLATILE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select "notifyEventSent"(q.uid)
		from (
			select uid 
				from unemailedtasks 
				where logid = _lid and userid = "get_usid"()
		) as q;
		
	select "notifyEventSeenList"(_unseen_limit, _flags);
$BODY$;

