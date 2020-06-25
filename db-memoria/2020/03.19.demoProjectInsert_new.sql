-- FUNCTION: public."demoProjects"()

-- DROP FUNCTION public."demoProjects"();

CREATE OR REPLACE FUNCTION public."demoProjects"(
	)
    RETURNS SETOF "tBigintStr" 
    LANGUAGE 'plpgsql'

    COST 100
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
declare
	_conn_string_from text = 'host=dbt.cerebrohq.com port=45432 dbname=memoria_template user=sa_copier password=copier';
	_unid_from integer = 8310;
	
begin

	perform dblink_connect(_conn_string_from);
	
	RETURN query	
	select uid, val FROM dblink('SELECT p.uid, ap.val::character varying FROM projects AS p INNER JOIN attrib_project ap ON ap.pid = p.uid WHERE key = 600 and p.unid = ' || _unid_from || ';') AS t(uid bigint, val character varying);
end
$BODY$;


-- FUNCTION: public."demoProjectInsert"(integer, bigint, text, integer[], integer[])

-- DROP FUNCTION public."demoProjectInsert"(integer, bigint, text, integer[], integer[]);

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
	_conn_string_from text = 'host=dbt.cerebrohq.com port=45432 dbname=memoria_template user=sa_copier password=copier';	
	_unid_from integer = 8310;
	_site_dns_from	character varying;
	
	_me				int = get_usid();
	_new_prj_uid	bigint = "newID"();
	_new_root_tid	bigint = "newID"();
	_new_site_id	bigint = null;	
	
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
	
	IF (SELECT unid FROM projects WHERE uid=_prj_id_from) != _unid_from
	THEN
		raise exception 'Selected project is not a Demo';
	END IF;
	
	IF "isExistsProjectName"(_unid_to, _prj_name)
	THEN
		raise exception 'Project with selected name exists';
	END IF;	
	
	--connect to template db
	perform dblink_connect(_conn_string_from);
	
	--insert new project
	INSERT INTO projects (uid, root_task, unid) VALUES (_new_prj_uid, _new_root_tid, _unid_to);
	
	CREATE TEMP TABLE tt_dup_tasks
	(		
		src bigint NOT NULL,		
		dst bigint NOT NULL,		
		dst_parent bigint NOT NULL,		
		new_name text NOT NULL,
		deep integer NOT NULL,
		url text NOT NULL,	
		src_activity bigint NOT NULL,		
		CONSTRAINT pk_tt_dup_tasks PRIMARY KEY (src)
	) ON COMMIT DROP;
	
	CREATE INDEX ix_tt_dup_tasks_deep ON tt_dup_tasks(deep);
	CREATE INDEX ix_tt_dup_tasks_src ON tt_dup_tasks(src);
	
	select lang INTO _lang from universes where uid = _unid_to;
	
	-- Select source root task	
	select * into _tid from dblink('select root_task from projects where uid =' || _prj_id_from || ';') AS t(root_task bigint);	   
	
	-- Insert root task dup
	INSERT INTO tt_dup_tasks(src, dst, dst_parent, new_name, deep, url, src_activity)
	VALUES(_tid, _new_root_tid, 0, _prj_name, 1, '/', 0);	
	
	-- Insert full tree dup
	i = 1;
	LOOP
		INSERT INTO tt_dup_tasks(src, dst, dst_parent, new_name, deep, url, src_activity) 
			SELECT ext.uid, "newID"(), tt.dst, ext.name, i+1, tt.url || tt.new_name || '/', ext.activityid
			FROM dblink('select uid, name, activityid, lnk_front_parent from tasks where prj_id = ' || _prj_id_from || ' and (flags & 1)=0 order by seq_order;')
			AS ext(				
				uid bigint,				
				name character varying,
				activityid bigint,				
				lnk_front_parent bigint				
			)			
			JOIN tt_dup_tasks AS tt ON ext.lnk_front_parent = tt.src
			WHERE tt.deep=i;
		
		EXIT WHEN NOT FOUND;
		i = i+1;
	END LOOP;	
	
	analyze tt_dup_tasks;
	
	--raise notice 'do copy % tasks', (SELECT COUNT(1) FROM tt_dup_tasks);	
	
	--copy activities	
	FOR _id IN (SELECT src_activity FROM tt_dup_tasks WHERE src_activity != 0)
	LOOP
		IF (NOT EXISTS(SELECT 1 FROM z_act_map WHERE u = _unid_to AND s = _id))
		THEN
			SELECT uid INTO _nid FROM activitytypes WHERE unid = _unid_to
				AND "name" = (select t."name" FROM dblink('select name from activitytypes where uid =' || _id || ';') AS t("name" character varying));
			IF (_nid IS NULL)
			THEN
				_nid = "newID"();
				INSERT INTO activitytypes(uid, "name", cp_default_weight, del, unid, color)
					SELECT _nid, "name", cp_default_weight, del, _unid_to, color
					FROM dblink('select "name", cp_default_weight, del, color from activitytypes where uid = ' || _id || ';')
					AS ext(								
						"name" character varying,
						cp_default_weight real,				
						del smallint,
						color integer
					);
																														   
				--raise exception 'activity %', (select "name" from activitytypes where uid=_nid);
			END IF;
			INSERT INTO z_act_map(u, s, d) VALUES(_unid_to, _id, _nid);
		END IF;
	END loop;	
	
	-- copy tasks
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
			, langid, fts

	FROM dblink('select * from tasks where prj_id = ' || _prj_id_from || '  and (flags & 1)=0 order by seq_order;')
			AS ext(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				creationtime timestamp with time zone,
				creatoruserid integer,
				name character varying,
				activityid bigint,
				progress real,
				lnk_front_parent bigint,
				cp_fixed real,
				cp_weight real,
				cp_cc_child_fixed boolean,
				cp_cc_child_fixed_sum real,
				cp_cc_reserve real,
				tg_duration real,
				cp_salary real,
				priority smallint,
				pr_cc_progress real,
				cp_cc_declared_time bigint,
				cp_cc_approved_time bigint,
				cp_cc_declared_total bigint,
				cp_cc_approved_total bigint,
				cp_cc_sum_fixed_min real,
				cc_thumbnailes character varying,
				xmtm timestamp with time zone,
				prj_id bigint,
				cc_url character varying,
				cc_last_event_tag integer,
				cc_level smallint,
				tg_cc_dur double precision,
				tg_cc_ofs double precision,
				flags integer,
				cc_thumb_recent_id bigint,
				cc_thumb_recent_mtm timestamp with time zone,
				cc_thumb_oldest_id bigint,
				cc_thumb_oldest_mtm timestamp with time zone,
				cc_thumb_recent_group integer,
				cc_thumb_oldest_group integer,
				tg_offset double precision,
				tg_stop double precision,
				costs double precision,
				cc_costs double precision,
				cc_pays double precision,
				cc_pays_total double precision,
				resource_declared bigint,
				resource_approved bigint,
				resource_declared_total bigint,
				resource_approved_total bigint,
				seq_order double precision,
				status bigint,
				cc_status bigint,
				cc_status_stat text,
				fts tsvector,
				langid integer,
				tg_mtm_cc timestamp with time zone
			)
	JOIN tt_dup_tasks AS tt ON ext.uid = tt.src
	ORDER BY tt.deep;
			
	-- copy internal links
	insert into links(src, dst, flags, percent)
	select ta.dst, tb.dst, flags, percent
	from dblink('select l.src, l.dst, l.flags, l.percent from links as l join tasks as t1 on l.src=t1.uid join tasks as t2 on l.dst=t2.uid where t1.prj_id = ' || _prj_id_from || ' and t2.prj_id = ' || _prj_id_from || ' and l.del=0;')
		AS ext(				
			src bigint,							
			dst bigint,
			flags integer,
			percent real				
		) 
		join tt_dup_tasks as ta on ext.src=ta.src 
		join tt_dup_tasks as tb on ext.dst=tb.src 
	;
																												 
	
	-- copy events
	CREATE TEMP TABLE tt_dup_events
	(		
		tid bigint NOT NULL,
		src bigint NOT NULL,
		dst bigint NOT NULL,		
		CONSTRAINT pk_tt_dup_events PRIMARY KEY (src)
	) ON COMMIT DROP;	
	
	CREATE INDEX ix_tt_dup_events_src ON tt_dup_events(src);
	
	-- Select all events excluding status change
	INSERT INTO tt_dup_events(tid, src, dst)
		SELECT dst, ext.uid, "newID"()
		FROM dblink('select e.uid, e.taskid from events as e join tasks as t on e.taskid=t.uid where t.prj_id = ' || _prj_id_from || ' and e.del=0 and e.tag!=6 ;')
			AS ext(				
				uid bigint,				
				taskid bigint				
			) 
		JOIN tt_dup_tasks on src=ext.taskid		
		ORDER BY ext.uid
	;
	
	INSERT INTO events(
		uid, taskid, parenteventid, del, tag, worktime, flags, "text", mtm, xmtm,  muid, creationtime
			, creatoruserid, statusid, langid, fts
			)
		SELECT tt.dst, tt.tid, NULL, del, tag, worktime, flags, "text", mtm, xmtm, _me, _now
			, _me, NULL, langid, fts
		FROM dblink('select e.* from events as e join tasks as t on e.taskid=t.uid where t.prj_id = ' || _prj_id_from || ';')
			AS ext(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				creationtime timestamp with time zone,
				creatoruserid integer,
				taskid bigint,
				tag integer,
				parenteventid bigint,
				worktime integer,
				flags integer,
				text text,
				xmtm timestamp with time zone,
				statusid bigint,
				langid integer,
				fts tsvector,
				rating real
			)  
		JOIN tt_dup_events AS tt ON ext.uid = tt.src
		ORDER BY ext.creationtime
	;
	
	INSERT INTO attachments(eventid, groupid, hash, tag, filesize, originalfilename, description, mtm, del, creationtime, flags)
		SELECT tt.dst, groupid, hash, tag, filesize, originalfilename, description, mtm, del, _now, flags
		FROM dblink('select a.* from attachments as a join events as e on a.eventid=e.uid join tasks as t on e.taskid=t.uid where t.prj_id = ' || _prj_id_from || ' and a.del=0;')
			AS ext(
				mtm timestamp with time zone,
				eventid bigint,
				del smallint,
				groupid integer,
				creationtime timestamp with time zone,
				hash character(64),
				tag integer,
				filesize bigint,
				originalfilename character varying,
				description character varying,
				uid bigint,
				flags integer) 
		JOIN tt_dup_events AS tt ON ext.eventid = tt.src
		ORDER BY ext
	;
	
	perform "thumbRegenTask"(dst) from tt_dup_tasks order by deep desc;
	
	UPDATE tasks SET cc_last_event_tag = "getLastEventTag"(uid)
	WHERE uid IN (SELECT dst FROM tt_dup_tasks);
	
	--clean statuses tasks	
	UPDATE tasks SET status=NULL, cc_status=NULL, cc_status_stat=NULL
	WHERE prj_id = _new_prj_uid AND (status IS NOT NULL OR cc_status IS NOT NULL OR cc_status_stat IS NOT NULL);
	
	--copy site
	IF EXISTS(SELECT 1 FROM attachments JOIN tt_dup_events AS tt ON eventid = tt.dst WHERE del=0)
	THEN
		select * into _site_dns_from from dblink('select s.dns_name from sites as s join sites_projects as sp on sp.siteid=s.uid WHERE sp.projectid =' || _prj_id_from || ' limit 1;') AS t(dns_name character varying);	   
		
		FOR _id IN (SELECT uid FROM sites WHERE unid = _unid_to AND (dns_name = _site_dns_from))
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
