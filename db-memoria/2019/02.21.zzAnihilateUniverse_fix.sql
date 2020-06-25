/*
Исправлен порядок удаления данных из таблицы status_activities
*/


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
	   
	delete from status_activities where activityid in (select uid from activitytypes where unid=_unid);

	delete from status_cond where ruleid in (select uid from status_rules where unid=_unid);
	delete from status_rules where unid=_unid;
	delete from status where unid=_unid;
	
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

