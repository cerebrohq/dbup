CREATE OR REPLACE FUNCTION public."demoProjects"()
RETURNS SETOF "tBigintStr"
	LANGUAGE 'plpgsql'
	COST 100
	STABLE SECURITY DEFINER 
AS $BODY$
declare
	_unid_from integer = 8310;
begin
	RETURN query
	SELECT p.uid, ap.val::character varying FROM projects AS p INNER JOIN attrib_project ap ON ap.pid = p.uid WHERE p.unid = _unid_from AND key = 600;
end
$BODY$;

ALTER FUNCTION public."demoProjects"()
	OWNER TO sa;


CREATE OR REPLACE FUNCTION public."uniUserSetGroups"(
	_unid integer,
	_privileg_taskid bigint,
	_u_admins integer[],
	_u_workers integer[])
	RETURNS void
	LANGUAGE 'plpgsql'
	
	COST 100
	VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_id			bigint;
	_name_uni	text = (select name from universes where uid = _unid);
begin
	perform "perm_checkUserManageByUnid"(_unid, null);
	-- Add admins
	IF array_length(_u_admins, 1) > 0
	THEN
		SELECT uid INTO _id FROM groups WHERE name = _name_uni || ' admins' and unid = _unid;
		IF _id is null
		THEN
			INSERT INTO groups(name, unid) VALUES (_name_uni || ' admins', _unid);
			SELECT uid INTO _id FROM groups WHERE name = _name_uni || ' admins' and unid = _unid;
			INSERT INTO perm_groups(groupid, taskid, privileg) VALUES (_id, _privileg_taskid, -2);
			perform "log"(500, _unid, _id, 'group was created. group name: <' || _name_uni || ' admins' || '>.');
		END IF;
		
		FOR i IN array_lower(_u_admins, 1)..array_upper(_u_admins, 1)
		LOOP
			IF (NOT EXISTS(SELECT 1 FROM users_groups WHERE userID = _u_admins[i] AND groupID = _id))
			THEN
				INSERT INTO users_groups(userID, groupID) VALUES (_u_admins[i], _id);
				perform "log"(300, _unid, _u_admins[i], 'user was added into group. group id: <' || _id || '>.');
			END IF;
		END LOOP;
	
	END IF;
	
	-- Add workers
	IF array_length(_u_workers, 1) > 0
	THEN
		SELECT uid INTO _id FROM groups WHERE name = _name_uni || ' workers' and unid = _unid;
		IF _id is null
		THEN
			INSERT INTO groups(name, unid) VALUES (_name_uni || ' workers', _unid);
			SELECT uid INTO _id FROM groups WHERE name = _name_uni || ' workers' and unid = _unid;
			INSERT INTO perm_groups(groupid, taskid, privileg) VALUES (_id, _privileg_taskid, 8607801348);
			perform "log"(500, _unid, _id, 'group was created. group name: <' || _name_uni || ' workers' || '>.');
		END IF;
		
		FOR i IN array_lower(_u_workers, 1)..array_upper(_u_workers, 1)
		LOOP
			IF (NOT EXISTS(SELECT 1 FROM users_groups WHERE userID = _u_workers[i] AND groupID = _id))
			THEN
				INSERT INTO users_groups(userID, groupID) VALUES (_u_workers[i], _id);
				perform "log"(300, _unid, _u_workers[i], 'user was added into group. group id: <' || _id || '>.');
			END IF;
		END LOOP;
	END IF;
end
$BODY$;


/*
В запросе для тестов _unid указываем для той вселенной откуда берутся демо проекты.

Запрос возвращяет идентификатор проекта и json с информацией. В json-е должен быть язык, по которому фильтруются проекты.
*/

CREATE OR REPLACE FUNCTION public."demoProjectInsert"(
	_unid_to integer,
	_prj_id_from bigint,
	_prj_name text,
	_u_admins integer[],
	_u_workers integer[])
    RETURNS bigint
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	_unid_from 		integer = 8310;
	
	_me				int = get_usid();
	_new_prj_uid	bigint = "newID"();
	_new_root_tid	bigint = "newID"();
	_new_site_id	bigint = null;
	_stotage_id_from integer;
	
	_site_dns		text;
	_site_id		bigint;
	
	_name_uni		text = (select name from universes where uid=_unid_to);
	
	_now			timestamp with time zone = now();
	
	_tid			bigint;
	_nid			bigint;
	_id				bigint;
	_lang			int;
	i				integer;
begin
	perform "perm_checkTask"(0, 'mng_task', _unid_to);
	perform "perm_checkGlobal"(_unid_to, 'mng_tag_act');
	
	IF NOT "isUserInUniverse"(_me, _unid_to) 
	THEN 
		raise exception 'You do not belong to the destination universe';
	END IF;
	
	IF _unid_to = _unid_from
	then
		raise exception 'You are trying to duplicate a project in Demo universe. Don''t do that.';
	end IF;
	
	IF (SELECT unid FROM projects WHERE uid=_prj_id_from) != _unid_from
	THEN
		raise exception 'Selected project is not a Demo';
	END IF;
	
	IF "isExistsProjectName"(_unid_to, _prj_name)
	THEN
		raise exception 'Project with selected name exists';
	END IF;	
	
	--copy project
	INSERT INTO projects(uid, root_task, approve_time_calc_mode, unid, flags, default_task_duration) 
		SELECT _new_prj_uid, _new_root_tid, approve_time_calc_mode, _unid_to, flags, default_task_duration
		FROM projects WHERE uid = _prj_id_from;
	
	--copy tasks
	--dupVTask_CrossUni
	
	CREATE TEMP TABLE tt_dup_tasks
	(
		num int NOT NULL,
		src bigint NOT NULL,
		dst bigint NOT NULL,
		dst_parent bigint NOT NULL,
		new_name text NOT NULL,
		deep integer NOT NULL,
		url text NOT NULL,
		langid int,
		fts tsvector,
		CONSTRAINT pk_tt_dup_tasks PRIMARY KEY (src, num)
	) ON COMMIT DROP;
	
	CREATE INDEX ix_tt_dup_tasks_deep ON tt_dup_tasks(deep);
	CREATE INDEX ix_tt_dup_tasks_src ON tt_dup_tasks(src);
	
	-- Select source root task
	SELECT root_task INTO _tid FROM projects WHERE uid = _prj_id_from;
	SELECT langid INTO _lang FROM tasks WHERE uid = _tid;
	
	-- Insert root task dup
	INSERT INTO tt_dup_tasks(src, dst, dst_parent, new_name, deep, url, num, langid, fts)
	VALUES(_tid, _new_root_tid, 0, _prj_name, 1, '/', 1, _lang, "ftsVector"(_prj_name, COALESCE(_lang, "ftsUniLang_byTask"(_tid))));
	
	-- Insert full tree dup
	i = 1;
	LOOP
		INSERT INTO tt_dup_tasks(src, dst, dst_parent, new_name, deep, url, num, langid, fts) 
			SELECT tasks.uid, "newID"(), tt.dst, tasks.name, i+1, tt.url || tt.new_name || '/', num, tasks.langid, tasks.fts
			FROM tasks JOIN tt_dup_tasks AS tt ON tasks.lnk_front_parent = tt.src
			WHERE tt.deep=i AND (tasks.flags & 1)=0
			ORDER BY seq_order;
		
		EXIT WHEN NOT FOUND;
		i = i+1;
	END LOOP;
	
	--copy and set activities tasks
	--zDupAct
	--zMovePrj
	
	FOR _id IN (SELECT activityid FROM tasks WHERE prj_id = _prj_id_from AND activityid != 0)
	LOOP
		IF (NOT EXISTS(SELECT 1 FROM z_act_map WHERE u = _unid_to AND s = _id))
		THEN
			SELECT uid INTO _nid FROM activitytypes WHERE unid = _unid_to
				AND "name" = (SELECT "name" FROM activitytypes WHERE uid = _id);
			IF (_nid IS NULL)
			THEN
				_nid = "newID"();
				INSERT INTO activitytypes(uid, "name", cp_default_weight, del, unid, color)
					SELECT _nid, "name", cp_default_weight, del, _unid_to, color
					FROM activitytypes WHERE uid = _id;
			END IF;
			INSERT INTO z_act_map(u, s, d) VALUES(_unid_to, _id, _nid);
		END IF;
	END loop;
	
	
	raise notice 'do copy % tasks', (SELECT COUNT(1) FROM tt_dup_tasks);
	analyze tt_dup_tasks;
	
	-- Dup with event and attach
	INSERT INTO tasks(
			uid, name, lnk_front_parent, prj_id, cc_url, cc_level
			, mtm, xmtm, creationtime, muid,  creatoruserid
			, del, activityid, progress, flags, priority
			, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
			
			, pr_cc_progress, cc_last_event_tag
			
			, cp_cc_declared_time, cp_cc_approved_time, cp_cc_declared_total, cp_cc_approved_total
			, resource_declared, resource_approved,  resource_declared_total, resource_approved_total
			, costs
			
			, cc_thumbnailes, cc_thumb_recent_id, cc_thumb_recent_mtm, cc_thumb_oldest_id
			, cc_thumb_oldest_mtm, cc_thumb_recent_group, cc_thumb_oldest_group
			
			, status, seq_order
			, langid, fts
		)
	SELECT 
			tt.dst, tt.new_name, tt.dst_parent, _new_prj_uid, tt.url, tt.deep
			, _now, xmtm, _now, _me, _me
			, del, coalesce((SELECT d FROM z_act_map WHERE u = _unid_to AND s = activityid), 0), NULL, (flags & (~2)), priority
			, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
			
			, pr_cc_progress, cc_last_event_tag
			
			, cp_cc_declared_time, cp_cc_approved_time, cp_cc_declared_total, cp_cc_approved_total
			, resource_declared, resource_approved,  resource_declared_total, resource_approved_total
			, NULL
			
			, cc_thumbnailes, cc_thumb_recent_id, cc_thumb_recent_mtm, cc_thumb_oldest_id
			, cc_thumb_oldest_mtm, cc_thumb_recent_group, cc_thumb_oldest_group
			
			, NULL, "newSeqID"()
			, tt.langid, tt.fts

	FROM tasks JOIN tt_dup_tasks AS tt ON tasks.uid = tt.src
	ORDER BY tt.deep;
	
	-- Dup events
	CREATE TEMP TABLE tt_dup_events
	(
		num int NOT NULL,
		tid bigint NOT NULL,
		src bigint NOT NULL,
		dst bigint NOT NULL,
		dst_parent bigint,
		deep integer NOT NULL,
		tagid integer NOT NULL,
		CONSTRAINT pk_tt_dup_events PRIMARY KEY (src, num)
	) ON COMMIT DROP;
	
	CREATE INDEX ix_tt_dup_events_deep ON tt_dup_events(deep);
	CREATE INDEX ix_tt_dup_events_src ON tt_dup_events(src);
	
	-- Select all events excluding status change
	INSERT INTO tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
		SELECT dst, events.uid, "newID"(), NULL, 0, events.tag, num
		FROM events JOIN tt_dup_tasks on src=events.taskid
		WHERE del=0 AND events.tag!=6
		ORDER BY events.uid
	;
	
	INSERT INTO events(
		uid, taskid, parenteventid, del, tag, worktime, flags, "text", mtm, xmtm,  muid, creationtime
			, creatoruserid, statusid, langid, fts
			)
		SELECT tt.dst, tt.tid, dst_parent, del, tag, worktime, flags, "text", mtm, xmtm, _me, _now
			, _me, NULL, langid, fts
		FROM events JOIN tt_dup_events AS tt ON events.uid = tt.src
		ORDER BY events.creationtime
	;
	
	INSERT INTO attachments(eventid, groupid, hash, tag, filesize, originalfilename, description, mtm, del, creationtime)
		SELECT tt.dst, groupid, hash, tag, filesize, originalfilename, description, mtm, del, _now
		FROM attachments JOIN tt_dup_events AS tt ON eventid = tt.src
		WHERE del=0;
	
	perform "thumbRegenTask"(dst) from tt_dup_tasks order by deep desc;
	
	UPDATE tasks SET cc_last_event_tag = "getLastEventTag"(uid)
	WHERE uid IN (SELECT dst FROM tt_dup_tasks);
	
	--clean statuses tasks
	--zMovePrj
	
	UPDATE tasks SET status=NULL, cc_status=NULL, cc_status_stat=NULL
	WHERE prj_id = _new_prj_uid AND (status IS NOT NULL OR cc_status IS NOT NULL OR cc_status_stat IS NOT NULL);
	
	--copy site
	IF EXISTS(SELECT 1 FROM attachments JOIN tt_dup_events AS tt ON eventid = tt.src WHERE del=0)
	THEN
		SELECT s.uid, s.dns_name, s.storageid INTO _site_id, _site_dns, _stotage_id_from 
		FROM sites AS s JOIN sites_projects AS sp ON sp.siteid=s.uid WHERE sp.projectid=_prj_id_from LIMIT 1;
		
		FOR _id IN (SELECT uid FROM sites WHERE unid = _unid_to AND (dns_name = _site_dns)) -- and storageid = _stotage_id_from
		LOOP
			_new_site_id =_id; 
		END loop;
		
		IF _new_site_id is null
		THEN
			_new_site_id = "newID"();
			INSERT INTO sites(uid, name, dns_name, unid, size_quota, storageid, nativeport, webport)
				SELECT _new_site_id, name, dns_name, _unid_to, 0, null, nativeport, webport
				FROM sites WHERE uid=_site_id;
		END IF;
		
		INSERT INTO sites_projects(siteid, projectid) VALUES (_new_site_id, _new_prj_uid);
	END IF;
	
	-- Add user groups and privileges
	perform "uniUserSetGroups"(_unid_to, 0, _u_admins, _u_workers);
	
	-- Set start project now and recalc
	perform "updateProjectStartTime"(_new_prj_uid, _now);
	perform "touchTask"(_new_root_tid, 2 | 16 | 8192 | 262144, null);
	-- LOG?
	
	RETURN _new_prj_uid;
end

$BODY$;

ALTER FUNCTION public."demoProjectInsert"(integer, bigint, text, integer[], integer[])
    OWNER TO sa;
