/*

1. Реализация связи статуса с видами деятельности задачи, на которых данный статус можно поставить.
Если для статуса не определён ни один вид деятельности, считается, что статус возможен на задачах с любым видом деятельности

2. Реализован функционал для расширения возможных форматов иконок статуса, без преобразования в XPM (там проблемы с прозрачностью)
Для этого добавлено поле icon_hash, где будет хранится хеш иконки статуса. 
Сама иконка будет отправлять в наше хранилище storage.cerebrohq.com, по тому же принципу что и аватарки пользователей
Поддерживаемые форматы:
PNG
JPEG
SVG - для поддержки экранов разного разрешения (dpi). (В мобильной версии их нужно будет преобразовывать в поддерживаемый формат в зависимости от разрешения экрана, я тогда опишу в ТЗ)


Добавлены:

процедуры:

statusHasActivity - проверка на наличие привязки вида деятельности к статусу
statusCheckActivity - проверка на возможность установки статуса на задаче с таким видом деятельности
statusActivites - список видов деятельности, привязанных к статусу
statusActivitySet - привязка/отвязка стутуса от вида деятельности. 
			Просходит путем добавления/удаления записи в status_activities

statusSetIcon_01 - установка хеша иконки статуса
statusIconHashs - запрос на хеши иконок

Изменено:

процедуры:

statusListByTask - возвращает список возможных статусов с учетом вида деятельности
taskSetStatus_a - добавлена проверка на возможность установки статуса на задаче с таким видом деятельности
zzAnihilateUniverse - добавлено удаление записей из status_activities
zMessageUpdate - добавлено сообщение о невозможности установить статус


в конце вызывается zMessageUpdate
*/

CREATE OR REPLACE FUNCTION "statusSetIcon_01"(
    _uid bigint,
    _hash text)
  RETURNS bigint AS
$BODY$
declare
	
begin	
	perform "perm_checkGlobal"((select unid from status where uid=_uid), 'mng_tag_act');
	update status set icon_hash = _hash, mtm = now() where uid=_uid;
	return _uid;	
end
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;
ALTER FUNCTION "statusSetIcon_01"(bigint, text)
  OWNER TO sa;


CREATE OR REPLACE FUNCTION "statusIconHashs"(_uid bigint[])
  RETURNS SETOF "tBigintStr" AS
$BODY$
	select uid, icon_hash from status where uid = any ($1);
$BODY$
  LANGUAGE sql STABLE STRICT SECURITY DEFINER
  COST 100
  ROWS 1000;
ALTER FUNCTION  "statusIconHashs"(bigint[])
  OWNER TO sa;


CREATE OR REPLACE FUNCTION "statusHasActivity"(
    _status_uid bigint,
    _task_activity bigint)
  RETURNS boolean AS
$BODY$
declare	
begin
	if ( (not exists (select 1 from status_activities where statusid=$1)) or 
		(exists (select 1 from status_activities where statusid=$1 and activityid=$2)) )
	then
		return true;
	end if;
	
	return false;
end
$BODY$
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  COST 1000;
ALTER FUNCTION "statusIsPerms"(bigint, bigint, integer)
  OWNER TO sa;


CREATE OR REPLACE FUNCTION "statusCheckActivity"(
   _status_uid bigint,
    _task_activity bigint)
  RETURNS void AS
$BODY$
begin
	if not "statusHasActivity"(_status_uid, _task_activity)
	then
		raise exception '%', msg(142);
	end if;
end
$BODY$
  LANGUAGE plpgsql STABLE SECURITY DEFINER
  COST 1000;
ALTER FUNCTION "statusCheckPerms"(bigint, bigint, integer)
  OWNER TO sa;


-- FUNCTION: public."statusListByTask"(bigint)

-- DROP FUNCTION public."statusListByTask"(bigint);

CREATE OR REPLACE FUNCTION public."statusListByTask"(
	__tid bigint)
    RETURNS SETOF "tStatus" 
    LANGUAGE 'plpgsql'

    COST 1000
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$

declare
	_ret	"tStatus";
	_tid		bigint				= "refResolve"(__tid);
	_unid		int				= "getUnid"(_tid);
	_task_perms	bigint				=  perm(get_usid(), _tid, 0);
	_cur_status bigint; --				= (select cc_status from tasks where uid=_tid);
	_actid bigint;	
	_cur_status_leave_perms int; --			= "statusPerm"(_cur_status, _unid, false);
	_can_leave boolean; --				= "statusIsPerms"(_tid, _task_perms, _cur_status_leave_perms);
	_true_task boolean				= (not exists (select 1 from tasks where lnk_front_parent=_tid and del=0));
begin	

	select cc_status, activityid into _cur_status, _actid from tasks where uid=_tid;
	
	_cur_status_leave_perms = "statusPerm"(_cur_status, _unid, false);
	_can_leave = "statusIsPerms"(_tid, _task_perms, _cur_status_leave_perms);
												   
	for _ret in (select * from "statusList"())
	loop		
		if _unid=_ret.unid and 
		(	_cur_status is not distinct from _ret.uid
			or (
				_can_leave and "statusIsPerms"(_tid, _task_perms, _ret.perm_enter)
				and (_true_task or (_ret.uid is null) or (select (flags & 2)!=0 from status where uid=_ret.uid))
				and "statusHasActivity"(_ret.uid, _actid)
			)
		)
		then
			return next _ret;
		end if;
	end loop;
end

$BODY$;

ALTER FUNCTION public."statusListByTask"(bigint)
    OWNER TO sa;



-- Function: "taskSetStatus_a"(bigint[], bigint)

-- DROP FUNCTION "taskSetStatus_a"(bigint[], bigint);

CREATE OR REPLACE FUNCTION "taskSetStatus_a"(
    tid bigint[],
    _status bigint)
  RETURNS SETOF bigint AS
$BODY$
DECLARE 
	i 		bigint;
	_usid	int = get_usid();
	_priveleg	bigint;
	_unid int;
	_perm_leave int;
	_perm_enter int;
	_task_perms bigint;
	_tid		bigint;
	_actid	bigint;
	_cur_status bigint;
BEGIN
	if(array_dims(tid) is not NULL)
	then
		for i in array_lower(tid, 1)..array_upper(tid, 1)
		loop
			_tid = "refResolve"(tid[i]);
			_unid = "getUnid"(_tid);

			select cc_status, activityid into _cur_status, _actid from tasks where uid=_tid;
			_perm_enter = "statusPerm"(_status, _unid, true);
			_perm_leave = "statusPerm"(_cur_status, _unid, false);
			
			_task_perms = perm(_usid, _tid, 0);
			perform "statusCheckPerms"(_tid, _task_perms, _perm_enter);
			perform "statusCheckPerms"(_tid, _task_perms, _perm_leave);
			perform "statusCheckActivity"(_status, _actid);

			update tasks set status = _status, flags = (flags | (1<<29)) where uid=_tid;

			--perform "touchBase"(_unid);
			perform "touchTask"(_tid, 4, null);
			return next tid[i];
		end loop;
	end if;

	
	perform "ggSolveMulti"(tid, 4);
	perform "touchBase"();
END
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100
  ROWS 1000;
ALTER FUNCTION "taskSetStatus_a"(bigint[], bigint)
  OWNER TO sa;
  

CREATE OR REPLACE FUNCTION "statusActivites"(_status_id bigint)
  RETURNS SETOF "tSubjectObjectBigint_00" AS
$BODY$
	select status_activities.mtm, activityid, $1, acts.name, acts.unid from status_activities 
			inner join activitytypes as acts on status_activities.activityid=acts.uid
			where statusid=$1
$BODY$
  LANGUAGE sql STABLE STRICT SECURITY DEFINER
  COST 100
  ROWS 1000;
ALTER FUNCTION "statusActivites"(bigint)
  OWNER TO sa;

-- Function: "userActivityAddTo"(integer, bigint)


CREATE OR REPLACE FUNCTION "statusActivitySet"(_status_id bigint,
    _activity_id bigint,
    _set boolean)
  RETURNS void AS
$BODY$
declare
	_unid integer = (select unid from activitytypes where uid=$2);	
begin
	perform "perm_checkGlobal"(_unid, 'mng_tag_act');

	if($1 is null or $2=0)
	then
		raise exception '%', msg(105);
	end if;	

	if ((select unid from status where uid=$1)!=_unid)
	then
		raise exception '%', msg(116);
	end if;	

	if ($3)
	then		
		if(not exists (select 1 from status_activities where statusid=$1 and activityid=$2))
		then
			INSERT INTO status_activities(statusid, activityid) VALUES ($1, $2);
		end if;
	else
		if(exists (select 1 from status_activities where statusid=$1 and activityid=$2))
		then
			DELETE FROM status_activities WHERE statusid=$1 and activityid=$2;
		end if;
	end if;	
end
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER
  COST 100;
ALTER FUNCTION "statusActivitySet"(bigint, bigint, boolean)
  OWNER TO sa;



-- FUNCTION: public."zzAnihilateUniverse"(character varying, boolean)

-- DROP FUNCTION public."zzAnihilateUniverse"(character varying, boolean);

CREATE OR REPLACE FUNCTION public."zzAnihilateUniverse"(
	_uname character varying,
	_archive_mode boolean)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT 
AS $BODY$

-- in 'archive_mode' does not remove universe and admin user accounts
declare 
	_unid 		integer = (select uid from universes where "name" = _uname);
	_user_id	integer;
	_lid		name;
	
begin
	if(_unid is null)
	then
		raise exception 'Invalid Universe';
	end if;
	
	--raise notice 'Universe % pid(%) is going to be ANIHILATED! You have 30 sec to abort DATA EXTERMINATION', _uname, _unid;
	--perform pg_sleep(30);

	if(not "isUserShepherd_bySession"())
	then
		raise exception 'You must be Shepherd';
	end if;

	perform "zzAnihilateProject"(uid) from projects where unid = _unid; -- limit 5;

	UPDATE cur_state set debug=true where uid=0;

	delete from z_act_map  where u=_unid;
	delete from z_tag_map  where u=_unid;
	delete from z_enum_map where u=_unid;

	delete from sched_exceptos_fields where exectoid in (select uid from sched_exceptos where unid=_unid);
	delete from sched_exceptos where unid=_unid;
	delete from sched_weeks where schedid in (select uid from sched_plans where unid=_unid);
	delete from sched_users where schedid in (select uid from sched_plans where unid=_unid);
	delete from sched_plans where unid=_unid;
	delete from logs where unid=_unid;
	
	delete from invites where unid=_unid;

	delete from tag_enums where tagid in (select uid from tag_schema where unid=_unid);
	delete from tag_schema where unid=_unid;
	delete from ht_schema where unid=_unid;

	delete from users_groups_visible where groupid in (select uid from groups where unid=_unid);
	delete from users_groups where groupid in (select uid from groups where unid=_unid);
	delete from perm_groups where groupid in (select uid from groups where unid=_unid);
	delete from groups where unid=_unid;

	delete from sites_projects where siteid in (select uid from sites where unid=_unid);
	delete from sites where unid=_unid;

	delete from perm_roles where unid=_unid;

	delete from coupons where dedicated_unid=_unid;

	delete from status_cond where ruleid in (select uid from status_rules where unid=_unid);
	delete from status_rules where unid=_unid;
	delete from status where unid=_unid;

	delete from status_activities where activityid in (select uid from activitytypes where unid=_unid);
	delete from users_activities where activityid in (select uid from activitytypes where unid=_unid);
	delete from activitytypes where unid=_unid;

	delete from users_salary where unid=_unid;

	delete from plugins_versions where pluginid in (select uid from plugins where unid=_unid);
	delete from plugins where unid=_unid;
	
	delete from attrib_universe where unid = _unid;
	
	for _user_id in (select userid from users_universes where unid=_unid and del=0 and userid>5) --limit 10
	loop
		-- in demo and this universe
		if("isUserInOneUniverse"(_user_id) or
			("isUserInUniverse"(_user_id, 31) and (SELECT count(1) FROM users_universes WHERE userID=_user_id and users_universes.del=0)=2)) 
		then
			raise notice 'removing user:% %', _user_id, (select lid from users where uid=_user_id);
			
			if(_archive_mode and "perm_Root"(_user_id, _unid)<0)
			then
				continue;
			end if;
			
			delete from web_sid		where usid=_user_id;
			delete from users_web_sids	where usid=_user_id;
			delete from users_salary	where userid=_user_id;
			delete from users_tasks		where userid=_user_id;
			delete from users_activities	where userid=_user_id;
			delete from users_groups 	where userid=_user_id;
			delete from users_groups_visible where userid=_user_id;
			delete from perm_users		where userid=_user_id;
			delete from logins		where userid = _user_id;

			delete from attrib_user where usid = _user_id;

			delete from archive_users_tasks	where userid=_user_id;
			delete from logs where userid=_user_id;

			if(((select flags from users where uid=_user_id) & 2)=0)
			then
				perform "userKill"(_user_id, _unid);

				if("isUserInUniverse"(_user_id, 31))
				--if exists (SELECT 1 FROM users_universes WHERE userID=_user_id and unid=31) -- caused user not in uneverse when he WAS here, and has del!=0
				then
					perform "userKill"(_user_id, 31);
				end if;
			else
				perform "resourceDel"(_user_id, _unid);
				
				if("isUserInUniverse"(_user_id, 31))
				--if exists (SELECT 1 FROM users_universes WHERE userID=_user_id and unid=31) -- caused user not in uneverse when he WAS here, and has del!=0
				then
					perform "resourceDel"(_user_id, 31);
				end if;
			end if;

			--raise notice 'users_universes %', (select count(1) from users_universes WHERE userid=_user_id);
			-- user kill only marks users_universes del flag
			delete from users_universes WHERE userid=_user_id;

			begin
				delete from users where uid=_user_id;
			exception
			when FOREIGN_KEY_VIOLATION then
				raise notice 'cant remove user:% %', _user_id, (select lid from users where uid=_user_id);
			end;
		end if;
	end loop;

	delete from logs where unid=_unid;

	if(not _archive_mode)
	then
		delete from bills where unid=_unid;
		delete from users_universes WHERE unid=_unid;
		delete from universes where uid=_unid;

		perform (select uid from dblink(
			(select cabinet_link from cur_state where uid=0) --'host=/var/run/postgresql port=45432 dbname=cabinet user=sa_cabinet'
			, 'select "universeDel"((select uid from universes where memoria_uid=' || _unid::text || '));'
		) AS t(uid integer));
	end if;

	UPDATE cur_state set debug=false, mtm=now() where uid=0;
	
	--raise exception 'SUCCESS';
end

$BODY$;

ALTER FUNCTION public."zzAnihilateUniverse"(character varying, boolean)
    OWNER TO sa;

GRANT EXECUTE ON FUNCTION public."zzAnihilateUniverse"(character varying, boolean) TO sa;
GRANT EXECUTE ON FUNCTION public."zzAnihilateUniverse"(character varying, boolean) TO PUBLIC;


CREATE OR REPLACE FUNCTION "zzPullUniverse"(_uname character varying, _conn_string text) RETURNS void
    LANGUAGE plpgsql STRICT
    AS $$
-- e.g. select "zzPullUniverse"('Chain-FX', 'host=cerebrohq.com port=45432 dbname=memoria user=sa password=<passwd>');
declare
	_unid 		integer;
	_ret		record;
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

	--SET SESSION session_replication_role = replica;
	INSERT INTO users(mtm, del, uid, creationtime, email, icq, phone, lid, langid, emit_start
	, emit_assign, emit_interest, multilogin, spam_sent_time, spam_stage, flags, firstname, lastname
	, delete_unwatched_age, randid, avatar_hash, local_time_offset , emit_schedule, emit_cando, ad_sid,
	ldap_dn, ldap_login, ldap_email)
		select * from
			dblink('select u.* from users as u join users_universes as uu on uu.userid=u.uid where u.uid>10 and uu.unid = ' || _unid || ';')
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
			);

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
				dblink('select wa.* from web_auth as wa join users as u on wa.usid=u.uid join users_universes as uu on uu.userid=u.uid where u.uid>10 and uu.unid = ' || _unid || ';')
				AS t(
					mtm timestamp with time zone,
					usid integer,
					salt text,
					hash text
				);

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
	update users as u
		set lid = null
	where
		u.uid>10
		and coalesce((select del!=0 from users_universes as uu where uu.unid = _unid and userid = u.uid), true);


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

	INSERT INTO status(uid, "name", flags, order_no, description, icon_xpm, color, unid, perm_leave_bits, perm_enter_bits, icon_hash)
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
			t.cc_thumb_oldest_group, t.tg_offset, t.tg_stop, costs, t.cc_costs, t.cc_pays,
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

	INSERT INTO event_likes(mtm, eventid, userid, voice)
		select * from
			dblink('select a.* from event_likes as a join events as e on a.eventid=e.uid join tasks as t on e.taskid=t.uid join projects as p on t.prj_id=p.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				  eventid bigint,
				  userid integer,
				  voice boolean);

	INSERT INTO attachments(mtm, eventid, del, groupid, creationtime, hash, tag, filesize, originalfilename, description, uid)
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
				uid bigint);

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
			dblink('select ht.* from ht_event as ht join ht_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				eventid bigint,
				tagid bigint);

	INSERT INTO ht_attachment(mtm, attachmentid, tagid)
		select * from
			dblink('select ht.* from ht_attachment as ht join ht_schema as ts on tagid=ts.uid where unid = ' || _unid || ';')
			AS t(
				mtm timestamp with time zone,
				attachmentid bigint,
				tagid bigint);

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
			dblink('select x.* from perm_users as x join users_universes as uu on x.userid=uu.userid where unid = ' || _unid || ';')
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

	if exists (select 1 from universes where uid=1841)
	then
		perform "zzAnihilateUniverse"('Your Universe', false);
	end if;

	raise exception 'good';
end
$$;


-- FUNCTION: public."zMessageUpdate"()

-- DROP FUNCTION public."zMessageUpdate"();

CREATE OR REPLACE FUNCTION public."zMessageUpdate"(
	)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
begin
	INSERT INTO messages (code, langid, msg) 
	VALUES 
	(100, 1, 'the Site and the Project bolongs to diffirent universes'),
	(100, 2, 'Хранилище и проект находятся в разных вселенных'),
	(100, 3, '站点和项目属于不同领域'),
	(100, 17, '사이트와 프로젝트가 서로 다른 유니버스에 있습니다'),
	(100, 18, 'サイトとプロジェクトが異なるユニバースに属しています'),
	(101, 1, 'Last storage can not be removed'),
	(101, 2, 'Нельзя лишать проект самого распоследнего хранилища'),
	(101, 3, '无法删除上一个存储'),
	(101, 17, '마지막 스토리지는 삭제될 수 없습니다'),
	(101, 18, '最後のストレージは削除できません'),
	(102, 1, 'You are trying to revoke your own administrative privileges'),
	(102, 2, 'Вы пытаетесь лишить себя прав на управление. Так не пойдет'),
	(102, 3, '您在尝试撤销自己的管理权限'),
	(102, 17, '자신의 관리자 권한을 취소하려고 합니다'),
	(102, 18, '自分自身の管理権限を削除しようとしています'),
	(103, 1, 'User is not permitted see this task. You should use Access Rights tab to resolve the problem#103'),
	(103, 2, 'У пользователя не достаточно прав для просмотра этой задачи. Используйте панель "Права Доступа" для устранения проблемы#103'),
	(103, 3, '用户不允许查看该任务。您应该使用“访问权限”选项卡来解决问题#103'),
	(103, 17, '사용자는 이 작업을 볼 수 없습니다. 사용 권한 탭을 사용하여 문제를 해결하세요#103'),
	(103, 18, 'ユーザーにはこのタスクの表示は許可されていません問題#103を解決するにはアクセス権タブを使用します'),
	(105, 1, 'Access denied'),
	(105, 2, 'Доступ отклонен'),
	(105, 3, '访问被拒绝'),
	(105, 17, '액세스가 거부되었습니다'),
	(105, 18, 'アクセス拒否'),
	(106, 1, 'User belongs several universes'),
	(106, 2, 'Пользователь сосотоит в нескольких вселенных и поэтому не может быть отредактирован'),
	(106, 3, '用户属于多个领域'),
	(106, 17, '사용자가 몇 개의 유니버스에 속합니다 '),
	(106, 18, 'ユーザーは複数のユニバースに属します'),
	(107, 1, 'The License is invalid'),
	(107, 2, 'Лицензия корявая'),
	(107, 3, '许可证无效'),
	(107, 17, '유효한 라이선스가 아닙니다'),
	(107, 18, 'ライセンスが無効です'),
	(108, 1, 'Database is under maintanance. Please get newer client to work with alternate server.'),
	(108, 2, 'Система на обслуживании. Обновите версию Cerbro для работы с альтернативным сервером'),
	(108, 3, '数据库正在维护。请让新客户使用备用服务器。'),
	(108, 17, '데이터베이스가 유지보수 중입니다. 다른 서버와 작업하려면 최신 클라이언트를 사용하세요.'),
	(108, 18, 'データベースはメンテナンス中です。別のサーバーで作業をするには、より新しいクライアントを取得してください。'),
	(109, 1, 'Your trial period has expired. You would contact customer service at http://cerebrohq.com. '),
	(109, 2, 'Ваш период тестирования закончился. Вы можете связаться со службой продаж на сайте http://cerebrohq.com.'),
	(109, 3, '您的试用期已到期。您可以在 http://cerebrohq.com 联系客服。'),
	(109, 17, '체험판 기간이 만료되었습니다. 고객 서비스 문의는 http://cerebrohq.com을 이용하세요.'),
	(109, 18, '試用期間が失効しました。カスタマーサポートにお問い合わせください：http://cerebrohq.com'),
	(111, 1, 'The same order number already exists in the system'),
	(111, 2, 'Такой порядковый номер уже существует'),
	(111, 3, '系统中已存在同样的订单号'),
	(111, 17, '시스템에 동이한 주문 번호가 있습니다.'),
	(111, 18, '同じ注文番号が既にシステムに存在します'),
	(112, 1, 'Access to database denied by Local Policy'),
	(112, 2, 'Доступ к базе данных отклонен локальной политикой'),
	(112, 3, '访问数据库被“本地策略”拒绝'),
	(112, 17, '로컬 정책에서 허용하지 않는 데이터베이스 액세스'),
	(112, 18, 'データベースへのアクセスがローカルポリシーにより拒否されました'),
	(113, 1, 'You have exceeded licence limit in the % universe. Buy more or remove exceeded logins, please. (You may recover removed logins later with theirs e-mail). Loging allowed % but exists %. Email account allowed % but exists %'),
	(113, 2, 'Вы превысили лимит лицензий для компании "%". Приобретите больше лицензий или уменьшите количество пользователей. (Позже вы сможете восстановить их зная их email). Разрешено пользователей %, но существует %. Разрешенное количество email пользователей %, но существует %'),
	(113, 3, '您已超过 % 领域中的许可证限制。请购买更多或删除超过的登录名。（您可以在以后用其电子邮件恢复被删除的登录名）。允许登录 % 但是存在 %。允许电子邮件账户 % 但是存在 %'),
	(113, 17, '% 유니버스에서 라이선스 한도를 초과했습니다. 더 구입하시거나 초과된 로그인 수를 제거하세요. (나중에 제거된 로그인과 연결된 이메일은 복구할 수 있습니다.) % 로그인을 허용하지만 %이(가) 존재합니다. % 이메일 계정을 허용하지만 %이(가) 존재합니다.'),
	(113, 18, 'ユニバースのライセンス制限数 % を超過しました。もっと購入するか、超過分のログインを削除してください。（削除したログインは後でEメールアドレスを使って復元することができます）。ログの作成許可数は % ですが、% 存在します。Eメールアカウント許可数は % ですが、% 存在します。'),
	(115, 1, 'The action can not be applied to the reference'),
	(115, 2, 'Действие не может быть применено к ссылке'),
	(115, 3, '操作不能应用于参考'),
	(115, 17, '작업은 참조에 적용될 수 없습니다.'),
	(115, 18, 'アクションは参照資料には適用できません'),
	(116, 1, 'Objects belongs differen universes'),
	(116, 2, 'Объекты находятся в разных вселенных'),
	(116, 3, '对象属于不同领域'),
	(116, 17, '개체가 다른 유니버스에 존재합니다.'),
	(116, 18, 'オブジェクトは異なるユニバースに属します'),
	(117, 1, 'The action can be applied to the reference only'),
	(117, 2, 'Действие может быть применено только к ссылке'),
	(117, 3, '操作只能应用于参考'),
	(117, 17, '작업은 참조에만 적용될 수 있습니다.'),
	(117, 18, 'アクションは参照資料にのみ適用できます'),
	(120, 1, 'Same object exists already'),
	(120, 2, 'Такой объект уже есть'),
	(120, 3, '有些对象已存在'),
	(120, 17, '같은 개체가 이미 존재합니다.'),
	(120, 18, '同じオブジェクトが既に存在します'),
	(140, 1, 'Admin can not login as other admin'),
	(140, 2, 'Администратор не может входить из под другого администратора'),
	(140, 3, '管理员不能作为其他管理员登录'),
	(140, 17, '관리자는 다른 관리자로 로그인할 수 없습니다.'),
	(140, 18, '管理者は、他の管理者としてログインできません'),
	(141, 1, 'You can not restore a subtask inside archival task'),
	(141, 2, 'Вы не можете восстановить подзадачу внутри архивной задачи'),
	(141, 3, '您不能恢复存档任务内的子任务'),
	(141, 17, '보관된 작업의 하위 작업을 복원할 수 없습니다.'),
	(141, 18, 'アーカイブタスクの中にサブタスクを復元することはできません'),
	(142, 1, 'Status changing for this activity is unavailable.'),
	(142, 2, 'Статус не может быть установлен на задаче с таким видом деятельности.'),
	(142, 3, '该活动的状态修改功能不可用。'),
	(142, 17, '이 액티비티에 대한 상태 변경이 불가합니다.'),
	(142, 18, 'このアクティビティのためにステータスを変更することはできません。')
	ON CONFLICT (code, langid) DO UPDATE 
		SET msg = EXCLUDED.msg;
end

$BODY$;

ALTER FUNCTION public."zMessageUpdate"()
    OWNER TO sa;

select "zMessageUpdate"();

