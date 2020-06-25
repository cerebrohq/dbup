-- Function: "zFileList_ForUniverse"(text, interval)

-- DROP FUNCTION "zFileList_ForUniverse"(text, interval);

CREATE OR REPLACE FUNCTION "logList"(
    _unid integer,
    _categoty smallint,
    start_time timestamp with time zone,
    stop_time timestamp with time zone)
  RETURNS SETOF logs AS
$BODY$
declare
	
begin
	if not("isUserShepherd_bySession"() or "perm_Root"($1) < 0)
	then
		raise exception 'Access denied';
	end if;

	return query
	select 
		*
	from 
		logs
	where 
		unid=$1	
		and category=$2	
		and coalesce(mtm >= $3, true)
		and coalesce(mtm <= $4, true);
end
$BODY$
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  COST 100
  ROWS 1000;
ALTER FUNCTION "logList"(integer, smallint, timestamp with time zone, timestamp with time zone)
  OWNER TO sa;
