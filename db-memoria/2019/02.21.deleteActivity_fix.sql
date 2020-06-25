/*
Добавлено удаление записей из status_activities
*/



-- FUNCTION: public."deleteActivity"(bigint)

-- DROP FUNCTION public."deleteActivity"(bigint);

CREATE OR REPLACE FUNCTION public."deleteActivity"(
	activity_id bigint)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
begin
	perform "perm_checkGlobal"((select unid from activityTypes where uid=$1), 'mng_tag_act');
	
	if (activity_id = "getDefaultActivityID"())
	then
		raise exception 'Can''t delete default activity';
		return;
	end if;

	UPDATE activityTypes SET del=1 WHERE uid=activity_id;
	if not FOUND then ROLLBACK; return; end if;

	DELETE FROM users_activities WHERE activityID = activity_id;
	delete from status_activities where activityid = activity_id;

	perform "touchActivity"(activity_id);
end
$BODY$;

ALTER FUNCTION public."deleteActivity"(bigint)
    OWNER TO sa;

GRANT EXECUTE ON FUNCTION public."deleteActivity"(bigint) TO sa;

GRANT EXECUTE ON FUNCTION public."deleteActivity"(bigint) TO PUBLIC;

