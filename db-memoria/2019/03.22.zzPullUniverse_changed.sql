-- select * from universes where name ilike 'Schoo%' --6803
-- select "zzPullUniverse"('Industry', 'dbname=memoria port=45432');
-- select * from users where uid=4
-- update users set lid='admin' where uid=4;
-- select "userSetPassword"('apjcdjpcb@emlpro.com', 'dQMewp'); -- mem2
-- select "userSetPassword"('apjcdjpcb@emlpro.com', 'fuGasx'); -- mem3

/*
delete from archive_ht_task as ht       where tagid not in (select uid from ht_schema);
delete from archive_ht_event as ht      where tagid not in (select uid from ht_schema);
delete from archive_ht_attachment as ht where tagid not in (select uid from ht_schema);
*/

CREATE OR REPLACE FUNCTION public."zzPullUniverse"(
	_uname character varying,
	_conn_string text)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT 
AS $BODY$
-- e.g. select "zzPullUniverse"('Chain-FX', 'host=cerebrohq.com port=45432 dbname=memoria user=sa password=<passwd>');
declare
	_unid 		integer;
	_user_id	integer;
	_seq_val	bigint;
	_ret		boolean;
begin
	if(not "isUserShepherd_bySession"())
	then
		raise exception 'You must be Shepherd';
	end if;

	perform dblink_connect(_conn_string);

	select * into _unid from dblink('select uid from universes where "name" = ''' || _uname || ''';') AS t(uid int);
	if(_unid is null)
	then
		raise exception 'Invalid Universe';
	end if;

    raise notice 'pulling universe:%', _unid;
	   

	--SET SESSION session_replication_role = replica;
	INSERT INTO users(mtm, del, uid, creationtime, email, icq, phone, lid, langid, emit_start
	, emit_assign, emit_interest, multilogin, spam_sent_time, spam_stage, flags, firstname, lastname
	, delete_unwatched_age, randid, avatar_hash, local_time_offset , emit_schedule, emit_cando, ad_sid,
	ldap_dn, ldap_login, ldap_email)
		select * from
			dblink('
				select u.* 
				from users as u
				where
					u.uid > 10
					and u.uid in (select distinct(uu) from "zzPullUniverse_UserList"(' || _unid || ', true) as uu)
			')
			AS t(
				mtm timestamp with time zone,
				del smallint,
				uid int,
				creationtime timestamp with time zone,
				email character varying,
				icq character varying,
				phone character varying,
				lid name,
				langid integer,
				emit_start timestamp with time zone,
				emit_assign integer,
				emit_interest integer,
				multilogin boolean,
				spam_sent_time timestamp with time zone,
				spam_stage integer,
				flags integer,
				firstname text,
				lastname text,
				delete_unwatched_age integer,
				randid integer,
				avatar_hash text,
				local_time_offset real,
				emit_schedule interval,
				emit_cando integer,
				ad_sid text,
				ldap_dn text,
				ldap_login text,
				ldap_email text
			)
		where t.uid not in (select uid from users);

		--(DROP_ROLE)
		-- for _ret in (select * from
		-- 	dblink('select u.lid, auth.rolpassword from users as u join users_universes as uu on uu.userid=u.uid join pg_authid as auth on auth.rolname=lid where u.uid>10 and (ad_sid is null) and (lid is not null) and uu.del=0 and uu.unid = ' || _unid || ';')
		-- 	AS t(lid name, pswd text))
		-- loop
		-- 	EXECUTE 'CREATE ROLE ' || _ret.lid || ' WITH LOGIN INHERIT ENCRYPTED PASSWORD ' || _ret.pswd;
		-- 	raise notice '... created role: %', _ret.lid;
		-- end loop;

		INSERT INTO web_auth(mtm, usid, salt, hash)
			select * from
				dblink('select 
					wa.* from 
						web_auth as wa 
							join users as u on wa.usid = u.uid
						where u.uid > 10 and u.uid in (select distinct(uu) from "zzPullUniverse_UserList"(' || _unid || ', true) as uu)
				')
				AS t(
					mtm timestamp with time zone,
					usid integer,
					salt text,
					hash text
				)
			where t.usid not in (select usid from web_auth);
	   
	   /* do need copy Long-tokens ?
	   INSERT INTO users_web_sids(mtm, usid, sid, client_type, expire_at, client_ip, flags)
			select * from
				dblink('select wa.* from users_web_sids as wa join users as u on wa.usid=u.uid join users_universes as uu on uu.userid=u.uid where u.uid>10 and uu.unid = ' || _unid || ';')
				AS t(
					mtm timestamp with time zone,
					usid integer,
					sid character varying,
					client_type integer,
					expire_at timestamp with time zone,
					client_ip text,
					flags integer
				)
			where t.usid not in (select usid from users_web_sids);
	    raise notice 'users done';*/

		INSERT INTO universes(mtm, del, uid, creationtime, creatoruserid, name
		, description, muid, lang, bill_last_kolbasa_check, bill_maxlogins
		, bill_maxtask, multilogin, tasks_mtm, acl_mtm, email_anihilate_sent, spam_round, flags, status_null_perms
		, email_lowsize_sent, "~ht_mtm")
		select * from
			dblink('select * from universes where uid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				del smallint,
				uid integer,
				creationtime timestamp with time zone,
				creatoruserid integer,
				name character varying,
				description character varying,
				muid integer,
				lang integer,
				bill_last_kolbasa_check date,
				bill_maxlogins integer,
				bill_maxtask bigint,
				multilogin boolean,
				tasks_mtm timestamp with time zone,
				acl_mtm timestamp without time zone,
				email_anihilate_sent timestamp with time zone,
				spam_round integer,
				flags integer,
				status_null_perms bigint,
				email_lowsize_sent timestamp with time zone,
				"~ht_mtm" timestamp with time zone);

	INSERT INTO attrib_universe(unid, key, val)
		select * from
			dblink('select * from attrib_universe where unid = ' || _unid || ';')
			AS t(
				unid integer,
				key integer,
				val text);
	   
	 INSERT INTO users_universes(mtm, userid, unid, flags, del)
		select * from
			dblink('select * from users_universes where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				userid integer,
				unid integer,
				flags integer,
				del smallint);

	-- mark users who do not work but worked for this Universe as deleted
	/*
	update users as u
		set lid = null
	where
		u.uid>10
		and coalesce((select del!=0 from users_universes as uu where uu.unid = _unid and userid = u.uid), true);
	*/
		
    raise notice 'universe done';

	INSERT INTO sites(mtm, muid, uid, dns_name, name, unid, size_quota, storageid, nativeport, webport, localaddr
			, ssl_client_cert, size_used)
		select * from
			dblink('select * from sites where "unid" = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				dns_name character varying,
				name character varying,
				unid integer,
				size_quota bigint,
				storageid integer,
				nativeport integer,
				webport integer,
				localaddr text,
				ssl_client_cert text,
				size_used bigint);
				
	INSERT INTO plugins(mtm, uid, "name", "desc", flags, unid, del, title)
		select * from
			dblink('select * from plugins where unid = ' || _unid || ';')
			AS t(
				  mtm timestamp with time zone,
				uid bigint,
				name character varying,
				"desc" character varying,
				flags integer,
				unid integer,
				del smallint,
				title character varying
  				);
				
	INSERT INTO plugins_versions(ctm, uid, pluginid, flags, version_str, hash, comment)
		select * from
			dblink('select x.* from plugins_versions as x join plugins as p on x.pluginid=p.uid where unid = ' || _unid || ';')
			AS t(
				  ctm timestamp with time zone,
				uid bigint,
				pluginid bigint,
				flags integer,
				version_str character varying,
				hash character(64),
				comment character varying
    				);

	INSERT INTO status(uid, "name", flags, order_no, description, icon_xpm, color, unid, perm_leave_bits, perm_enter_bits, mtm, icon_hash)
		select * from
			dblink('select * from status where unid = ' || _unid || ';')
			AS t(
				  uid bigint,
				  "name" text,
				  flags integer,
				  order_no integer,
				  description text,
				  icon_xpm text,
				  color integer,
				  unid integer,
				  perm_leave_bits integer,
				  perm_enter_bits integer,
					mtm timestamp with time zone,
				  icon_hash text
  				);

	INSERT INTO status_rules(uid, order_no, unid, flags, result_status)
		select * from
			dblink('select * from status_rules where unid = ' || _unid || ';')
			AS t(
				uid bigint,
				order_no integer,
				unid integer,
				flags integer,
				result_status bigint
				);

	INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
		select * from
			dblink('select sc.* from status_cond as sc join status_rules as sr on sc.ruleid=sr.uid where unid = ' || _unid || ';')
			AS t(
				  ruleid bigint,
				  order_no integer,
				  flags integer,
				  var integer,
				  op integer,
				  cmp_status bigint
    				);

	INSERT INTO activitytypes(mtm, muid, del, uid, name, creatoruserid, cp_default_weight, unid, color)
		select * from
			dblink('select * from activitytypes where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				name character varying,
				creatoruserid integer,
				cp_default_weight real,
				unid integer,
				color integer);

	INSERT INTO users_activities(mtm, muid, userid, activityid)
		select * from
			dblink('select ua.* from users_activities as ua join activitytypes as a on activityid=a.uid where a.unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				activityid bigint);

	INSERT INTO status_activities(mtm, muid, flags, statusid, activityid)
		select * from
			dblink('select ua.* from status_activities as ua join activitytypes as a on activityid=a.uid where a.unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				flags integer,
				statusid bigint,
				activityid bigint);

	INSERT INTO projects(uid, cc_thumbnailes, root_task, approve_time_calc_mode, unid, flags, default_task_duration)
		select * from
			dblink('select * from projects where unid = ' || _unid || ';')
			AS t(
				uid bigint,
				cc_thumbnailes character varying,
				root_task bigint,
				approve_time_calc_mode integer,
				unid integer,
				flags integer,
				default_task_duration real
			);
			
	INSERT INTO attrib_user(usid, key, val)
			select * from
				dblink('select au.* from attrib_user as au join users as u on au.usid=u.uid join users_universes as uu on uu.userid=u.uid where u.uid>10 and uu.unid = ' || _unid || ';')
				AS t(
					usid integer,
					key integer,
					val text
				)
			where t.usid not in (select usid from attrib_user);

    raise notice 'statuses, activities, sites done';
	
	INSERT INTO tasks(
				mtm, muid, del, uid, creationtime, creatoruserid, name, activityid,
				progress, lnk_front_parent, cp_fixed, cp_weight, cp_cc_child_fixed,
				cp_cc_child_fixed_sum, cp_cc_reserve, tg_duration, cp_salary,
				priority, pr_cc_progress, cp_cc_declared_time, cp_cc_approved_time,
				cp_cc_declared_total, cp_cc_approved_total, cp_cc_sum_fixed_min,
				cc_thumbnailes, xmtm, prj_id, cc_url, cc_last_event_tag, cc_level,
				tg_cc_dur, tg_cc_ofs, flags, cc_thumb_recent_id, cc_thumb_recent_mtm,
				cc_thumb_oldest_id, cc_thumb_oldest_mtm, cc_thumb_recent_group,
				cc_thumb_oldest_group, tg_offset, tg_stop, costs, cc_costs, cc_pays,
				cc_pays_total, resource_declared, resource_approved, resource_declared_total,
				resource_approved_total, seq_order, status, cc_status, cc_status_stat, fts,
				langid, tg_mtm_cc)
		select
			t.mtm, t.muid, t.del, t.uid, t.creationtime, t.creatoruserid, t.name, t.activityid,
			t.progress, t.lnk_front_parent, t.cp_fixed, t.cp_weight, t.cp_cc_child_fixed,
			t.cp_cc_child_fixed_sum, t.cp_cc_reserve, t.tg_duration, t.cp_salary,
			t.priority, t.pr_cc_progress, t.cp_cc_declared_time, t.cp_cc_approved_time,
			t.cp_cc_declared_total, t.cp_cc_approved_total, t.cp_cc_sum_fixed_min,
			t.cc_thumbnailes, t.xmtm, t.prj_id, t.cc_url, t.cc_last_event_tag, t.cc_level,
			t.tg_cc_dur, t.tg_cc_ofs, t.flags, t.cc_thumb_recent_id, t.cc_thumb_recent_mtm,
			t.cc_thumb_oldest_id, t.cc_thumb_oldest_mtm, t.cc_thumb_recent_group,
			t.cc_thumb_oldest_group, t.tg_offset, t.tg_stop, t.costs, t.cc_costs, t.cc_pays,
			t.cc_pays_total, t.resource_declared, t.resource_approved, t.resource_declared_total,
			t.resource_approved_total, "newSeqID"(), t.status, t.cc_status, t.cc_status_stat,
			t.fts, t.langid, t.tg_mtm_cc
			from
			dblink('select t.* from tasks as t join projects as p on t.prj_id=p.uid where p.unid = ' || _unid || ' order by seq_order;')
			AS t(
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
			);
			
			raise notice 'tasks done';
			
			INSERT INTO archive_tasks(
				mtm, muid, del, uid, creationtime, creatoruserid, name, activityid,
				progress, lnk_front_parent, cp_fixed, cp_weight, tg_duration, cp_salary,
				priority, xmtm, prj_id, flags, tg_offset, tg_stop, costs, status, seq_order,
				langid)
		select
			t.mtm, t.muid, t.del, t.uid, t.creationtime, t.creatoruserid, t.name, t.activityid,
			t.progress, t.lnk_front_parent, t.cp_fixed, t.cp_weight,
			t.tg_duration, t.cp_salary,
			t.priority, t.xmtm, t.prj_id, t.flags, t.tg_offset, t.tg_stop, t.costs, t.status, "newSeqID"(), t.langid
			from
			dblink('select t.* from archive_tasks as t join projects as p on t.prj_id=p.uid where p.unid = ' || _unid || ' order by seq_order;')
			AS t(
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
				tg_duration real,
				cp_salary real,
				priority smallint,
				xmtm timestamp with time zone,
				prj_id bigint,
				flags integer,
				tg_offset double precision,
				tg_stop double precision,
				costs double precision,
				status bigint,
				seq_order double precision,
				langid integer
			);
			
			raise notice 'atchive tasks done';

	INSERT INTO links(mtm, muid, del, uid, src, dst, flags, percent)
		select * from
			dblink('select l.* from links as l
				join tasks as t1 on l.src=t1.uid join projects as p1 on t1.prj_id=p1.uid
				join tasks as t2 on l.dst=t2.uid join projects as p2 on t2.prj_id=p2.uid
				where p1.unid = ' || _unid || ' and p2.unid = ' || _unid || ';'
			)
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				src bigint,
				dst bigint,
				flags integer,
				percent real);
				
	INSERT INTO archive_links(mtm, muid, del, uid, src, dst, flags, percent)
		select * from
			dblink('select l.* from archive_links as l
				join archive_tasks as t1 on l.src=t1.uid join projects as p1 on t1.prj_id=p1.uid
				join archive_tasks as t2 on l.dst=t2.uid join projects as p2 on t2.prj_id=p2.uid
				where p1.unid = ' || _unid || ' and p2.unid = ' || _unid || ';'
			)
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				src bigint,
				dst bigint,
				flags integer,
				percent real);

	INSERT INTO nav_links(mtm, muid, parentid, taskid, flags, uid, name, seq_order)
		select * from
			dblink('select l.* from nav_links as l
				join tasks as t1 on l.parentid = t1.uid join projects as p1 on t1.prj_id=p1.uid
				join tasks as t2 on l.taskid = t2.uid join projects as p2 on t2.prj_id=p2.uid
				where p1.unid = ' || _unid || ' and p2.unid = ' || _unid || ';'
			)
			AS t(
				mtm timestamp with time zone,
				muid integer,
				parentid bigint,
				taskid bigint,
				flags integer,
				uid bigint,
				name text,
				seq_order double precision
			);
			
	INSERT INTO archive_nav_links(mtm, muid, parentid, taskid, flags, uid, name, seq_order)
		select * from
			dblink('select l.* from archive_nav_links as l
				join archive_tasks as t1 on l.parentid = t1.uid join projects as p1 on t1.prj_id=p1.uid
				join archive_tasks as t2 on l.taskid = t2.uid join projects as p2 on t2.prj_id=p2.uid
				where p1.unid = ' || _unid || ' and p2.unid = ' || _unid || ';'
			)
			AS t(
				mtm timestamp with time zone,
				muid integer,
				parentid bigint,
				taskid bigint,
				flags integer,
				uid bigint,
				name text,
				seq_order double precision
			);
			
	raise notice 'links done';

	INSERT INTO events(mtm, muid, del, uid, creationtime, creatoruserid, taskid, tag, parenteventid, worktime, flags, text, xmtm, statusid, langid, fts, rating)
		select * from
			dblink('select e.* from events as e join tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
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
			);
			
	raise notice 'events done';
	
	INSERT INTO archive_events(mtm, muid, del, uid, creationtime, creatoruserid, taskid, tag, parenteventid, worktime, flags, text, xmtm, statusid, langid, rating)
		select * from
			dblink('select e.* from archive_events as e join archive_tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
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
				rating real
			);
			
	raise notice 'archive events done';

	INSERT INTO event_likes(mtm, eventid, userid, voice)
		select * from
			dblink('select a.* from event_likes as a join events as e on a.eventid=e.uid join tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				  eventid bigint,
				  userid integer,
				  voice boolean);
				 
	INSERT INTO archive_event_likes(mtm, eventid, userid, voice)
		select * from
			dblink('select a.* from archive_event_likes as a join archive_events as e on a.eventid=e.uid join archive_tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				  eventid bigint,
				  userid integer,
				  voice boolean);

				
	INSERT INTO attachments(mtm, eventid, del, groupid, creationtime, hash, tag, filesize, originalfilename, description, uid, flags)
		select * from
			dblink('select a.* from attachments as a join events as e on a.eventid=e.uid join tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
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
				flags integer);
				
	raise notice 'attachments done';
				
	INSERT INTO archive_attachments(mtm, eventid, del, groupid, creationtime, hash, tag, filesize, originalfilename, description, uid)
		select * from
			dblink('select a.* from archive_attachments as a join archive_events as e on a.eventid=e.uid join archive_tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
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
				uid bigint);
				
	raise notice 'archive attachments done';

	INSERT INTO tag_schema(mtm, muid, del, uid, datatype, name, unid)
		select * from
			dblink('select * from tag_schema where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				datatype integer,
				name character varying,
				unid integer);

	INSERT INTO tag_enums(mtm, muid, del, uid, tagid, sval)
		select * from
			dblink('select tve.* from tag_enums as tve join tag_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				uid bigint,
				tagid bigint,
				sval character varying);

	INSERT INTO tag_val_enum(mtm, muid, del, taskid, tagid, enumid)
		select * from
			dblink('select tve.* from tag_val_enum as tve join tag_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				taskid bigint,
				tagid bigint,
				enumid bigint);

	INSERT INTO tag_val_scalar(mtm, muid, del, taskid, tagid, ival, rval, sval)
		select * from
			dblink('select tve.* from tag_val_scalar as tve join tag_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				taskid bigint,
				tagid bigint,
				ival integer,
				rval real,
				sval character varying);
				
	INSERT INTO archive_tag_val_enum(mtm, muid, del, taskid, tagid, enumid)
		select * from
			dblink('select tve.* from archive_tag_val_enum as tve join tag_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				taskid bigint,
				tagid bigint,
				enumid bigint);

	INSERT INTO archive_tag_val_scalar(mtm, muid, del, taskid, tagid, ival, rval, sval)
		select * from
			dblink('select tve.* from archive_tag_val_scalar as tve join tag_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				taskid bigint,
				tagid bigint,
				ival integer,
				rval real,
				sval character varying);

	-- HT ---------
	INSERT INTO ht_schema(mtm, uid, flags, name, unid)
		select * from
			dblink('select * from ht_schema where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				uid bigint,
				flags integer,
				name text,
				unid integer);

	INSERT INTO ht_task(mtm, taskid, tagid)
		select * from
			dblink('select ht.* from ht_task as ht join ht_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				taskid bigint,
				tagid bigint);

	INSERT INTO ht_event(mtm, eventid, tagid)
		select * from
			dblink('select ht.* from ht_event as ht join ht_schema as ts on ht.tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				eventid bigint,
				tagid bigint);

	INSERT INTO ht_attachment(mtm, attachmentid, tagid)
		select * from
			dblink('select ht.* from ht_attachment as ht join ht_schema as ts on ht.tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				attachmentid bigint,
				tagid bigint);
	   
	raise notice 'tags done';
				
	INSERT INTO archive_ht_task(mtm, taskid, tagid)
		select * from
			dblink('select ht.* from archive_ht_task as ht join ht_schema as ts on ht.tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				taskid bigint,
				tagid bigint);

	INSERT INTO archive_ht_event(mtm, eventid, tagid)
		select * from
			dblink('select ht.* from archive_ht_event as ht join ht_schema as ts on ht.tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				eventid bigint,
				tagid bigint);

	INSERT INTO archive_ht_attachment(mtm, attachmentid, tagid)
		select * from
			dblink('select ht.* from archive_ht_attachment as ht join ht_schema as ts on ht.tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				attachmentid bigint,
				tagid bigint);
				
	raise notice 'archive tags done';

	-------------------
	INSERT INTO users_tasks(mtm, muid, userid, taskid, interrest, assigned_perc, flags)
		select * from
			dblink('select x.* from users_tasks as x join tasks as t on x.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				taskid bigint,
				interrest boolean,
				assigned_perc integer,
				flags smallint);
				
	INSERT INTO archive_users_tasks(mtm, userid, taskid, interrest, assigned_perc, flags)
		select * from
			dblink('select x.* from archive_users_tasks as x join archive_tasks as t on x.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				userid integer,
				taskid bigint,
				interrest boolean,
				assigned_perc integer,
				flags smallint);

	INSERT INTO tag_project_bind(mtm, muid, del, projectid, tagid, levelmask)
		select * from
			dblink('select x.* from tag_project_bind as x join projects as p on x.projectid=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				projectid bigint,
				tagid bigint,
				levelmask integer);
				
	INSERT INTO attrib_project(pid, key, val)
		select * from
			dblink('select x.* from attrib_project as x join projects as p on x.pid=p.uid where unid = ' || _unid || ';')
			AS t(
				pid bigint,
				key integer,
				val text);

	INSERT INTO pays_tasks(mtm, muid, uid, taskid, flags, money, commit, comment)
		select * from
			dblink('select x.* from pays_tasks as x join tasks as t on x.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
			  mtm timestamp with time zone,
			  muid integer,
			  uid bigint,
			  taskid bigint,
			  flags integer,
			  money double precision,
			  commit timestamp with time zone,
			  comment character varying);
			  
	INSERT INTO archive_pays_tasks(mtm, muid, uid, taskid, flags, money, commit, comment)
		select * from
			dblink('select x.* from archive_pays_tasks as x join archive_tasks as t on x.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
			  mtm timestamp with time zone,
			  muid integer,
			  uid bigint,
			  taskid bigint,
			  flags integer,
			  money double precision,
			  commit timestamp with time zone,
			  comment character varying);

	INSERT INTO activity_project_user(mtm, muid, del, activityid, projectid, userid)
		select * from
			dblink('select x.* from activity_project_user as x join projects as p on x.projectid=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				del smallint,
				activityid bigint,
				projectid bigint,
				userid integer);

	INSERT INTO sites_projects(mtm, muid, siteid, projectid)
		select * from
			dblink('select x.* from sites_projects as x join projects as p on x.projectid=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				siteid bigint,
				projectid bigint);

	INSERT INTO sched_plans(mtm, muid, uid, unid, name, flags)
		select * from
			dblink('select x.* from sched_plans as x where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				unid integer,
				name text,
				flags integer);

	INSERT INTO sched_users(mtm, muid, uid, schedid, userid, startdate)
		select * from
			dblink('select x.* from sched_users as x join sched_plans as sp on x.schedid=sp.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				schedid bigint,
				userid integer,
				startdate date);
				
	INSERT INTO sched_holes(mtm, muid, uid, taskid, start, finish, flags)
		select * from
			dblink('select x.* from sched_holes as x join tasks as t on x.taskid=t.uid  join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				taskid bigint,
				start timestamp with time zone,
				finish timestamp with time zone,
				flags integer);
				
	INSERT INTO archive_sched_holes(mtm, muid, uid, taskid, start, finish, flags)
		select * from
			dblink('select x.* from archive_sched_holes as x join archive_tasks as t on x.taskid=t.uid  join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				taskid bigint,
				start timestamp with time zone,
				finish timestamp with time zone,
				flags integer);

	INSERT INTO sched_weeks(mtm, muid, uid, schedid, startdate, flags, mon_lo, mon_hi, tue_lo, tue_hi, wen_lo, wen_hi, thu_lo, thu_hi, fri_lo, fri_hi, sat_lo, sat_hi, sun_lo, sun_hi, local_time_offset)
		select * from
			dblink('select x.* from sched_weeks as x join sched_plans as sp on x.schedid=sp.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				schedid bigint,
				startdate date,
				flags integer,
				mon_lo integer,
				mon_hi bigint,
				tue_lo integer,
				tue_hi bigint,
				wen_lo integer,
				wen_hi bigint,
				thu_lo integer,
				thu_hi bigint,
				fri_lo integer,
				fri_hi bigint,
				sat_lo integer,
				sat_hi bigint,
				sun_lo integer,
				sun_hi bigint,
				local_time_offset real);

	INSERT INTO sched_exceptos(mtm, muid, uid, unid, userid, flags, local_time_offset, name)
		select * from
			dblink('select x.* from sched_exceptos as x where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				unid integer,
				userid integer,
				flags integer,
				local_time_offset real,
				name text);

	INSERT INTO sched_exceptos_fields(mtm, uid, exectoid, startdate, finishdate, work_lo, work_hi, mask_lo, mask_hi)
		select * from
			dblink('select x.* from sched_exceptos_fields as x join sched_exceptos as sp on x.exectoid=sp.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				uid bigint,
				exectoid bigint,
				startdate date,
				finishdate date,
				work_lo integer,
				work_hi bigint,
				mask_lo integer,
				mask_hi bigint);

    raise notice 'projects data and schedules done';
	
	INSERT INTO groups(mtm, muid, uid, creationtime, name, unid, flags)
		select * from
			dblink('select x.* from groups as x where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				uid bigint,
				creationtime timestamp with time zone,
				name character varying,
				unid integer,
				flags integer);

	INSERT INTO users_groups(mtm, muid, userid, groupid)
		select * from
			dblink('select x.* from users_groups as x join groups as g on x.groupid=g.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				groupid bigint);

	INSERT INTO users_groups_visible(mtm, muid, userid, groupid)
		select * from
			dblink('select x.* from users_groups_visible as x join groups as g on x.groupid=g.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				groupid bigint);

	INSERT INTO perm_roles(uid, privileg, name, unid)
		select * from
			dblink('select * from perm_roles where unid = ' || _unid || ';')
			AS t(
				uid bigint,
				privileg bigint,
				name character varying,
				unid integer);

	INSERT INTO perm_users(mtm, muid, userid, taskid, privileg, flags)
		select * from
			dblink('select x.* from perm_users as x join tasks as t on x.taskid=t.uid  join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				taskid bigint,
				privileg bigint,
				flags integer);

	INSERT INTO perm_groups(mtm, muid, groupid, taskid, privileg, flags)
		select * from
			dblink('select x.* from perm_groups as x join groups as g on x.groupid=g.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				groupid bigint,
				taskid bigint,
				privileg bigint,
				flags integer);

	INSERT INTO users_salary(mtm, muid, userid, takeeffecttime, salary, project_id, unid, uid)
		select * from
			dblink('select * from users_salary where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				muid integer,
				userid integer,
				takeeffecttime timestamp with time zone,
				salary real,
				project_id bigint,
				unid integer,
				uid bigint);
				
    raise notice 'groups data done';

					
	INSERT INTO logs(mtm, category, userid, unid, param, details, flags, taskid)
		select * from
			dblink('select 
				mtm,
				category,
				userid,
				unid,
				param,
				details,
				flags,
				taskid
			from logs where unid = ' || _unid || ';')
			AS t(
				--uid bigint,
				mtm timestamp with time zone,
				category smallint,
				userid integer,
				unid integer,
				param bigint,
				details text,
				flags smallint,
				taskid bigint);
				
	raise notice 'logs done';

	INSERT INTO unwatchedtasks(mtm, userid, taskid, parentid, attached_file, watched)
		select * from
			dblink('select x.* from unwatchedtasks as x join tasks as t on x.taskid=t.uid  join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				userid integer,
				taskid bigint,
				parentid bigint,
				attached_file boolean,
				watched timestamp with time zone);
				
	raise notice 'unwatched tasks done';
				
	INSERT INTO unemailedtasks(mtm, userid, taskid, eventid, emailsent, uid, reply_id, param, scope, category, time_to_send, logid)
		select * from
			dblink('select x.* from unemailedtasks as x join tasks as t on x.taskid=t.uid  join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				userid integer,
				taskid bigint,
				eventid bigint,
				emailsent timestamp with time zone,
				uid bigint,
				reply_id text,
				param text,
				scope integer,
				category text,
				time_to_send timestamp with time zone,
				logid bigint);
		
  	raise notice 'unemailed tasks done';

  	INSERT INTO bills(mtm, muid, uid, unid, tugrick, tarrif_id, descr, start_date
					  , stop_date, allow_remote_carga, allow_logins, allow_hddspace
					  , currency, sent_start_email, sent_stop_email, coupon_id, transaction_id
					  , lic_signature, allow_lumpens, del)
	select * from
		dblink('select 
				mtm, muid, uid, unid, tugrick, 0, descr, start_date                -- 0 as tarrif_id
					  , stop_date, allow_remote_carga, allow_logins, allow_hddspace
					  , currency, sent_start_email, sent_stop_email, coupon_id, transaction_id
					  , lic_signature, allow_lumpens, del			   
			   from bills where unid = ' || _unid || ';')
		AS t(
			mtm timestamp with time zone,
			muid integer,
			uid integer,
			unid integer,
			tugrick double precision,
			tarrif_id integer,
			descr text,
			start_date date,
			stop_date date,
			allow_remote_carga boolean,
			allow_logins integer,
			allow_hddspace bigint,
			currency smallint,
			sent_start_email timestamp with time zone,
			sent_stop_email timestamp with time zone,
			coupon_id bigint,
			transaction_id bigint,
			lic_signature text,
			allow_lumpens integer,
			del smallint);

	raise notice 'bills done';
	
	-- sequences val update
	
	select * into _seq_val from dblink('select nextval(''bill_id_seq'')') AS t(uid bigint);	
	raise notice 'bill_id_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('bill_id_seq')))
	then
		perform setval('bill_id_seq', _seq_val);
	end if;
	raise notice 'bill_id_seq: %', _seq_val;	
	
	select * into _seq_val from dblink('select nextval(''del_seq'')') AS t(uid bigint);	
	raise notice 'del_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('del_seq')))
	then
		perform setval('del_seq', _seq_val);
	end if;
	raise notice 'del_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''group_id_seq'')') AS t(uid bigint);	
	raise notice 'group_id_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('group_id_seq')))
	then
		perform setval('group_id_seq', _seq_val);
	end if;
	raise notice 'group_id_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''log_seq'')') AS t(uid bigint);	
	raise notice 'log_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('log_seq')))
	then
		perform setval('log_seq', _seq_val);
	end if;
	raise notice 'log_seq: %', _seq_val;
								   
	select * into _seq_val from dblink('select nextval(''partner_id_seq'')') AS t(uid bigint);	
	raise notice 'partner_id_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('partner_id_seq')))
	then
		perform setval('partner_id_seq', _seq_val);
	end if;
	raise notice 'partner_id_seq: %', _seq_val;					
								   
	select * into _seq_val from dblink('select nextval(''seqno_seq'')') AS t(uid bigint);	
	raise notice 'seqno_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('seqno_seq')))
	then
		perform setval('seqno_seq', _seq_val);
	end if;
	raise notice 'seqno_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''servers_seq'')') AS t(uid bigint);	
	raise notice 'servers_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('servers_seq')))
	then
		perform setval('servers_seq', _seq_val);
	end if;
	raise notice 'servers_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''uid_seq'')') AS t(uid bigint);	
	raise notice 'uid_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('uid_seq')))
	then
		perform setval('uid_seq', _seq_val);
	end if;
	raise notice 'uid_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''unemail_notify_random_seq'')') AS t(uid bigint);	
	raise notice 'unemail_notify_random_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('unemail_notify_random_seq')))
	then
		perform setval('unemail_notify_random_seq', _seq_val);
	end if;
	raise notice 'unemail_notify_random_seq: %', _seq_val;		
								   
	select * into _seq_val from dblink('select nextval(''unemail_uid'')') AS t(uid bigint);	
	raise notice 'unemail_uid from: %', _seq_val;	
	if (_seq_val > (select nextval('unemail_uid')))
	then
		perform setval('unemail_uid', _seq_val);
	end if;
	raise notice 'unemail_uid: %', _seq_val;
								   
	select * into _seq_val from dblink('select nextval(''universe_id_seq'')') AS t(uid bigint);	
	raise notice 'universe_id_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('universe_id_seq')))
	then
		perform setval('universe_id_seq', _seq_val);
	end if;
	raise notice 'universe_id_seq: %', _seq_val;
								   
	select * into _seq_val from dblink('select nextval(''users_uid_seq'')') AS t(uid bigint);	
	raise notice 'users_uid_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('users_uid_seq')))
	then
		perform setval('users_uid_seq', _seq_val);
	end if;
	raise notice 'users_uid_seq: %', _seq_val;	
								   
	select * into _seq_val from dblink('select nextval(''web_sid_seq'')') AS t(uid bigint);	
	raise notice 'web_sid_seq from: %', _seq_val;	
	if (_seq_val > (select nextval('web_sid_seq')))
	then
		perform setval('web_sid_seq', _seq_val);
	end if;
	raise notice 'web_sid_seq: %', _seq_val;								   
	
	raise notice 'sequences val done';
								   
	--raise exception 'good';
								   
	select * into _ret from dblink(
			(select cabinet_link from cur_state where uid=0)
			, 'select "zRegionChange"((select uid from universes where memoria_uid=' || _unid::text || '),' || (select server from cur_state where uid=0)::text || ');'
			) AS t(ret boolean);
									  
	raise notice 'change cabinet server id done';							   

	/*
	select * into _ret from dblink('select "zzKillUsers"(' || _unid || ')') AS t(ret boolean);
	raise notice 'remove users done';
	*/
									  
	raise notice 'pulling done';
	
	
	/*if exists (select 1 from universes where uid=1841)
	then
		perform "zzAnihilateUniverse"('Your Universe', false);
	end if;*/	
end
$BODY$;

ALTER FUNCTION public."zzPullUniverse"(character varying, text)
    OWNER TO sa;
