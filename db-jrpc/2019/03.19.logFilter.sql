
-- DROP FUNCTION public."filterClusters"(integer[], text, text);
--select "filterClusters"(array[1,2,3,11]::integer[], 'tiunovi', '123456');
--select * from login_log where cluster_id=11 and status < 0 

-- CREATE INDEX ix_login_log_hash ON public.login_log USING btree(hash);

CREATE OR REPLACE FUNCTION public."filterClusters"(
	_cluster_id integer[],
	_user text,
	_password text)
RETURNS SETOF integer 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$
declare
	_hash text = ('md5' || encode(digest(_user || _password, 'md5'), 'hex'));
	_status int;
	_mtm timestamp with time zone;
	_last_login timestamp with time zone;
	_repeats int;
begin
	_last_login = (select mtm from login_log where hash = _hash order by mtm desc limit 1);

	--raise notice '_hash %, last_login age %', _hash, now() - _last_login;
	
	for i in array_lower(_cluster_id, 1)..array_upper(_cluster_id, 1)
	loop
		if exists (select 1 
			from login_log 
			where cluster_id = _cluster_id[i]
				and status < 0 
				and (now() - mtm) < '5 min'::interval) 
		then
			raise notice 'failed %', _cluster_id[i];
			continue; -- error with this cluster in less than 5 min
		end if;
		
		if now() - _last_login > '3 min'::interval
		then
			-- if _last_login < 3 min - do not check Login Log cache
			
			select status, mtm, repeats
				into _status, _mtm, _repeats
				from login_log 
				where cluster_id = _cluster_id[i] and hash = _hash;

			raise notice 'lastLogin %, cluster %, status %', now()-_last_login, _cluster_id[i], _status;

			if _status = 0 then -- bad login
				raise notice 'bad %, age %, _repeats %', _cluster_id[i], (now() - _mtm), _repeats;
				continue; -- 
				
				/* USELESS Checks!!!
				if (now() - _mtm) < '3 min'::interval then
					continue;
				end if;
				
				if  _repeats < 5 and (now() - _mtm) < '10 min'::interval then
					continue;
				end if;

				if  _repeats < 20 and (now() - _mtm) < '1 hour'::interval then
					continue;
				end if;

				--if  _repeats > 50 then
				--	continue;
				--end if;*/
			else
				-- _status is null then -- no login attemptes found
				-- _status > 0 then -- good login
			end if;	
		end if;
		
		return next _cluster_id[i]; 
	end loop;
end
$BODY$;

ALTER FUNCTION public."filterClusters"(integer[], text, text)
    OWNER TO sa;
