/*

Добавлено:
Новая процедура получения значений тегов родительских задач для массива задач.
taskTagParentColumn

*/


-- Function: "taskTagParentColumn"(bigint, bigint[])

-- DROP FUNCTION "taskTagParentColumn"(bigint, bigint[]);

CREATE OR REPLACE FUNCTION "taskTagParentColumn"(
    tag_id bigint,
    task_uid bigint[])
  RETURNS SETOF "tTagValShort" AS
$BODY$
declare
	tag_type	integer = (select datatype from tag_schema where uid=tag_id);
	_ret		"tTagValShort";
	sv		character varying;
	_id		bigint;
	_tid		bigint;
	i 			int;
begin

	if(array_dims(task_uid) is NULL)
	then
		return;
	end if;

	for i in array_lower(task_uid, 1)..array_upper(task_uid, 1)
	loop
		_id = task_uid[i];
		_tid = "refResolve"(_id);
		
		if(tag_type=0 or tag_type=5)
		then
			return query
			(
				SELECT tasks.lnk_front_parent, tag_val_scalar.ival::character varying
				from tasks join tag_val_scalar on tasks.lnk_front_parent=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.ival is not null)
			);
		elseif(tag_type=2)
		then
			return query
			(
				SELECT tasks.lnk_front_parent, tag_val_scalar.rval::character varying
				from tasks join tag_val_scalar on tasks.lnk_front_parent=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.rval is not null)
			);
		elseif(tag_type=3)
		then
			return query
			(
				SELECT tasks.lnk_front_parent, tag_val_scalar.sval
				from tasks join tag_val_scalar on tasks.lnk_front_parent=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.sval is not null)
			);
		elseif(tag_type=1 or tag_type=4)
		then
			return query
			(
				SELECT tasks.lnk_front_parent, tag_enums.sval
				from 
					tasks join tag_val_enum on tasks.lnk_front_parent=tag_val_enum.taskid
					inner join tag_enums on tag_val_enum.enumid=tag_enums.uid 
				where
					tasks.uid = _tid
					and tag_val_enum.tagid=tag_id
					and tag_val_enum.del=0 and (tag_enums.sval is not null)
			);
		end if;
	end loop;
end
$BODY$
  LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER
  COST 100
  ROWS 100;
ALTER FUNCTION "taskTagParentColumn"(bigint, bigint[])
  OWNER TO sa;




