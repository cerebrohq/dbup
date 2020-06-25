-- FUNCTION: public."taskTagColumn"(bigint, bigint[])

-- DROP FUNCTION public."taskTagColumn"(bigint, bigint[]);

CREATE OR REPLACE FUNCTION public."taskTagColumn"(
	tag_id bigint,
	task_uid bigint[])
RETURNS SETOF "tTagValShort" 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 100
AS $BODY$

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
				SELECT _id, tag_val_scalar.ival::character varying
				from tasks join tag_val_scalar on tasks.uid=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.ival is not null)
			);
		elseif(tag_type=2)
		then
			return query
			(
				SELECT _id, tag_val_scalar.rval::character varying
				from tasks join tag_val_scalar on tasks.uid=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.rval is not null)
			);
		elseif(tag_type=3)
		then
			return query
			(
				SELECT _id, tag_val_scalar.sval
				from tasks join tag_val_scalar on tasks.uid=tag_val_scalar.taskid
				where 
					tasks.uid = _tid
					and tag_val_scalar.tagid=tag_id and tag_val_scalar.del=0 and (tag_val_scalar.sval is not null)
			);
		elseif(tag_type=1 or tag_type=4)
		then
			return query
			(
				SELECT _id, tag_enums.sval
				from 
					tasks join tag_val_enum on tasks.uid=tag_val_enum.taskid
					inner join tag_enums on tag_val_enum.enumid=tag_enums.uid 
				where
					tasks.uid = _tid
					and tag_val_enum.tagid=tag_id
					and tag_val_enum.del=0 and (tag_enums.sval is not null)
			);
		end if;
	end loop;
end

$BODY$;

ALTER FUNCTION public."taskTagColumn"(bigint, bigint[])
    OWNER TO sa;
