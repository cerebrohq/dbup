-- FUNCTION: public."taskList_byStatus_01"(bigint[], text[], bigint, bigint[])

-- DROP FUNCTION public."taskList_byStatus_01"(bigint[], text[], bigint, bigint[]);

CREATE OR REPLACE FUNCTION public."taskList_byStatus_01"(
	project_ids bigint[],
	parent_urls text[],
	status_id bigint,
	activity_ids bigint[])
RETURNS SETOF "tKey" 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$

DECLARE
	user_id integer = "get_usid"();
begin
	return query
		SELECT
			t.mtm::timestamp with time zone
			, t.uid::bigint
		FROM
			tasks AS t
		WHERE
			t.prj_id = ANY(project_ids)
			AND (t.flags & 0000001) = 0
			AND (t.flags & 4) = 0
			AND "perm_IsTaskVisible"(user_id, t.uid)
			AND t.cc_status = status_id
			AND t.activityid = ANY(activity_ids)
			AND EXISTS (SELECT 1 FROM UNNEST(parent_urls) url WHERE t.cc_url LIKE url||'%')
			AND (NOT EXISTS (SELECT 1 FROM tasks AS tt WHERE tt.lnk_front_parent = t.uid AND (tt.flags & 0000001) = 0))
			ORDER BY t.mtm
			LIMIT 1000
		;
end

$BODY$;

ALTER FUNCTION public."taskList_byStatus_01"(bigint[], text[], bigint, bigint[])
    OWNER TO sa;

-- FUNCTION: public."taskList_byLevel"(bigint[], text[], integer, integer)

-- DROP FUNCTION public."taskList_byLevel"(bigint[], text[], integer, integer);

CREATE OR REPLACE FUNCTION public."taskList_byLevel"(
	project_ids bigint[],
	parent_urls text[],
	task_level integer,
	flags integer)
RETURNS SETOF "tKey" 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$

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
			t.prj_id = ANY(project_ids)
			and (t.flags & 1) = 0
			and (t.flags & 4) = 0
			and "perm_IsTaskVisible"(user_id, t.uid)
			and case when task_level = -1
				then exists
				(
					select 1 from tasks as tc
					where not
					(
						exists(select 1 from tasks as tcc where tcc.lnk_front_parent = tc.uid and (tcc.flags & 1)=0 and (tcc.flags & 4)=0)
					)					
					and tc.lnk_front_parent = t.uid
					and (tc.flags & 1)=0 and (tc.flags & 4)=0
				)
				else t.cc_level = task_level
				end
			and exists (select 1 from unnest(parent_urls) url where t.cc_url like url||'%')
			order by t.mtm
		;
end

$BODY$;

ALTER FUNCTION public."taskList_byLevel"(bigint[], text[], integer, integer)
    OWNER TO sa;
											 
-- FUNCTION: public."taskList_byParents"(bigint[], bigint[], integer)

-- DROP FUNCTION public."taskList_byParents"(bigint[], bigint[], integer);

CREATE OR REPLACE FUNCTION public."taskList_byParents"(
	parent_ids bigint[],
	activity_ids bigint[],
	flags integer)
RETURNS SETOF "tKeyParent" 
    LANGUAGE 'plpgsql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$

-- _flags are:
-- b0	only child tasks

DECLARE
	user_id integer = "get_usid"();
begin
	return query
		SELECT
			t.mtm::timestamp with time zone
			, t.uid::bigint
			, t.lnk_front_parent::bigint
		FROM
			tasks as t 
		WHERE
			t.lnk_front_parent = ANY($1)
			and
			(
				($3 & 1) = 0
				or
				not(exists(select 1 from tasks as tc where tc.lnk_front_parent = t.uid and (tc.flags & 1)=0 and (tc.flags & 4)=0))
			)
			and t.activityid = ANY($2)
			and (t.flags & 0000001) = 0
			and (t.flags & 4) = 0
			and "perm_IsTaskVisible"(user_id, t.uid)
			order by t.activityid
		;
end

$BODY$;

ALTER FUNCTION public."taskList_byParents"(bigint[], bigint[], integer)
    OWNER TO sa;

