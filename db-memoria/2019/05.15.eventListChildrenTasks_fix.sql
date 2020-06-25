-- FUNCTION: public."eventListChildrenTasks"(bigint, boolean)

-- DROP FUNCTION public."eventListChildrenTasks"(bigint, boolean);

CREATE OR REPLACE FUNCTION public."eventListChildrenTasks"(
	_tid bigint,
	_list_deleted boolean)
    RETURNS SETOF "tKey" 
    LANGUAGE 'plpgsql'

    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$
declare
	_task_id bigint = "refResolve"(_tid);
	_task_url character varying;
	_task_parent_url character varying;
	_prj_id bigint;
	usid integer = "get_usid"();
	_limit integer = 200;
begin	
	select prj_id, cc_url, cc_url || "name" into _prj_id, _task_parent_url, _task_url  from tasks where uid = _task_id;
	if _task_parent_url = '/'
	then
		_limit = 500;
	end if;
	
	return query
	SELECT 
		e.mtm
		, e.uid
	FROM
		events as e 
	INNER JOIN 
		tasks as t on t.uid=e.taskid	
	WHERE
		t.prj_id = _prj_id
		AND t.cc_url like (_task_url || '/%')
		AND ($2 or e.del=0)
		AND e.tag!=6
		AND "perm_IsEventVisble"(usid, e.uid)
		
	ORDER BY e.creationTime DESC limit _limit;
end
$BODY$;

ALTER FUNCTION public."eventListChildrenTasks"(bigint, boolean)
    OWNER TO sa;
