-- FUNCTION: public."getLastEventTag"(bigint)

-- DROP FUNCTION public."getLastEventTag"(bigint);

CREATE OR REPLACE FUNCTION public."getLastEventTag"(
	tid bigint)
RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
AS $BODY$

declare
	t		integer;
	f		integer;
begin
	-- in getTaskFlags some bits reserverd for lastEventBits
	select tag, flags into t, f from events where taskid=$1 and del=0 order by creationtime DESC, uid DESC LIMIT 1;
	return (t | (f << 4));
end;

$BODY$;

ALTER FUNCTION public."getLastEventTag"(bigint)
    OWNER TO sa;
