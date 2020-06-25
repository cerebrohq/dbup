/*

Реализованы процедуры:
Для получения пользователя и даты переключения статуса. Данные берутся из таблицы logs
Для получения задач в определенном статусе

Новая процедура для получения данных по изменению статуса для массива задач
taskStatusModified

Новая процедура для получения задачи по статусу. Возвращает тип tKey, имеет лимит в 1000 и только трутаски. 
taskList_byStatus

*/


CREATE OR REPLACE FUNCTION "taskStatusModified"(task_uid bigint[])
  RETURNS SETOF "tTaskStatusModified" AS
$BODY$
declare	
	ln 		"tTaskStatusModified";
	_tid		bigint;
	_id		bigint;
	i 		int;
begin

	if(array_dims(task_uid) is NULL)
	then
		return;
	end if;

	for i in array_lower(task_uid, 1)..array_upper(task_uid, 1)
	loop
		_id = task_uid[i];
		_tid = "refResolve"(_id);

		ln.uid=_id;
				
		select mtm, userid, param
			into ln.mtm, ln.userid, ln.statusid
			from logs
			where taskid = _tid
			and category = 1010 -- status changed
			order by mtm desc
			limit 1;

		return next ln;
	end loop;
end
$BODY$
  LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER
  COST 100
  ROWS 100;
ALTER FUNCTION "taskStatusModified"(bigint[])
  OWNER TO sa;


CREATE OR REPLACE FUNCTION "taskList_byStatus"(
    project_id bigint[],
    status_id bigint,
    activity_id bigint[])
  RETURNS SETOF "tKey" AS
$BODY$

DECLARE	
	user_id integer = "get_usid"();		
begin
	return query
		SELECT
			t.mtm::timestamp with time zone
			, t.uid::bigint
		FROM
			tasks as t 
		WHERE
			t.prj_id= any ($1)			
			and (t.flags & 0000001)=0
			and (t.flags & 4)=0
			and  "perm_IsTaskVisible"(user_id, t.uid)
			and t.cc_status = $2
			and t.activityid = any ($3)
			and (not exists (select 1 from tasks as tt where tt.lnk_front_parent=t.uid and (tt.flags & 0000001)=0))
			order by t.mtm
			limit 1000
		;
end
$BODY$
  LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER
  COST 100
  ROWS 1000;
ALTER FUNCTION "taskList_byStatus"(bigint[], bigint, bigint[])
  OWNER TO sa;

