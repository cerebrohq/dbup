-- FUNCTION: public."taskList_byStatus_02"(bigint[], text[], bigint, bigint[])

-- DROP FUNCTION public."taskList_byStatus_02"(bigint[], text[], bigint, bigint[]);

CREATE OR REPLACE FUNCTION public."taskList_byStatus_02"(
	_project_ids bigint[],
	_parent_urls text[],
	_status_id bigint,
	_activity_ids bigint[],
	_flags integer)
RETURNS SETOF "tKey" 
	LANGUAGE 'plpgsql'
	COST 100
	STABLE STRICT SECURITY DEFINER 
	ROWS 1000
AS $BODY$

-- _flags are:
-- b0	show deleted
-- OBSOLETE b1	show done tasks
-- OBSOLETE b2	show closed tasks
-- b3	show references

DECLARE
	user_id integer = "get_usid"();
begin
	IF (_flags & 8) != 0
	THEN
		return query
			SELECT sortedtasks.mtm, sortedtasks.uid FROM
			(
				SELECT DISTINCT ON (uniquetasks.taskid) uniquetasks.mtm, uniquetasks.uid FROM
				(
					(
						SELECT
							t.mtm::timestamp with time zone as mtm
							, t.uid::bigint as uid
							, t.uid::bigint as taskid
							, 0::int as reforder
						FROM
							tasks AS t
						WHERE
							t.prj_id = ANY(_project_ids)
							AND (t.flags & 0000001) = 0
							AND (t.flags & 4) = 0
							AND "perm_IsTaskVisible"(user_id, t.uid)
							AND t.cc_status = _status_id
							AND t.activityid = ANY(_activity_ids)
							AND EXISTS (SELECT 1 FROM UNNEST(_parent_urls) url WHERE t.cc_url LIKE url||'%')
							AND (NOT EXISTS (SELECT 1 FROM tasks AS tt WHERE tt.lnk_front_parent = t.uid AND (tt.flags & 0000001) = 0))
						-- ORDER BY t.mtm
						LIMIT 1000
					)
					UNION
					(
						SELECT
							t.mtm::timestamp with time zone as mtm
							, nl.uid::bigint as uid
							, t.uid::bigint as taskid
							, 1::int as reforder
						FROM
							nav_links as nl join tasks as t on nl.taskid = t.uid
						WHERE
							EXISTS (SELECT 1 FROM UNNEST(_parent_urls) url WHERE (SELECT cc_url||"name"||'/' FROM tasks WHERE uid = nl.parentid)::text LIKE url||'%')
							AND (t.flags & 0000001) = 0
							AND (t.flags & 4) = 0
							AND "perm_IsTaskVisible"(user_id, t.uid)
							AND t.cc_status = _status_id
							AND t.activityid = ANY(_activity_ids)
						-- ORDER BY t.mtm
						LIMIT 1000
					)
				) AS uniquetasks ORDER BY uniquetasks.taskid, uniquetasks.reforder ASC
			) AS sortedtasks ORDER BY sortedtasks.mtm DESC;
	ELSE
		return query
			SELECT
				t.mtm::timestamp with time zone as mtm
				, t.uid::bigint as uid
			FROM
				tasks AS t
			WHERE
				t.prj_id = ANY(_project_ids)
				AND (t.flags & 0000001) = 0
				AND (t.flags & 4) = 0
				AND "perm_IsTaskVisible"(user_id, t.uid)
				AND t.cc_status = _status_id
				AND t.activityid = ANY(_activity_ids)
				AND EXISTS (SELECT 1 FROM UNNEST(_parent_urls) url WHERE t.cc_url LIKE url||'%')
				AND (NOT EXISTS (SELECT 1 FROM tasks AS tt WHERE tt.lnk_front_parent = t.uid AND (tt.flags & 0000001) = 0))
			ORDER BY t.mtm DESC
			LIMIT 1000;
	END IF;
end

$BODY$;

ALTER FUNCTION public."taskList_byStatus_02"(bigint[], text[], bigint, bigint[], integer)
	OWNER TO sa;
