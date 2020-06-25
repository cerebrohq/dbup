-- FUNCTION: public."refList"(bigint[])
-- DROP FUNCTION public."refList"(bigint[]);

CREATE OR REPLACE FUNCTION public."refParentList"(
	_parent_id bigint)
    RETURNS SETOF "tValBint" 
    LANGUAGE 'sql'

    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select uid, taskid from nav_links where parentid = $1;
$BODY$;

ALTER FUNCTION public."refParentList"(bigint)
    OWNER TO sa;
