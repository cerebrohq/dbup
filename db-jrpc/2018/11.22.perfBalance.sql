
CREATE OR REPLACE FUNCTION public."webResume2"(ws_id bigint)
  RETURNS void AS
$BODY$
declare
begin
	perform set_config('usrvar.wsid', ws_id::text, true);
end	
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER COST 10;


CREATE OR REPLACE FUNCTION public."userSID"()
  RETURNS bigint AS
$BODY$
declare
	_twsid text;
begin
	_twsid = current_setting('usrvar.wsid');
	if coalesce(_twsid, '') = ''
	then
		raise exception 'ASSERT: webResume or webStart was not called (usrvar.wsid is null)';
	end if;

	return _twsid::bigint;
end
$BODY$
  LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER COST 10;


-- drop FUNCTION public."perfLogDelay"();
CREATE OR REPLACE FUNCTION public."perfLogDelay"(_sql text)
  RETURNS int AS
$BODY$
declare
	_sid 		bigint		= "userSID"();
	_look_deep	interval	= '15 min'::interval;

	_super_heavy_duration	int = 30;  -- 'super-heavy query' duration in seconds
	_super_heavy_limit		int = 3;   -- in _look_deep interval
	_super_heavy_delay		int = 20;  -- penalty in sec to Delay

	_heavy_duration		int = 10;  -- 'heavy query' duration in seconds
	_heavy_limit		int = 5;   -- in _look_deep interval
	_heavy_delay		int = 5;   -- penalty in sec to Delay

	_count_limit_freq	int = 250; -- limit overal request Frequency per ONE Minute
	_count_delay		int = 1;   -- penalty in sec to Delay

	_sh		int;
	_h		int;
begin
	select 
		sum((case when duration > _super_heavy_duration then 1 else 0 end))
		, sum((case when duration > _heavy_duration then 1 else 0 end))
	into _sh, _h
	from perf_log 
	where sid = _sid and mtm > now() - _look_deep and sql =_sql;

	--raise notice '_sh %, _h %', _sh, _h;
		
	if _sh >= _super_heavy_limit
	then 
		return _super_heavy_delay;
	end if;

	if _h >= _heavy_limit
	then 
		return _heavy_delay;
	end if;

	if (select count(1) from perf_log where sid = _sid and mtm > now() - '1 min'::interval) > _count_limit_freq
	then 
		return _count_delay;
	end if;

	return 0;
end
$BODY$
  LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER
  COST 100;

CREATE OR REPLACE FUNCTION public."perfLogInsert"(_duration double precision, _sql text, _delay int)
  RETURNS void AS
$BODY$
declare
	_sid 		bigint = "userSID"();
begin
	if random() < 0.001 
	then
		delete from public.perf_log where mtm < now() - '24 hour'::interval;	
	end if;
	
	INSERT INTO public.perf_log(sid, duration, sql, delay) VALUES (_sid, _duration, _sql, _delay);	
end
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER COST 100;


-- select "webResume2"(3507698991788144687); select "perfLogDelay"();
-- select "webResume2"(3507698991788144687); select * from "perfLogInsert"(11.898173093796, e'sss', 323);


