-- FUNCTION: public."getTaskID_byURL_a"(text[])
-- DROP FUNCTION public."getTaskID_byURL_a"(text[]);

CREATE OR REPLACE FUNCTION public."getTaskID_byURL_a"(
	task_url text[])
    RETURNS SETOF bigint
    LANGUAGE 'sql'

    COST 100
    STABLE STRICT SECURITY DEFINER 
	ROWS 1000
AS $BODY$
	select uid from tasks where (cc_url || "name") = any($1) and (flags & 0000001)=0;
$BODY$;

ALTER FUNCTION public."getTaskID_byURL_a"(text[])
    OWNER TO sa;
										  