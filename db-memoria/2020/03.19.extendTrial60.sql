-- FUNCTION: public."unwatchSpamUniRoundList"()

-- DROP FUNCTION public."unwatchSpamUniRoundList"();


-- FUNCTION: public."billQueryMaxLogins"(integer, date)

-- DROP FUNCTION public."billQueryMaxLogins"(integer, date);

CREATE OR REPLACE FUNCTION public."billQueryMaxLogins"(
	un_id integer,
	dt date)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$	
declare
	v1 	integer;
	v2	integer;
begin
	v2 = coalesce((select sum(allow_logins) from bills where unid=un_id and del=0 and start_date<=dt and stop_date>=dt), 0);
	v1 = coalesce((select bill_maxlogins from universes where uid=un_id and (creationtime::date + 60)>=dt), 0); --30
	
	return v1+v2;
end
$BODY$;

ALTER FUNCTION public."billQueryMaxLogins"(integer, date)
    OWNER TO sa;
	
-- FUNCTION: public."billQueryMaxLumpens"(integer)

-- DROP FUNCTION public."billQueryMaxLumpens"(integer);

CREATE OR REPLACE FUNCTION public."billQueryMaxLumpens"(
	un_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$	
declare
	v1 	integer;
	v2	integer;
begin
	v2 = coalesce((select sum(allow_lumpens) from bills where unid=un_id and del=0 and start_date<=current_date and stop_date>=current_date), 0);
	v1 = coalesce((select bill_maxlogins from universes where uid=un_id and (creationtime::date + 60)>=current_date), 0); --30
	
	return v1+v2;
end
$BODY$;

ALTER FUNCTION public."billQueryMaxLumpens"(integer)
    OWNER TO sa;



CREATE OR REPLACE FUNCTION public."unwatchSpamUniRoundList"(
	)
    RETURNS SETOF "tSpamEntryList" 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
    ROWS 100
AS $BODY$
begin
	/*select uid::bigint, 'uni_spam'::text, '31-day'::text, 0 
		from universes 
		where uid=70 
			and false
		;
	*/
	if "isServerPrimary"()
	then
		perform "zzAnihilateUniverse"(name, false) 
		from universes 
		where 
			uid > 100
			and now()-tasks_mtm > '100 days'::interval 
			and now()-creationtime > '100 days'::interval 
			and (not exists (select 1 from bills where unid=universes.uid))
		limit 1;
	end if;

	return query
	select * from
	(
		-- initial welcome
		select uid::bigint, 'uni_spam'::text, 'welcom', 0 
			from universes 
			where spam_round=0 and del=0
			and (not exists (select 1 from bills where unid=universes.uid) or uid=72)
	) as t1
	union
	select * from
	(
		select uid::bigint, 'uni_spam'::text, '15-day', 0 
			from universes 
			where spam_round=1 and del=0 and age(creationtime) >= '15 days'
			and (not exists (select 1 from bills where unid=universes.uid) or uid=72)
	) as t2
	union
	select * from
	(
		select uid::bigint, 'uni_spam'::text, '25-day', 0 
			from universes 
			where spam_round=2 and del=0 and age(creationtime) >= '55 days'
			and (not exists (select 1 from bills where unid=universes.uid) or uid=72)
	) as t3
	union
	select * from
	(
		select uid::bigint, 'uni_spam'::text, '30-day', 0 
			from universes 
			where spam_round=3 and del=0 and age(creationtime) >= '60 days'
			and (not exists (select 1 from bills where unid=universes.uid) or uid=72)
	) as t4
	union
	select * from
	(
		select uid::bigint, 'uni_spam'::text, '31-day', 0 
			from universes 
			where spam_round=4 and del=0 and age(creationtime) >= '61 days'
			and (not exists (select 1 from bills where unid=universes.uid) or uid=72)
	) as t5
	;
	/**/
end
$BODY$;

ALTER FUNCTION public."unwatchSpamUniRoundList"()
    OWNER TO sa;
