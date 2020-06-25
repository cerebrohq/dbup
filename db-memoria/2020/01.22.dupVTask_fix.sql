-- FUNCTION: public."dupVTask"(bigint[], text[], bigint, integer, integer[])

-- DROP FUNCTION public."dupVTask"(bigint[], text[], bigint, integer, integer[]);

CREATE OR REPLACE FUNCTION public."dupVTask"(
	__tid bigint[],
	__name text[],
	_pid bigint,
	_flags integer,
	__langid integer[])
    RETURNS SETOF bigint 
    LANGUAGE 'plpgsql'

    COST 10000
    VOLATILE SECURITY DEFINER 
    ROWS 1000
AS $BODY$

DECLARE 
	tid bigint[];
	_name text[];
	_cross_tid bigint[];
	_cross_name text[];

	_lang	int;
	_langid int[];
	_cross_langid int[];
	
	pid 	bigint = _pid;
	_pid_unid 	int = "getUnid"(_pid);
	i	integer;
	_tid 	bigint;
	_rtid	bigint;	-- ref resolved tid
	_prj_id bigint;
	_base_deep integer;
	_base_url text;
	_usid	integer = get_usid();
	_lnk	links;
	_full_dup boolean;
	_now timestamp with time zone = now();
	_perm_mask bigint = (1 | (1<<12)); -- | (1<<30) costs ???
	_punid	int;
	_copy_prj boolean;
	_dup_mode boolean;
	_dup_perms boolean;
	_dup_status boolean;
	_found		boolean;
	
	_seed int = nextval('del_seq');
	_dup_tasks_name	text = 'tt_dup_tasks_' || _seed;
	_dup_refs_name	text = 'tt_dup_refs_' || _seed;
	
BEGIN
/*
1   - sub tasks
2   - tags
4   - assigned users
8   - events (by default only null parented)
16  	-  full event copy
32 - atachments
64 - internal links
128 - external links 1
256 - external links 2
512 - permissions
1024 - assign users full protocol with notified (may be slow)
2048 - subscription
4096 - status and progress
*/
	if "refIs"(_pid)
	then
		raise exception '%', "msg"(115);
	end if;

	if not (
		(array_dims(__tid) is not NULL) 
		and (array_dims(__name) is not NULL) 
		and array_dims(__tid) = array_dims(__name)
	)
	then
		return;
	end if;

	for i in array_lower(__tid, 1)..array_upper(__tid, 1)
	loop
		_tid = __tid[i];

		if (array_dims(__langid) is not NULL) and i <= array_upper(__langid, 1)
		then		
			_lang = __langid[i];
		else
			_lang = null;
		end if;

		if _pid_unid != "getUnid"(_tid)
		then
			_cross_tid  = array_append(_cross_tid, _tid);
			_cross_name = array_append(_cross_name, __name[i]);
			_cross_langid = array_append(_cross_langid, _lang);
		else
			tid   = array_append(tid, _tid);
			_name = array_append(_name, __name[i]);
			_langid = array_append(_langid, _lang);
		end if;
	end loop;

	-- cross Universe copy
	return query 
		(select * from "dupVTask_CrossUni"(_cross_tid, _cross_name, _pid, _flags, _cross_langid));

	if not ((array_dims(tid) is not NULL) and (array_dims(_name) is not NULL) and array_dims(tid) = array_dims(_name))
	then
		return;
	end if;

	select cc_level, cc_url || "name" || '/', prj_id into _base_deep, _base_url, _prj_id from tasks where uid=_pid;

	-- is pid a task
	if _prj_id is null
	then
		select uid, root_task, unid into _prj_id, pid, _punid from projects where uid=_pid;

		if (pid is null) or array_lower(tid, 1)!=1 or array_upper(tid, 1)!=1
		then
			raise exception 'Invalid arguments pid:%, l:%, u:%', pid, array_lower(tid, 1), array_upper(tid, 1);
		end if;

		perform "perm_checkTask"(0, 'mng_task', _punid);
		perform "perm_checkTask"(0, 'task_prop', _punid);

		_copy_prj = true;
		_base_deep = -1;
		_base_url = '/';
	else
		_copy_prj = false;
		_punid = "getUnid"(pid);

		perform "perm_checkTask"(pid, 'mng_task', null);
		perform "perm_checkTask"(pid, 'task_prop', null);
	end if;

	CREATE TEMP TABLE _dup_tasks_name
	(
	   num int NOT NULL,
	   src bigint NOT NULL,
	   dst bigint NOT NULL,
	   dst_parent bigint NOT NULL,
	   new_name text NOT NULL, 
	   deep integer NOT NULL, 
	   url text NOT NULL, 	   
	   perms bigint NOT NULL, 
	   langid int,
	   fts tsvector,
	   CONSTRAINT pk_tt_dup_tasks PRIMARY KEY (src, num)
	) ON COMMIT DROP;
	CREATE INDEX ix_tt_dup_tasks_deep ON _dup_tasks_name(deep);
	CREATE INDEX ix_tt_dup_tasks_src ON _dup_tasks_name(src);
	CREATE INDEX ix_tt_dup_tasks_dst ON _dup_tasks_name(dst);

	CREATE TEMP TABLE _dup_refs_name
	(
	   num int NOT NULL,
	   src bigint NOT NULL,
	   dst bigint NOT NULL,
	   dst_parent bigint NOT NULL,
	   new_name text, 
	   CONSTRAINT pk_tt_dup_refs PRIMARY KEY (src, num)
	) ON COMMIT DROP;
	CREATE INDEX ix_tt_tt_dup_refs_src ON _dup_refs_name(src);
	CREATE INDEX ix_tt_tt_dup_refs_dst ON _dup_refs_name(dst);

	-- fill primary tasks
	for i in array_lower(tid, 1)..array_upper(tid, 1)
	loop
		_tid = tid[i];
		_rtid = "refResolve"(_tid);
		
		if(not "perm_IsTaskVisible"(_usid, _rtid))
		then
			raise exception 'You don''t have rights read task';
		end if;

		if(_punid is distinct from "getUnid"(_rtid))
		then
			raise exception '%', "msg"(116);
		end if;

		if _tid != _rtid
		then
			-- reference
			insert into _dup_refs_name(src, dst, dst_parent, new_name, num)
				values(_tid, "newID"(), pid, _name[i], i);
		else
			_lang = coalesce(_langid[i], (select langid from tasks where uid=_tid));
			
			if (_copy_prj)
			then
				insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts)
					values(_tid, pid, 0, _name[i], 1, _base_url, "perm"(_usid, _tid, 0), i
					, _lang, "ftsVector"(_name[i], coalesce(_lang, "ftsUniLang_byTask"(_tid))));
			else
				insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts)
					values(_tid, "newID"(), pid, _name[i], 1, _base_url, "perm"(_usid, _tid, 0), i
					, _lang, "ftsVector"(_name[i], coalesce(_lang, "ftsUniLang_byTask"(_tid))));
			end if;
		end if;
	end loop;

	_dup_mode = (exists (select 1 from _dup_tasks_name group by src having count(src)>1));
	_dup_perms = (_flags & 512)!=0;
	_dup_status = (_flags & 4096)!=0;

	raise notice 'flags: %', _flags;

	-- fill visisble sub-tasks
	if((_flags & 1)!=0)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_tid = tid[i];
			
			if not "refIs"(_tid) and "isTaskChild"(_tid, pid)
			then
				raise exception 'You can not copy task tree to its sub-task. (1)';
			end if;
		end loop;

		i = 1;
		loop
			insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts) 
				select tasks.uid, "newID"(), tt.dst, tasks.name, i+1, tt.url || tt.new_name || '/', "perm"(_usid, tasks.uid, 0), num, tasks.langid, tasks.fts
					from tasks join _dup_tasks_name as tt on tasks.lnk_front_parent=tt.src
					where tt.deep=i and (tasks.flags & 1)=0 and ("perm"(_usid, tasks.uid, 0) & _perm_mask) = _perm_mask
					order by seq_order;

			--raise notice 'found = %', FOUND;
			_found = FOUND;

			insert into _dup_refs_name(src, dst, dst_parent, num) 
				select nav_links.uid, "newID"(), tt.dst, num
					from nav_links join _dup_tasks_name as tt on nav_links.parentid=tt.src
					where tt.deep=i -- and (tasks.flags & 1)=0 and ("perm"(_usid, tasks.uid, 0) & _perm_mask) = _perm_mask
					order by seq_order;
			
			exit when not _found and not FOUND;
			i = i+1;
		end loop;
	end if;	

	raise notice 'do copy % tasks', (select count(1) from _dup_tasks_name);

	analyze _dup_tasks_name;
	analyze _dup_refs_name;

	---------------
	-- dup task body
	_full_dup = ((_flags & 8)!=0) and ((_flags & 16)!=0) and ((_flags & 32)!=0);
	
	if _full_dup
	then
		-- dup with event and attach
		insert into tasks(
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
		select 
				tt.dst, tt.new_name, tt.dst_parent, _prj_id, tt.url, _base_deep + tt.deep
				, _now, xmtm, _now, _usid, _usid
				, del, activityid
				, (case when _dup_status then progress else null end)				
				, (case when _dup_perms then flags else (flags & (~2)) end), priority	-- don't copy perm block flags
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary

				, (case when _dup_status then pr_cc_progress else null end) 
				, cc_last_event_tag

				, cp_cc_declared_time, cp_cc_approved_time, cp_cc_declared_total, cp_cc_approved_total
				, resource_declared, resource_approved,  resource_declared_total, resource_approved_total
				, (case when (perms & (1<<30))=0 then null else costs end)

				, cc_thumbnailes, cc_thumb_recent_id, cc_thumb_recent_mtm, cc_thumb_oldest_id
				, cc_thumb_oldest_mtm, cc_thumb_recent_group, cc_thumb_oldest_group

				, (case when _dup_status then status else null end)
				
				, "newSeqID"()
				, tt.langid, tt.fts

		from tasks join _dup_tasks_name as tt on tasks.uid = tt.src
		order by tt.dst; --deep; seems dst is better
	else
		-- dup tasks only
		insert into tasks(
				uid, name, lnk_front_parent, prj_id, cc_url, cc_level
				, mtm, xmtm, creationtime, muid,  creatoruserid
				, del, activityid, progress, flags, priority
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
				, costs
				, status, seq_order
				, langid, fts
			)
		select 
				tt.dst, tt.new_name, tt.dst_parent, _prj_id, tt.url, _base_deep + tt.deep
				, _now, xmtm, _now, _usid, _usid
				, del, activityid
				, (case when _dup_status then progress else null end)
				, (case when _dup_perms then flags else (flags & (~2)) end), priority -- don't copy perm block flags
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
				, (case when (perms & (1<<30))=0 then null else costs end)
				, (case when _dup_status then status else null end)
				, "newSeqID"()
				, tt.langid, tt.fts
		from tasks join _dup_tasks_name as tt on tasks.uid = tt.src
		order by tt.dst; --deep; seems dst is better
	end if;

	----------------
	-- dup refs
	insert into nav_links(
			uid, name, parentid, taskid, flags, seq_order
		)
	select 
			tt.dst, tt.new_name, tt.dst_parent, taskid, flags, "newSeqID"()
		from nav_links join _dup_refs_name as tt on nav_links.uid = tt.src
		order by tt.dst;

	----------------
	-- dup tags
	if((_flags & 2)!=0)
	then
		--perform "perm_checkTask"(pid, 'tag', null);
		
		insert into tag_val_enum(taskid, tagid, enumid)
				select   tt.dst, tagid, enumid
				from tag_val_enum join _dup_tasks_name as tt on tag_val_enum.taskid = tt.src
				where del=0;

		insert into tag_val_scalar(taskid, tagid, ival, rval, sval)
				select     tt.dst, tagid, ival, rval, sval
				   from tag_val_scalar join _dup_tasks_name as tt on tag_val_scalar.taskid = tt.src
				   where del=0;
	end if;

	----------------
	-- dup user ass
	if((_flags & 4)!=0)
	then
		if((_flags & 1024)!=0)
		then
			perform "userAssignmentSet"(userid, tt.dst, true)
					from users_tasks join _dup_tasks_name as tt on users_tasks.taskid = tt.src
					where 
						(assigned_perc is not null) 
						and "isUserInUniverse"(userid, _pid_unid);
		else
			insert into users_tasks(userid,  taskid, interrest, assigned_perc)
				select             userid,  tt.dst, interrest, assigned_perc
					from users_tasks join _dup_tasks_name as tt on users_tasks.taskid = tt.src
					where 
						(assigned_perc is not null)
						and "isUserInUniverse"(userid, _pid_unid);
		end if;			
  	end if;

	perform "billCheckTaskCount"("getUnid"(pid));

	----------------
	-- dup subscripton
	if((_flags & 2048)!=0)
	then
		insert into users_tasks(userid,  taskid, interrest)
			select             userid,  tt.dst, interrest
				from users_tasks join _dup_tasks_name as tt on users_tasks.taskid = tt.src
				where 
					(assigned_perc is null)
					and (interrest is not null)
					and "isUserInUniverse"(userid, _pid_unid);				
  	end if;

	perform "billCheckTaskCount"("getUnid"(pid));

	----------------
	-- dup events
	if((_flags & 8)!=0)
	then
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

		/*insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
			select dst, events.uid, "newID"(), null, 1, events.tag, num
			from events join _dup_tasks_name on src=events.taskid
			where events.parenteventid is null and del=0 and events.tag!=6 -- status events --and tag=0
		;

		if((_flags & 16)!=0)
		then
			i = 1;
			loop
				insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
					select tt.tid, events.uid, "newID"(), dst, i+1, events.tag, num
					from events join tt_dup_events as tt on src=events.parenteventid
						where tt.deep=i and events.del=0 and events.tag!=6 -- status events
						order by tt.src;

				--raise notice 'found = %', FOUND;

				exit when not FOUND;
				i = i + 1;
			end loop;

			analyze tt_dup_events;
		end if;*/
																					
		if((_flags & 16)!=0)
		then
			insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
				select dst, events.uid, "newID"(), null, 0, events.tag, num
				from events join _dup_tasks_name on src=events.taskid
				where del=0
				order by events.uid
			;			
			--analyze tt_dup_events;
		else
			insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
				select dst, events.uid, "newID"(), null, 0, events.tag, num
				from events join _dup_tasks_name on src=events.taskid
				where events.parenteventid is null and del=0 and events.tag=0
				order by events.uid
			;							 
		end if;																			

		if exists (select 1 from tt_dup_events where tagid=0) then perform "perm_checkTask"(pid, 'ev_def', null); end if;
		if exists (select 1 from tt_dup_events where tagid=2) then perform "perm_checkTask"(pid, 'ev_rep', null); end if;
		if exists (select 1 from tt_dup_events where tagid=1) then perform "perm_checkTask"(pid, 'ev_rev', null); end if;
		if exists (select 1 from tt_dup_events where tagid=3) then perform "perm_checkTask"(pid, 'ev_msg', null); end if;
		if exists (select 1 from tt_dup_events where tagid=4) then perform "perm_checkTask"(pid, 'ev_clrev', null); end if;
		if exists (select 1 from tt_dup_events where tagid=5) then perform "perm_checkTask"(pid, 'ev_rep', null); end if;

		-- events
		insert into events(uid,  taskid, parenteventid, del, tag, worktime, flags, "text", mtm, xmtm,  muid, creationtime, creatoruserid, statusid, langid, fts)
			select       tt.dst, tt.tid,    dst_parent, del, tag, worktime, flags, "text", mtm, xmtm, _usid, _now,         creatoruserid, statusid, langid, fts
			from events join tt_dup_events as tt on events.uid = tt.src
			order by events.creationtime
			;

		-- attach
		if((_flags & 32)!=0)
		then
			insert into attachments(eventid, groupid, hash, tag, filesize, originalfilename, description, mtm, del, creationtime)
				select           tt.dst, groupid, hash, tag, filesize, originalfilename, description, mtm, del, _now
				from attachments join tt_dup_events as tt on eventid = tt.src
				where del=0;
		end if;

		raise notice 'do copy % events', (select count(1) from tt_dup_events);

	end if;

	-- internal links
	if((_flags & 64)!=0)
	then
		--CREATE INDEX ix_tt_dup_tasks_num ON _dup_tasks_name(num);

		if(_dup_mode)
		then
			for i in array_lower(tid, 1)..array_upper(tid, 1)
			loop
				insert into links(src,    dst, flags, percent)
					select ta.dst, tb.dst, flags, percent
					from links  
						join _dup_tasks_name as ta on links.src=ta.src 
						join _dup_tasks_name as tb on links.dst=tb.src 
					where del=0 and ta.num=i and tb.num=i;
			end loop;
		else
			insert into links(src,    dst, flags, percent)
				select ta.dst, tb.dst, flags, percent
				from links  
					join _dup_tasks_name as ta on links.src=ta.src 
					join _dup_tasks_name as tb on links.dst=tb.src 
				where del=0;
		end if;
	end if;

	-- external links src
	if((_flags & 128)!=0)
	then
		insert into links(src,       dst, flags, percent)
			select ta.dst, links.dst, flags, percent
			from links
				join _dup_tasks_name as ta on links.src=ta.src 
			where del=0 and not exists (select 1 from _dup_tasks_name where src=links.dst);
	end if;

	-- external links dst
	if((_flags & 256)!=0)
	then
		insert into links(  src,     dst, flags, percent)
			select links.src, tb.dst, flags, percent
			from links 
				join _dup_tasks_name as tb on links.dst=tb.src 
			where del=0 and not exists (select 1 from _dup_tasks_name where src=links.src);
	end if;

	-- perms
	if((_flags & 512)!=0)
	then
		insert into perm_groups(mtm,  muid, groupid, taskid, privileg, flags)
				select _now, _usid, groupid, tt.dst, privileg, flags
				from perm_groups join _dup_tasks_name as tt on taskid = tt.src;

		insert into perm_users( mtm,  muid, userid, taskid, privileg, flags)
				select _now, _usid, userid, tt.dst, privileg, flags
				from perm_users join _dup_tasks_name as tt on taskid = tt.src;
	end if;

	if (not _full_dup)
	then
		perform "thumbRegenTask"(dst) from _dup_tasks_name order by deep desc;
		UPDATE tasks set cc_last_event_tag = "getLastEventTag"(uid) 
			WHERE uid in (select dst from _dup_tasks_name);
	end if;

	perform "touchTask"(pid, 2 | 16 | 8192 | 262144, null);

	--raise exception 'all fine';

	return query 
			(select dst from _dup_tasks_name) union (select dst from _dup_refs_name);
		--select count(1) from _dup_tasks_name group by deep order by deep; --limit 10;
END

$BODY$;


-- FUNCTION: public."dupVTask_CrossUni"(bigint[], text[], bigint, integer, integer[])

-- DROP FUNCTION public."dupVTask_CrossUni"(bigint[], text[], bigint, integer, integer[]);

CREATE OR REPLACE FUNCTION public."dupVTask_CrossUni"(
	tid bigint[],
	_name text[],
	_pid bigint,
	_flags integer,
	_langid integer[])
    RETURNS SETOF bigint 
    LANGUAGE 'plpgsql'

    COST 10000
    VOLATILE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$

DECLARE 
	pid 	bigint = _pid;
	i	integer;
	_tid 	bigint;
	_prj_id bigint;
	_base_deep integer;
	_base_url text;
	_usid	integer = get_usid();
	_lnk	links;
	_full_dup boolean;
	_now timestamp with time zone = now();
	_perm_mask bigint = (1 | (1<<12)); -- | (1<<30) costs ???
	_punid	int;
	_lang	int;
	_copy_prj boolean;
	_dup_mode boolean;
	_dup_perms boolean;
	_dup_status boolean;
	
	_seed int = nextval('del_seq');
	_dup_tasks_name	text = 'tt_dup_tasks_' || _seed;
BEGIN
/*
1   - sub tasks
2 (N/A)  - tags
4 (PARTIALLY) - assigned users
8   - events (by default only null parented)
16  	-  full event copy
32 - atachments
64 - internal links
128 (N/A) - external links 1
256 (N/A) - external links 2
512 (N/A) - permissions
1024 (N/A) - assign users full protocol with notified (may be slow)
2048 (N/A) - subscription
4096 (only progress) - status and progress
*/

	if "refIs"(_pid)
	then
		raise exception '%', "msg"(115);
	end if;

	select cc_level, cc_url || "name" || '/', prj_id into _base_deep, _base_url, _prj_id from tasks where uid=_pid;

	-- is pid a task
	if(_prj_id is null)
	then
		select uid, root_task, unid into _prj_id, pid, _punid from projects where uid=_pid;

		if(pid is null or array_lower(tid, 1)!=0 or array_upper(tid, 1)!=0)
		then
			raise exception 'Invalid arguments';
		end if;

		perform "perm_checkTask"(0, 'mng_task', _punid);
		perform "perm_checkTask"(0, 'task_prop', _punid);

		_copy_prj = true;
		_base_deep = -1;
		_base_url = '/';
		
	else
		_copy_prj = false;
		_punid = "getUnid"(pid);
		
		perform "perm_checkTask"(pid, 'mng_task', null);
		perform "perm_checkTask"(pid, 'task_prop', null);
	end if;

	if not "isUserInUniverse"(_usid, _punid) 
	then 
		raise exception 'You do not belong the destination universe';
	end if;

	CREATE TEMP TABLE _dup_tasks_name
	(
	   num int NOT NULL,
	   src bigint NOT NULL,
	   dst bigint NOT NULL,
	   dst_parent bigint NOT NULL,
	   new_name text NOT NULL, 
	   deep integer NOT NULL, 
	   url text NOT NULL, 
	   perms bigint NOT NULL,
	   langid int,
	   fts tsvector,
	   CONSTRAINT pk_tt_dup_tasks PRIMARY KEY (src, num)
	) ON COMMIT DROP;

	CREATE INDEX ix_tt_dup_tasks_deep ON _dup_tasks_name(deep);
	CREATE INDEX ix_tt_dup_tasks_src ON _dup_tasks_name(src);

	-- fill primary tasks
	if not ((array_dims(tid) is not NULL) and (array_dims(_name) is not NULL) and array_dims(tid) = array_dims(_name))
	then
		return;
	end if;
	
	for i in array_lower(tid, 1)..array_upper(tid, 1)
	loop
		if "refIs"(tid[i])
		then
			raise exception '%', "msg"(115);
		end if;
		
		_tid = tid[i];
		
		if(not "perm_IsTaskVisible"(_usid, _tid))
		then
			raise exception 'You don''t have rights read task';
		end if;

--		if(_punid != "getUnid"(_tid))
--		then
--			raise exception 'Inter-Universionary duplication is forbidden';
--		end if;

		_lang = coalesce(_langid[i], (select langid from tasks where uid=_tid));
		if(_copy_prj)
		then
			insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts)
				values(tid[i], pid, 0, _name[i], 1, _base_url, "perm"(_usid, tid[i], 0), i
					, _lang, "ftsVector"(_name[i], coalesce(_lang, "ftsUniLang_byTask"(_tid))));
		else
			insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts)
				values(tid[i], "newID"(), pid, _name[i], 1, _base_url, "perm"(_usid, tid[i], 0), i
					, _lang, "ftsVector"(_name[i], coalesce(_lang, "ftsUniLang_byTask"(_tid))));
		end if;
	end loop;

	_dup_mode = (exists (select 1 from _dup_tasks_name group by src having count(src)>1));
	_dup_perms = (_flags & 512)!=0;
	_dup_status = (_flags & 4096)!=0;

	raise notice 'flags: %', _flags;

	-- fill visisble sub-tasks
	if((_flags & 1)!=0)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_tid = tid[i];
			
			if("isTaskChild"(_tid, pid))
			then
				raise exception 'You can not copy task tree to its sub-task. (1)';
				rollback;
			end if;
		end loop;

		i = 1;
		loop
			insert into _dup_tasks_name(src, dst, dst_parent, new_name, deep, url, perms, num, langid, fts) 
				select tasks.uid, "newID"(), tt.dst, tasks.name, i+1, tt.url || tt.new_name || '/', "perm"(_usid, tasks.uid, 0), num, tasks.langid, tasks.fts
					from tasks join _dup_tasks_name as tt on tasks.lnk_front_parent=tt.src
					where tt.deep=i and (tasks.flags & 1)=0 and ("perm"(_usid, tasks.uid, 0) & _perm_mask) = _perm_mask
					order by seq_order;

			--raise notice 'found = %', FOUND;
			exit when not FOUND;
			i = i+1;
		end loop;
	end if;	

	raise notice 'do copy % tasks', (select count(1) from _dup_tasks_name);

	analyze _dup_tasks_name;

	---------------
	-- dup task body
	_full_dup = ((_flags & 8)!=0) and ((_flags & 16)!=0) and ((_flags & 32)!=0);
	
	if _full_dup
	then
		-- dup with event and attach
		insert into tasks(
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
		select 
				tt.dst, tt.new_name, tt.dst_parent, _prj_id, tt.url, _base_deep + tt.deep
				, _now, xmtm, _now, _usid, (case when "isUserInUniverse"(creatoruserid, _punid) then creatoruserid else _usid end)
				, del, 0
				, (case when _dup_status then progress else null end)
				, (case when _dup_perms then flags else (flags & (~2)) end), priority	-- don't copy perm block flags
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary

				, pr_cc_progress, cc_last_event_tag

				, cp_cc_declared_time, cp_cc_approved_time, cp_cc_declared_total, cp_cc_approved_total
				, resource_declared, resource_approved,  resource_declared_total, resource_approved_total
				, (case when (perms & (1<<30))=0 then null else costs end)

				, cc_thumbnailes, cc_thumb_recent_id, cc_thumb_recent_mtm, cc_thumb_oldest_id
				, cc_thumb_oldest_mtm, cc_thumb_recent_group, cc_thumb_oldest_group

				, NULL, "newSeqID"()
				, tt.langid, tt.fts

		from tasks join _dup_tasks_name as tt on tasks.uid = tt.src
		order by tt.deep;
	else
		-- dup tasks only
		insert into tasks(
				uid, name, lnk_front_parent, prj_id, cc_url, cc_level
				, mtm, xmtm, creationtime, muid,  creatoruserid
				, del, activityid, progress, flags, priority
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
				, costs
				, status, seq_order
				, langid, fts
			)
		select 
				tt.dst, tt.new_name, tt.dst_parent, _prj_id, tt.url, _base_deep + tt.deep
				, _now, xmtm, _now, _usid, (case when "isUserInUniverse"(creatoruserid, _punid) then creatoruserid else _usid end)
				, del, 0
				, (case when _dup_status then progress else null end)
				, (case when _dup_perms then flags else (flags & (~2)) end), priority -- don't copy perm block flags
				, cp_fixed, cp_weight, tg_offset, tg_stop, cp_salary
				, (case when (perms & (1<<30))=0 then null else costs end)
				, NULL, "newSeqID"()
				, tt.langid, tt.fts

		from tasks join _dup_tasks_name as tt on tasks.uid = tt.src
		order by tt.deep;
	end if;

	----------------
	-- dup tags

	----------------
	-- dup user ass
	if((_flags & 4)!=0)
	then
		insert into users_tasks(userid,  taskid, assigned_perc)
		     select             userid,  tt.dst, assigned_perc
			from users_tasks join _dup_tasks_name as tt on users_tasks.taskid = tt.src
			where 
				(assigned_perc is not null)
				and "isUserInUniverse"(userid, _punid);
  	end if;

	perform "billCheckTaskCount"("getUnid"(pid));

	----------------
	-- dup events
	if((_flags & 8)!=0)
	then
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

		/*insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
			select dst, events.uid, "newID"(), null, 1, events.tag, num
			from events join _dup_tasks_name on src=events.taskid
			where events.parenteventid is null and del=0 and events.tag!=6 -- status events --and tag=0
		;

		if((_flags & 16)!=0)
		then
			i = 1;
			loop
				insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
					select tt.tid, events.uid, "newID"(), dst, i+1, events.tag, num
					from events join tt_dup_events as tt on src=events.parenteventid
						where tt.deep=i and events.del=0 and events.tag!=6 -- status events
						order by tt.src;

				--raise notice 'found = %', FOUND;

				exit when not FOUND;
				i = i + 1;
			end loop;

			analyze tt_dup_events;
		end if;*/
																					
		if((_flags & 16)!=0)
		then
			insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
				select dst, events.uid, "newID"(), null, 0, events.tag, num
				from events join _dup_tasks_name on src=events.taskid
				where del=0 and events.tag!=6
				order by events.uid
			;			
			--analyze tt_dup_events;
		else
			insert into tt_dup_events(tid, src, dst, dst_parent, deep, tagid, num)
				select dst, events.uid, "newID"(), null, 0, events.tag, num
				from events join _dup_tasks_name on src=events.taskid
				where events.parenteventid is null and del=0 and events.tag=0
				order by events.uid
			;							 
		end if;

		if exists (select 1 from tt_dup_events where tagid=0) then perform "perm_checkTask"(pid, 'ev_def', null); end if;
		if exists (select 1 from tt_dup_events where tagid=2) then perform "perm_checkTask"(pid, 'ev_rep', null); end if;
		if exists (select 1 from tt_dup_events where tagid=1) then perform "perm_checkTask"(pid, 'ev_rev', null); end if;
		if exists (select 1 from tt_dup_events where tagid=3) then perform "perm_checkTask"(pid, 'ev_msg', null); end if;
		if exists (select 1 from tt_dup_events where tagid=4) then perform "perm_checkTask"(pid, 'ev_clrev', null); end if;
		if exists (select 1 from tt_dup_events where tagid=5) then perform "perm_checkTask"(pid, 'ev_rep', null); end if;

		-- events
		insert into events(uid,  taskid, parenteventid, del, tag, worktime, flags, "text", mtm, xmtm,  muid, creationtime
			, creatoruserid
			, statusid, langid, fts
		)
			select       tt.dst, tt.tid,    dst_parent, del, tag, worktime, flags, "text", mtm, xmtm, _usid, _now
				, (case when "isUserInUniverse"(creatoruserid, _punid) then creatoruserid else _usid end)
				, NULL, langid, fts
			from events join tt_dup_events as tt on events.uid = tt.src
			order by events.creationtime
			;

		-- attach
		if((_flags & 32)!=0)
		then
			insert into attachments(eventid, groupid, hash, tag, filesize, originalfilename, description, mtm, del, creationtime)
				select           tt.dst, groupid, hash, tag, filesize, originalfilename, description, mtm, del, _now
				from attachments join tt_dup_events as tt on eventid = tt.src
				where del=0;
		end if;

		raise notice 'do copy % events', (select count(1) from tt_dup_events);

	end if;

	-- internal links
	if((_flags & 64)!=0)
	then
		--CREATE INDEX ix_tt_dup_tasks_num ON _dup_tasks_name(num);

		if(_dup_mode)
		then
			for i in array_lower(tid, 1)..array_upper(tid, 1)
			loop
				insert into links(src,    dst, flags, percent)
					select ta.dst, tb.dst, flags, percent
					from links  
						join _dup_tasks_name as ta on links.src=ta.src 
						join _dup_tasks_name as tb on links.dst=tb.src 
					where del=0 and ta.num=i and tb.num=i;
			end loop;
		else
			insert into links(src,    dst, flags, percent)
				select ta.dst, tb.dst, flags, percent
				from links  
					join _dup_tasks_name as ta on links.src=ta.src 
					join _dup_tasks_name as tb on links.dst=tb.src 
				where del=0;
		end if;
	end if;

	-- external links src
	-- external links dst
	-- perms

	if (not _full_dup)
	then
		perform "thumbRegenTask"(dst) from _dup_tasks_name order by deep desc;
		UPDATE tasks set cc_last_event_tag = "getLastEventTag"(uid) 
			WHERE uid in (select dst from _dup_tasks_name);
	end if;

	perform "touchTask"(pid, 2 | 16 | 8192 | 262144, null);

	--raise exception 'all fine';

	return query 
		select dst from _dup_tasks_name;
		--select count(1) from _dup_tasks_name group by deep order by deep; --limit 10;
END

$BODY$;
