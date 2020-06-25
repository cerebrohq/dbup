
CREATE OR REPLACE FUNCTION public."taskSetStop_json"(
	_tid bigint,
	_at_js bigint)
    RETURNS json
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
declare
begin
	perform "ggSetTaskStop_a"(array[_tid]::bigint[], "ggJSTimeToFloat"(_at_js));
	return "taskQuery_json"(array[_tid]::bigint[]);
end
$BODY$;

CREATE OR REPLACE FUNCTION public."userSetDeviceId"(
	_id text,
	_on boolean)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
declare
	_usid	integer = "getUserID_bySession"();
	_key 	int = 200;
	_def	text = "attributeUser"(_usid, _key);
	_ids	text[];
	_other_usid int;
begin
	if coalesce(_id, '') = '' 
	then
		return;
	end if;

	--  remove DiveiceID form all others users
	for _other_usid in (select usid from attrib_user where key = _key and usid != _usid and val ilike '%' || _id || '%')
	loop
		_ids = (select coalesce((select array_agg(q) from unnest(val::text[]) as q where q != _id), '{}') 
			from attrib_user 
			where key = _key and usid = _other_usid);
			
		update attrib_user set val = _ids::text where usid = _other_usid and key = _key;
	end loop;
	
	if _def is not null
	then
		_ids = _def::text[];

		if _on and not exists (select 1 from unnest(_ids) as q where q = _id)
		then
			_ids = array_append(_ids, _id);
		elsif not _on 
		then
			_ids = coalesce((select array_agg(q) from unnest(_ids) as q where q != _id), '{}');			
		end if;
	else
		 if _on then 
			_ids = array[_id]::text[];
		 end if;
	end if;

	if _ids is not null
	then
		perform "attributeUserSet"(_usid, _key, _ids::text);

		-- mark as sent existing notifs
		update unemailedtasks set emailsent=now()
			where scope = 102 and userid = _usid and mtm > now() - '1 day'::interval;
	end if;
end
$BODY$;
