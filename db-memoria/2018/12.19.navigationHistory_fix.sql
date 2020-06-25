CREATE OR REPLACE FUNCTION public."navigationHistory_json"(
	_flags integer)
    RETURNS SETOF json 
    LANGUAGE 'plpgsql'

    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$
declare
	_user_id	int = "get_usid"();
	_r			record;
	_res		record;
	
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
		select t.*, _r.nav_mtm_at
			from "taskQueryShort"(_r.uid
				, _flags | (1<<13) -- no Status
				, _user_id, NULL) as t
			into _res;
			
		return next row_to_json(_res);
	end loop;
end
$BODY$;
