-- FUNCTION: public."refConvertTask"(bigint[], integer)

-- DROP FUNCTION public."refConvertTask"(bigint[], integer);

CREATE OR REPLACE FUNCTION public."refConvertTask"(
	_ref_ids bigint[],
	_flags integer)
    RETURNS SETOF bigint 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$
declare
        _i 	bigint;
	_uid 	bigint;
	_cloneid 	bigint;
	_r		nav_links;
	_name	text;
	_res	bigint;
	_copy_ok boolean;
begin
	if array_dims(_ref_ids) is not NULL
	then
		for _i in array_lower(_ref_ids, 1)..array_upper(_ref_ids, 1)
		loop
			_uid = _ref_ids[_i];
			
			if not "refIs"(_uid)
			then
				raise exception '%', msg(117);
			end if;

			select * into _r from nav_links where uid = _uid;

			_name = coalesce(_r.name, (select name from tasks where uid=_r.taskid));

			_copy_ok = false;
			
			for _cloneid in (select * from "dupVTask"(array[_r.taskid]::bigint[], array[_name]::text[], _r.parentid, _flags) as u limit 1)
			loop
				if not _copy_ok				
				then
					_copy_ok = true;
				else
					raise exception 'ASSERT: copy was made twice';
				end if;

				delete from nav_links where uid = _uid;

				update tasks set 
					--uid = _uid,
					seq_order = _r.seq_order 
					where 
						uid = _cloneid;
			end loop;

			if not _copy_ok
			then
				raise exception 'ASSERT: copy was not OK';
			end if;
		end loop;
	end if;
end
$BODY$;

ALTER FUNCTION public."refConvertTask"(bigint[], integer)
    OWNER TO sa;
