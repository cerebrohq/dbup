-- UPDATE USER CHANGE FACILITY!!!!
-- !!! REMOVE ALL TOKENS WHEN USER CHANGE ANY CREDS!!!
-- UPDATE USER CHANGE FACILITY!!!!


CREATE OR REPLACE FUNCTION public."webGenUserSID"(_flags int, _client_type int, _client_ip text)
  RETURNS name AS
$BODY$
declare
	_sid 	text;
begin
	loop
		_sid = substr(
			encode(digest(nextval('unemail_notify_random_seq'::regclass)::text || random()::text, 'md5'), 'hex')
			, 1, 24);
			
		exit when not exists (select 1 from users_web_sids where sid = _sid);
	end loop;

	delete from users_web_sids where mtm < now() - '1 year'::interval;
	
	insert into users_web_sids(usid, sid, flags, client_type, client_ip, expire_at)
		values ("get_usid"(), _sid, _flags, _client_type, _client_ip, now() + '6 month'::interval);
	return _sid;
end
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER COST 100;


CREATE OR REPLACE FUNCTION public."webStartBySID"(_sid text, _client_type int, _client_ip text)
  RETURNS bigint AS
$BODY$
declare
	ws_id	bigint;
	_r		record;
	_ret	bigint;
/*
returns:
	>0 - OK
	-1 - SID not found
	-2 - compromied by _client_ip
	-3 - compromied manually
	-4 - compromied by client_type
	Exception - expired
*/
begin
	if session_user != 'sa_web' and session_user != 'sa'
	then
		raise exception 'Web access denied';
	end if;

	select * into _r from users_web_sids where sid = _sid;
	if _r is null or (_r.flags & 1) != 0
	then
		return -1;
	end if;

	if _r is null or (_r.flags & 1) != 0
	then
		return -3;
	end if;

	if _r.client_ip != _client_ip or (_r.flags & 2) != 0
	then
		update users_web_sids set flags = flags | 2 where sid = _sid;
		return -2;
	end if;

	if _r.client_type != _client_type or (_r.flags & 4) != 0
	then
		update users_web_sids set flags = flags | 4 where sid = _sid;
		return -4;
	end if;

	if now() > _r.expire_at
	then
		return -5;
	end if;

	_ret = "webToken"(_r.usid, _client_type);
	update web_sid set token = _sid where wsid = _ret;
	return _ret;
end	
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER COST 10;


  
-- select "webGenUserSID"(0, 1, '_client_ip text');
-- select "webStartBySID"('_sid text', 1, '_client_ip text');
