-- FUNCTION: public."zUniPopulateDefaultNotify"(integer)

-- DROP FUNCTION public."zUniPopulateDefaultNotify"(integer);

CREATE OR REPLACE FUNCTION public."zUniPopulateDefaultNotify"(
	un_id integer)
RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE 
AS $BODY$

declare 
	_unid integer;
	_defa_client text = 'ev_def:As=1 ev_rev:As=1 ev_rep:As=1 ev_msg:As=1 ev_clrev:As=1 ev_def:Aw=1 ev_rev:Aw=1 ev_rep:Aw=1 ev_msg:Aw=1 ev_clrev:Aw=1 ev_def:In=0 ev_rev:In=0 ev_rep:In=0 ev_msg:In=0 ev_clrev:In=0 ev_def:Nm=1 ev_rev:Nm=1 ev_rep:Nm=1 ev_msg:Nm=1 ev_clrev:Nm=1 ev_clrev:CliShow=1';
	_defa_mail   text = 'ev_def:As=1 ev_rev:As=1 ev_rep:As=1 ev_msg:As=1 ev_clrev:As=1 ev_def:Aw=1 ev_rev:Aw=1 ev_rep:Aw=1 ev_msg:Aw=1 ev_clrev:Aw=1 ev_def:Nm=1 ev_rev:Nm=1 ev_rep:Nm=1 ev_msg:Nm=1 ev_clrev:Nm=1 ev_clrev:CliShow=1';

begin
	for _unid in (select uid from universes where coalesce(uid = un_id, true))
	loop
		if not exists (select 1 from attrib_universe where unid=_unid and key = 100)
		then
			insert into attrib_universe(unid, key, val) values (_unid, 100, _defa_client);
		else
			raise notice 'skip Client Defa for Unid %', _unid;
		end if;
		
		if not exists (select 1 from attrib_universe where unid=_unid and key = 101)
		then
			insert into attrib_universe(unid, key, val) values (_unid, 101, _defa_mail);
		else
			raise notice 'skip Mail Defa for Unid %', _unid;
		end if;
	end loop;
end

$BODY$;

ALTER FUNCTION public."zUniPopulateDefaultNotify"(integer)
    OWNER TO sa;
	
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


update logs_category set flags = flags | 2 where skey = 'CliShow';
