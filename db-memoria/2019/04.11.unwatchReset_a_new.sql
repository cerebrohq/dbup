-- FUNCTION: public."unwatchReset"(integer, bigint)
-- DROP FUNCTION public."unwatchReset_a"(integer, bigint);

CREATE OR REPLACE FUNCTION public."unwatchReset_a"(tid bigint[])
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
DECLARE
	usid integer = get_usid();											   
	i bigint;
	_uid bigint;	
BEGIN
	if(array_dims(tid) is not NULL)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_uid = "refResolve"(tid[i]);
			update unemailedtasks 
				set emailsent = now() 
				where userid = usid
					and logid in (select uid from logs where logs.taskid = _uid)		
				;							
		end loop;
	end if;
END
$BODY$;

ALTER FUNCTION public."unwatchReset_a"(bigint[])
    OWNER TO sa;
