
CREATE OR REPLACE FUNCTION "getUserID_bySession"() RETURNS integer
    LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER COST 10
    AS $$
declare
	l name = (select session_user);
	_twsid text;
	_usid int;
begin
	if l != 'sa_web'
	then
		if l = 'sa' or (l like 'sa_%')
		then
			return (select uid from users where lid=l);
		else
			raise exception 'Access denied. (not sa_web)';
		end if;
	end if;

	_twsid = current_setting('usrvar.wsid');
	if coalesce(_twsid, '') = ''
	then
		raise exception 'ASSERT: webResume or webStart was not called (usrvar.wsid is null)';
	end if;

	_usid = (select coalesce(fake_usid, usid) from web_sid where wsid = _twsid::bigint);

	if(_usid is null)
	then
		raise exception 'sqlmsg--Session is not authenticated (possible webResume was not called), addr=%:% #1--', inet_client_addr(), inet_client_port(); -- , age=% , age(t)
	end if;

	return _usid;
end
$$;

CREATE OR REPLACE FUNCTION "getSessionLID"() RETURNS name
    LANGUAGE plpgsql STABLE STRICT SECURITY DEFINER COST 15
    AS $$
declare
	l name = (select session_user);
	--t timestamp with time zone;
	_wsid bigint;
	_twsid text;
begin
	if l != 'sa_web'
	then
		if l = 'sa' or (l like 'sa_%')
		then
			return l;
		else
			raise exception 'Access denied. (not sa_web)';
		end if;
	end if;

	_twsid = current_setting('usrvar.wsid');
	if coalesce(_twsid, '') = ''
	then
		raise exception 'ASSERT: webResume or webStart was not called (usrvar.wsid is null)';
	end if;

	-- was in fake login
	l = (select lid from users where
			uid = (select coalesce(fake_usid, usid) from web_sid where wsid = _twsid::bigint));

	if l is null
	then
		raise exception 'sqlmsg--getSessionLID() failed to auth #0--';
	end if;

	return l;
end
$$;

CREATE OR REPLACE FUNCTION "webToken"(us_id integer) RETURNS bigint
    LANGUAGE plpgsql STRICT SECURITY DEFINER COST 10
    AS $$
declare
	ws_id	bigint;
	uss	name = (session_user);
begin
	--if inet_client_addr()='82.131.57.44'
	--then
	--	raise notice '~~~~~~~~~~~~~~~~~ WEB_START. userid=%', us_id;
	--end if;

	if uss != 'sa_web' and uss != 'sa'
	then
		raise exception 'ASSERT: Web access denied';
	end if;

	ws_id = nextval('web_sid_seq')::integer;
	ws_id = ws_id | ((random()*2147483647)::bigint << 32);

	--- !!!! Timer in getSessionLID COMMENTED!!!
	delete from web_sid where age(now(), mtm) > '1 hour'::interval; -- or connid="webConnID"(); --  in getSessionLID time out set to 10 min
	insert into web_sid(wsid, usid) values(ws_id, us_id);
	perform set_config('usrvar.wsid', ws_id::text, true);

	return ws_id;
end
$$;

CREATE OR REPLACE FUNCTION _user_update("userID" integer, full_name character varying, "Email" character varying, "Icq" character varying, "Phone" character varying, log_name name, password character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	user_id integer;
	setSome boolean = false;
	login_name name = lower(log_name);
	lname name;
	user_mail character varying;
	restricted boolean = false;
	fl	integer;
begin
	if("userID" is not NULL)
	then
		user_id = "userID";
		restricted = "perm_checkUserManage"(user_id);
	else
		user_id = "get_usid"();
	end if;

	fl = (select flags from users where uid=user_id);

	if((fl & 2)!=0)
	then
		raise exception 'Can''t update recources';
	end if;

	lname = "getUserLogin_byID"(user_id);

	if(full_name is not null)
	then
		--update users set fullName=full_name where uid=user_id;
		update users set firstname="userNameFirst"(full_name), lastname="userNameLast"(full_name) where uid=user_id;

		setSome=true;
	end if;

	if("Icq" is not null)
	then
		if("Icq"!='')
		then
			update users set icq="Icq" where uid=user_id;
		else
			update users set icq=null where uid=user_id;
		end if;

		setSome=true;
	end if;

	if("Phone" is not null)
	then
		if("Phone"!='')
		then
			update users set phone="Phone" where uid=user_id;
		else
			update users set phone=null where uid=user_id;
		end if;

		setSome=true;
	end if;

	if((password is not null) OR (login_name is not null) OR ("Email" is not null))
	then
		-- confedintial area

		if "isServerSU"(user_id)
		then
			raise exception 'can''t update superUser credential';
			ROLLBACK;
		end if;

		--if(restricted)
		--then
		--	RAISE EXCEPTION 'Access denied';
		--	ROLLBACK;
		--end if;

		if (select ad_sid from users where uid=user_id) is not null
		then
			RAISE EXCEPTION 'You can not rename LDAP-imported user';
		end if;

		if((login_name is not null) and (login_name!=lname))
		then
			if (password is null)
			then
				RAISE EXCEPTION 'You must privide New Password when renaming account';
			end if;

			--(DROP_ROLE) EXECUTE 'ALTER ROLE "' || lname || '" RENAME TO "' || login_name || '"';
			update users set lid=login_name where uid=user_id;
			lname = login_name;
			setSome=true;
		end if;

		if("Email" is not null)
		then
			if("Email"!='')
			then
				user_mail = lower("Email");
				update users set email=user_mail where uid=user_id;
			else
				update users set email=null where uid=user_id;
			end if;

			setSome=true;
		end if;

		if(password is not null)
		then
			if(password!='')
			then
				perform "userSetWebPassword"(user_id, password);

				--(DROP_ROLE) EXECUTE 'ALTER ROLE "' || lname || '" WITH LOGIN ENCRYPTED PASSWORD ''' || password || '''';
				setSome=true;
			else
				raise exception 'Empty password is not allowed';
			end if;

			perform "log"(3, null, user_id, 'user password changed. login: <' || "getUserLogin_byID"(user_id) || '>');
		end if;

	end if;

	if(setSome)
	then
		perform "touchUser"(user_id);
	end if;

	return user_id;
end
$$;

CREATE OR REPLACE FUNCTION "adUserActivate"(user_id integer, un_id integer, _assign_with integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	_ret 		int;
	_new_login	name;
	_ex_login	name;
	_u			users;
begin
	if "isServerSU"(user_id)
	then
		raise exception 'can''t update superUser credential';
	end if;

	perform "perm_checkUserManageByUnid"(un_id, user_id);

	select * from users into _u where uid=user_id;

	if _u.del=0 or (_u.lid is not null)
	then
		raise exception 'User can not be activated because he/she is alive';
	end if;

	if _u.ad_sid is null
	then
		raise exception 'User can not be activated because he was not imported from Directory';
	end if;

	_new_login = _u.ldap_login;
	if(_new_login is null)
	then
		raise exception 'User can not be activated he has NULL login';
	end if;

	if  _assign_with is null
	then
		-- just activate
		--(DROP_ROLE)
		-- if exists (SELECT 1 from pg_roles where rolname = _new_login)
		-- then
		-- 	raise exception 'User can not be activated due to PG login name conflict';
		-- end if;

		UPDATE users
			SET
				del=0
				, lid = ldap_login --user_id::text
				, email = ldap_email
			WHERE uid=user_id;

		_ret = user_id;

		perform "log"(1, un_id, user_id, 'user activated. login: <' || _new_login || '>');
	else
		-- assign with existed
		if (select ad_sid from users where uid = _assign_with) is not null
		then
			raise exception 'User can not be assigned with non-local user';
		end if;

		if (select del from users where uid=_assign_with) != 0
		then
			raise exception 'User to assign is not alive';
		end if;

		_ex_login = "getUserLogin_byID"(_assign_with);
		if _ex_login is null --(DROP_ROLE) or (not exists (SELECT 1 from pg_roles where rolname=_ex_login))
		then
			raise exception 'User to assign has no login ability';
		end if;

		--(DROP_ROLE) EXECUTE 'DROP ROLE "' || _ex_login || '"';

		-- change SID and del to disabled
		UPDATE users
			SET
				del=1
				, ad_sid = (ad_sid || '-ASSIGNED')
			WHERE uid = user_id;

		UPDATE users
			SET
				ad_sid = _u.ad_sid
				, ldap_login = _u.ldap_login
				, ldap_dn = _u.ldap_dn
				, ldap_email = _u.ldap_email
				, lid = _u.ldap_login
				, email = _u.ldap_email
			WHERE uid = _assign_with;

		_ret = _assign_with;
		perform "log"(1, un_id, _ret, 'user assigned. ldap_user: <' || user_id::text || '>');
	end if;

	insert into users_universes(unid, userid) values(un_id, _ret);

	return _ret;
end
$$;

CREATE OR REPLACE FUNCTION "adUserConvertToBasic"(user_id integer, password_str text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	_u	users;
	login_name name;
begin

	if "isServerSU"(user_id)
	then
		raise exception 'can''t update superUser credential';
	end if;

	perform "perm_checkUserManage"(user_id);

	select * from users into _u where uid=user_id;

	login_name = _u.lid;
	if(login_name is NULL)
	then
		raise exception 'ASSERT: Login Name is NULL';
	end if;

	if _u.ad_sid is null
	then
		raise exception 'User can not be converted because he was not imported from Directory';
	end if;

	if (password_str is null)
	then
		--(DROP_ROLE) EXECUTE 'CREATE ROLE ' || login_name || ' WITH LOGIN INHERIT ';
	else
		--(DROP_ROLE) EXECUTE 'CREATE ROLE ' || login_name || ' WITH LOGIN INHERIT ENCRYPTED PASSWORD ''' || password_str || '''';
	end if;

	update users set ad_sid=null where uid=user_id;

	if "getUserID_byLogin"(login_name) is null
	then
		RAISE EXCEPTION 'Create user failed';
	end if;

	perform "userSetWebPassword"(user_id, password_str);
	perform "log"(1, un_id, user_id, 'user coverted to basic. login: <' || login_name || '>');

	return user_id;
end
$$;

CREATE OR REPLACE FUNCTION "atLogon"() RETURNS integer
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
declare
	user_id int = (select uid from users where lid="getSessionLID"());
	del_role name;
begin
	if(("getSessionLID"() is null) or "getSessionLID"()='sa_passrecover' or "isSystemReader"())
	then
		raise exception 'Logon is forbitten';
		rollback;
	end if;

	if user_id is null then
		RAISE EXCEPTION 'Login has no user-security record';
	end if;

	--(DROP_ROLE)
	-- for del_role in
	-- (
	-- 	select rolname
	-- 		from pg_roles
	-- 			where (not rolcanlogin)
	-- 			and not rolname in ('backupus', 'sa_sirena', 'sa_stat', 'sa_passrecover', 'sa_web', 'develop', 'mamots', 'shepherds', 'system_readers', 'writer_estadistica', 'reader_estadistica')
	-- )
	-- loop
	-- 	EXECUTE 'DROP ROLE "' || del_role || '"';
	-- end loop;

	update users set local_time_offset=(SELECT EXTRACT(timezone FROM now())/60)::real where uid=user_id;

	perform "perm_checkMaster"();
	perform "cleanCaches"();
	return "getUserID_bySession"();
end
$$;

CREATE OR REPLACE FUNCTION "userConvert_Lumpen2User"(user_id integer, log_name character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	login_name name = lower(log_name);
	fl		integer;
	_del	integer;
	_email	text;
begin
	if("isServerSU"(user_id) or user_id<=5)
	then
		raise exception 'can''t update superUser credential';
	end if;
	perform "perm_checkUserManage"(user_id); -- test user in one universe

	if(login_name is NULL)
	then
		raise exception 'Login Name is NULL';
	end if;

	--(DROP_ROLE) if (exists (select 1 from pg_roles where rolname=login_name))
	if exists (select 1 from users where lid = login_name)
	then
		raise exception 'User with same login already exist : %1', login_name;
	end if;

	select flags, del, email into fl, _del, _email from users where uid=user_id;
	if((fl & 2)!=0)
	then
		raise exception 'Can''t convert recources';
	end if;

	if(_del!=0)
	then
		raise exception 'User in dead';
	end if;

	--(DROP_ROLE) EXECUTE 'CREATE ROLE ' || login_name || ' WITH LOGIN';
	UPDATE users SET del=0, LID = login_name WHERE uid=user_id;

	if("getUserID_byLogin"(login_name) is null)
	then
		RAISE EXCEPTION 'Convert user failed';
	end if;

	perform "log"(1, null, user_id, 'lumpen converted to user. login: <' || login_name || '>');
	return "getUserID_byLogin"(login_name);
end
$$;

CREATE OR REPLACE FUNCTION "userConvert_User2Lumpen"(user_id integer) RETURNS integer
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
declare
	login_name character varying = "getUserLogin_byID"(user_id);
	fl		integer;
	_del	integer;
	_email	text;
begin
	perform "perm_checkUserManage"(user_id); -- test user in one universe

	if("isServerSU"(user_id) or user_id<=5)
	then
		raise exception 'can''t update superUser credential';
	end if;

	select flags, del, email into fl, _del, _email from users where uid=user_id;
	if((fl & 2)!=0)
	then
		raise exception 'Can''t convert recources';
	end if;

	if (login_name is null) or (_del!=0)
	then
		raise exception 'User in dead';
	end if;

	if(_email is null)
	then
		raise exception 'User mail is empty';
	end if;

	if(user_id=get_usid())
	then
		raise exception 'You are going to convert yourself! Are you crazy?';
	end if;

	--(DROP_ROLE) EXECUTE 'DROP ROLE ' || login_name;
	perform "log"(1, null, user_id, 'user converted to lumpen. login: <' || login_name || '>');
	perform "userSetWebPassword"(user_id, null);
	update users set lid=null where uid=user_id;

	return user_id;
end
$$;

CREATE OR REPLACE FUNCTION "userGiveBirth_01"(log_name name, password_str character varying, full_name character varying, "Email" character varying, un_id integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	fl_name character varying = full_name;
	ex_uid integer;
	ex_lid name;
	login_name name = lower(log_name);
	user_id integer;
	user_mail character varying;
begin
	if(login_name is NULL)
	then
		raise exception 'Login Name is NULL';
	end if;

	if("getUserID_byLogin"(login_name) is not NULL)
	then
		raise exception 'User with same login already exist';
	end if;

	if(fl_name is null)
	then
		fl_name = login_name;
	end if;

	if("Email" is not null)
	then
		user_mail = lower("Email");
		select uid, lid from users into ex_uid, ex_lid where email=user_mail;
		if(ex_uid is not null)
		then
			if(ex_lid is not null)
			then
				raise exception 'User with same email already exists';
				rollback;
			end if;

			return -ex_uid;
		end if;
	end if;

	--(DROP_ROLE)
	-- if (password_str is null)
	-- then
	-- 	EXECUTE 'CREATE ROLE "' || login_name || '" WITH LOGIN INHERIT ';
	-- else
	-- 	EXECUTE 'CREATE ROLE "' || login_name || '" WITH LOGIN INHERIT ENCRYPTED PASSWORD ''' || password_str || '''';
	-- end if;

	INSERT INTO users (firstName, lastName, lid, langid, flags)
		select "userNameFirst"(fl_name), "userNameLast"(fl_name), login_name, (select lang from universes where uid=un_id), 8
		; --(DROP_ROLE) from pg_roles where rolname = login_name;

	if "getUserID_byLogin"(login_name) is null
	then
		RAISE EXCEPTION 'Create user failed';
		rollback;
	end if;

	user_id = "getUserID_byLogin"(login_name);

	perform "userSetWebPassword"(user_id, password_str);

	if("Email" is not null)
	then
		update users set email=user_mail where uid=user_id;
	end if;

	insert into users_universes(userid, unid) values ("getUserID_byLogin"(login_name), un_id);

	perform "userActivityAddTo"(user_id, 0);

	perform "perm_checkUserManageByUnid"(un_id, user_id);

	perform "log"(1, un_id, user_id, 'user created. login: <' || login_name || '> email: ' || coalesce("Email", 'none'));

	--if("isServerPrimary"())	then
	--	if(not (exists (select 1 from users_groups where groupid=394301 and users_groups.userid=user_id)))
	--	then
	--		-- add to Cerebro clients
	--		INSERT INTO users_groups(userID, groupID) VALUES (user_id, 394301);
	--	end if;
	--end if;

	return user_id;
end
$$;

CREATE OR REPLACE FUNCTION "userKill"(user_id integer, un_id integer) RETURNS void
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
declare
	login_name character varying = "getUserLogin_byID"(user_id);
	fl	integer = (select flags from users where uid=user_id);
	_finalKill boolean = false;
begin
	if(user_id!=get_usid())
	then
		perform "perm_checkUserManageByUnid"(un_id, user_id);
	end if;

	if((fl & 2)!=0)
	then
		raise exception 'Can''t remove recources';
	end if;

	if("isServerSU"(user_id))
	then
		raise exception 'can''t update superUser credential';
		ROLLBACK;
	end if;

	perform "uniUserRemoveFrom"(user_id, un_id);

	if(user_id>5)
	then
		if(not exists (select 1 from users_universes where userid=user_id and users_universes.del=0))
		then
			--(DROP_ROLE)
			-- if(exists (select 1 from pg_roles where rolname=login_name))
			-- then
			-- 	_finalKill = true;
			-- 	(DROP_ROLE)
			-- 	if user_id != get_usid()
			-- 	then
			-- 		EXECUTE 'DROP ROLE "' || login_name || '"';
			-- 	else
			-- 		EXECUTE 'ALTER Role "' || login_name || '" NOLOGIN';
			-- 	end if;
			-- end if;

			perform "log"(2, un_id, user_id, 'user killed. login: <' || coalesce(login_name, user_id::text) || '>. final: ' || _finalKill::text);
			perform "userSetWebPassword"(user_id, null);
			update users set lid=null, del=1 where uid=user_id;
		end if;
	end if;
end

$$;

CREATE OR REPLACE FUNCTION "userResetPassword"(mail character varying) RETURNS void
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
declare
	user_id integer;
	login_name character varying;
begin
	-- perms setuped by exec privileg

	if(coalesce(mail, '')='')
	then
		raise exception 'User''s email is empty.';
	end if;

	user_id = (select uid from users where email=mail);

	if(user_id is null)
	then
		raise exception 'This email does not exist.';
	end if;

	if "isServerSU"(user_id)
	then
		raise exception 'can''t update superUser credential';
	end if;

	perform "userSetWebPassword"(user_id, null);

	login_name = (select lid from users where uid=user_id);
	if (login_name is null)
	then
		raise exception 'User was killied';
	end if;

	update users set flags = (flags & (~8)) where uid=user_id; -- mark as Guru (non Novice)

	--raise notice 'id=%, lid=%', user_id, login_name;
	--(DROP_ROLE) EXECUTE 'ALTER Role "' || login_name || '" PASSWORD null';
end
$$;

-- FUNCTION: public."userResetPassword_01"(text)

-- DROP FUNCTION public."userResetPassword_01"(text);

CREATE OR REPLACE FUNCTION public."userResetPassword_01"(
	_email text)
    RETURNS boolean
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$

declare
	user_id 	integer;
	login_name	character varying;
begin
	-- perms setuped by exec privileg
	
	user_id = (select uid from users where email = _email);

	if(user_id is null)
	then
		return false;
	end if;
	
	if user_id < 10
	then 
		raise exception 'can''t update superUser credential';
	end if;

	login_name = (select lid from users where uid=user_id);
	if login_name is null
	then
		--raise exception 'User was killied';
		return false;
	end if;

	perform "userSetWebPassword"(user_id, null);
	update users set flags = (flags & (~8)) where uid = user_id; -- mark as Guru (non Novice)
	--EXECUTE 'ALTER Role "' || login_name || '" PASSWORD null';
	return true;
end
$BODY$;
ALTER FUNCTION public."userResetPassword_01"(text)
    OWNER TO sa;


CREATE OR REPLACE FUNCTION "userResurrect"(mail character varying, log_name character varying, un_id integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	login_name name = lower(log_name);
	user_id integer;
begin
	if(coalesce(mail, '')='')
	then
		raise exception 'User''s email is empty.';
	end if;

	user_id = (select uid from users where email=mail);
	if(user_id is null)
	then
		raise exception 'User with specified email has not been found';
		ROLLBACK;
	end if;

	if "isServerSU"(user_id)
	then
		raise exception 'can''t update superUser credential';
	end if;

	perform "perm_checkUserManageByUnid"(un_id, user_id);

	if(login_name is NULL)
	then
		raise exception 'Login Name is NULL';
	end if;

	--(DROP_ROLE) if(exists (select 1 from pg_roles where rolname=login_name))
	if exists (select 1 from users where lid = login_name)
	then
		raise exception 'User with same login already exist : %1', login_name;
	end if;

	if (select del from users where uid=user_id) = 0
	then
		raise exception 'User can not be ressurected because he is alive';
	end if;

	if (select ad_sid from users where uid=user_id) is not null
	then
		raise exception 'User can not be ressurected because he was imported from Directory';
	end if;

	--(DROP_ROLE) EXECUTE 'CREATE ROLE "' || login_name || '" WITH LOGIN';
	insert into users_universes(unid, userid) values(un_id, user_id);

	UPDATE users SET del=0, LID = login_name WHERE uid=user_id;
	if("getUserID_byLogin"(login_name) is null)
	then
		RAISE EXCEPTION 'Ressurect user failed';
	end if;

	perform "log"(1, un_id, user_id, 'user ressurected. login: <' || login_name || '>');

	return "getUserID_byLogin"(login_name);
end
$$;

CREATE OR REPLACE FUNCTION public."userResurrect"(mail character varying, un_id integer)
    RETURNS integer   LANGUAGE 'sql'
    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
	select "userResurrect"(lower(mail), lower(mail), un_id);
$BODY$;


CREATE OR REPLACE FUNCTION "userSetPassword"(mail character varying, pass character varying) RETURNS void
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
declare
	user_id integer;
	login_name character varying;
	_hash	text;
	_salt	text;
begin
	-- perms setuped by exec privileg

	if(coalesce(mail, '')='')
	then
		raise exception 'User''s email is empty.';
		ROLLBACK;
	end if;

	user_id = (select uid from users where email=mail);

	if(user_id is null)
	then
		raise exception 'This email does not exist.';
		ROLLBACK;
	end if;

	if "isServerSU"(user_id)
	then
		raise exception 'can''t update superUser credential';
		ROLLBACK;
	end if;

	login_name = (select lid from users where uid=user_id);
	if(login_name is null)
	then
		raise exception 'User was killied';
		ROLLBACK;
	end if;

	perform "userSetWebPassword"(user_id, pass);

	--(DROP_ROLE) EXECUTE 'ALTER ROLE "' || login_name || '" WITH LOGIN ENCRYPTED PASSWORD ''' || pass || '''';
end
$$;

CREATE OR REPLACE FUNCTION "zCreatePromoUniverse_00"(uname character varying, mail character varying, log_name character varying, "firstName" text, "lastName" text, lang_id integer, creator_icq character varying, creator_phone character varying, uni_desc character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
--- CALLED FROM CABINET!
declare
	un_id	integer;
	usid	integer;
	gid	bigint;
	pid	bigint;
	sid	bigint;
	gname	character varying = (uname || ' admins');

	us_template	integer = 18;
	us_demo		integer = 31;
	gid_spectro	bigint	= 102283;

begin
	if(age(now(), (select last_create_promo_universe from cur_state where uid=0)) < interval '5 sec')
	then
		raise exception 'Due to anti DOS-attack policy creating promo can be performed in %', (interval '1 minutes')-age((select last_create_promo_universe from cur_state where uid=0));
	end if;

	un_id = "uniNew"(uname);

	update universes set bill_maxlogins=50, bill_maxtask=null, description=uni_desc where uid=un_id;
	--insert into bill_univere_tarrif(tarrif, unid) values(1, un_id);
	--perform "billIncome"(un_id, get_usid(), 2, 0);

	if(exists (select 1 from users where email=lower(mail)))
	then
		raise exception 'Same email is already registered';
		rollback;
	end if;

	--(DROP_ROLE) EXECUTE 'CREATE ROLE "' || log_name || '" WITH LOGIN INHERIT';

	INSERT INTO users (firstname, lastname, lid, langid, email, icq, phone, flags)
		select "firstName", "lastName", log_name, (select lang from universes where uid=un_id), lower(mail), creator_icq, creator_phone, 8
			; --(DROP_ROLE) from pg_roles where rolname=log_name;

	usid = "getUserID_byLogin"(log_name);
	insert into users_universes(userid, unid, flags) values (usid, un_id, 2);

	--gid = "newGroup"(uname || ' admins', un_id);
	INSERT INTO groups(name, unid) VALUES (gname, un_id);
	gid = (select uid from groups where name=gname and unid=un_id);

	--perform "perm_GrantToGroup"(0, gid, -2);
	INSERT INTO perm_groups(groupid, taskid, privileg) VALUES (gid, 0, -2);
	INSERT INTO users_groups(userID, groupID) VALUES (get_usid(), gid);

	perform "userGroupAddTo"(usid, gid);

	perform "zDupAct"(un_id, us_template);
	perform "zDupTag"(un_id, us_template);

	pid = "newProject_00"(uname || ' first project', un_id);

	--sid = "siteNew"(uname || ' remote storage', 'storage.cerebrohq.com:45431:4080', un_id);
	--update sites set size_quota=15::bigint*1024*1024*1024, storageid=1 where uid=sid;
	sid = "siteSizeQuotaSet"(un_id, 15::bigint*1024*1024*1024);

	perform "siteProjectSet"(true, sid, pid);

	perform "uniSetLang"(un_id, lang_id);

	perform "userSetLang"(usid, lang_id);
	perform "unwatchEmailUpdateUser"(usid, '2000-01-01 10:00:00+03'::timestamp with time zone, 0, 86400);

	perform "userActivityAddTo"(usid, 0);

	--perform "uniUserAddTo"(usid, us_demo);
	insert into users_universes(userid, unid) values (usid, us_demo);

	--perform "userGroupAddTo"(usid, gid_spectro);
	INSERT INTO users_groups(userID, groupID) VALUES (usid, gid_spectro);

	update cur_state set last_create_promo_universe=now() where uid = 0;

	perform "statusUniverseInit"(un_id);
	perform "roleInitForUniverse"(un_id);

	--perform "userGroupRemoveFrom"(get_usid(), gid);
	DELETE FROM users_groups WHERE userID=get_usid() and groupID = gid;

	perform "zUniPopulateDefaultNotify"(un_id);

	perform "log"(0, un_id, usid, 'new promo universe: <' || uname || '>. admin: <' || log_name || '>. email: ' || mail);

	return un_id;
end
$$;

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

	INSERT INTO status(uid, "name", flags, order_no, description, icon_xpm, color, unid, perm_leave_bits, perm_enter_bits)
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
				  perm_enter_bits integer
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

CREATE OR REPLACE FUNCTION "zzSweepUser"(_user_id integer) RETURNS void
    LANGUAGE plpgsql STRICT
    AS $$
begin
	if(_user_id>10)
	then
		UPDATE cur_state set debug=true where uid=0;

		begin
			delete from users_universes WHERE userid=_user_id;
			DELETE FROM users_groups_visible WHERE 	userID=_user_id;
			DELETE FROM users_groups WHERE 	userID=_user_id;
			DELETE FROM perm_users WHERE 	userID=_user_id;
			DELETE FROM users_activities where userID=_user_id and activityid=0;
			delete from logins where userid=_user_id;
			delete from logs where userid=_user_id;

			--(DROP_ROLE)
			-- if(exists (select 1 from pg_roles where rolname=(select lid from users where uid=_user_id)))
			-- then
			-- 	EXECUTE 'DROP ROLE ' || (select lid from users where uid=_user_id);
			-- end if;

			delete from users where uid=_user_id;

			raise notice 'removed :%', _user_id;
		exception
		when FOREIGN_KEY_VIOLATION then
			raise notice 'keeped :% %', _user_id, (select firstname || ' ' || lastname from users where uid=_user_id);
		end;

		UPDATE cur_state set debug=false where uid=0;
	end if;
end
$$;


CREATE OR REPLACE FUNCTION "getUserID_byLogin"(login name) RETURNS integer
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    AS $_$
	SELECT uid from users where lid = $1;
$_$;

CREATE OR REPLACE FUNCTION "queryUser_00"("userID" integer) RETURNS "tUser_00"
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    AS $_$
select
	users.mtm
	, users.uid
	, users.del
	, "userNameDisplay"(users.uid)
	, users.lid
	, users.email
	, users.icq
	, users.phone
	, null::boolean --users.isclient
from
	users
where
	users.uid=$1 and "perm_IsUserVisible"(get_usid(), users.uid, 1)>=2;
$_$;

CREATE OR REPLACE FUNCTION "userGetLogin"(_user_id integer) RETURNS name
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $_$
	select users.lid from users where users.uid=$1 and "perm_IsUserVisible"(get_usid(), $1, 0)>=2;
$_$;

CREATE OR REPLACE FUNCTION "userQuery_01"(_user_id integer) RETURNS "tUser_01"
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $_$
	select
		users.mtm, users.uid
		, users.del
		, firstname
		, lastname
		, (case when "perm_IsUserVisible"(get_usid(), uid, 0)>=2 then users.lid else null end)
		, (case when "perm_IsUserVisible"(get_usid(), uid, 0)>=2 then users.email else null end)
		, (case when "perm_IsUserVisible"(get_usid(), uid, 0)>=2 then users.icq else null end)
		, (case when "perm_IsUserVisible"(get_usid(), uid, 0)>=2 then users.phone else null end)
		, flags
	from
		users
	where
		users.uid=$1
		and "perm_IsUserVisible"(get_usid(), $1, 1)>0;
$_$;

CREATE OR REPLACE FUNCTION "userBlankList"() RETURNS SETOF users
    LANGUAGE sql STRICT SECURITY DEFINER
    AS $$
	select users.*
		from users
		--(DROP_ROLE) inner join pg_authid on pg_authid.rolname = users.lid
		where
			del = 0
			and lid is not null
			and ad_sid is null
			and coalesce(email, '') != ''
			and not exists (select 1 from web_auth where usid = users.uid) --rolpassword is null
			--and mtm > '2018-01-01'::date -- exclude arch logins
			--and creationtime > '2018-01-01'::date -- exclude arch logins
$$;

CREATE OR REPLACE FUNCTION "webCheckPass"(user_name name, user_pass name) RETURNS integer
    LANGUAGE plpgsql STRICT SECURITY DEFINER COST 10
    AS $$
declare
	ws_id	bigint;
	us_id	integer;
	us_pwd  name;
	ch_pwd	text;
	_salt	text;
	_xml	text;
	_x_conf	xml;
	_p		text[];
	_domain text;

begin
	select uid into us_id from users where lid = user_name;

	if us_id is null
	then
		-- do password check. Returns -1 if failed
		--(DROP_ROLE) us_pwd = (select rolpassword from pg_authid where rolname = user_name);
		-- ch_pwd = ('md5' || encode(digest(user_pass || user_name, 'md5'), 'hex'));
		--
		-- if(us_pwd = ch_pwd)
		-- then
		-- 	perform "webCheckHBA"(us_id, 'ordinary');
		-- 	return us_id;
		-- end if;
	-- else
		us_id = (select uid from users where email = user_name);
	end if;

	if us_id is not null
	then
		if (select lid from users where uid = us_id) is null
		then
			-- disable LUMPEN
			return NULL;
		end if;

		select salt, hash from web_auth into _salt, us_pwd where usid = us_id;
		ch_pwd = ('md5' || encode(digest(user_pass || _salt, 'md5'), 'hex'));

		if(us_pwd = ch_pwd)
		then
			perform "webCheckHBA"(us_id, 'ordinary');
			return us_id;
		end if;
	end if;

	_x_conf = (select access_conf from cur_state where uid=0);
	if (_x_conf is not null)
	then
		-- here might be user@domain login format. Extract user domain
		if us_id is null
		then
			if coalesce(array_lower(xpath('/config/ldapSync/searchDN', _x_conf), 1), 0) = 1
			then
				_xml = (xpath('/config/ldapSync/searchDN/text()', _x_conf))[1];
				_p = string_to_array(_xml, ',');

				_domain = null;
				for _xml in (select unnest(_p))
				loop
					if (_xml like 'dc=%')
					then
						_domain = coalesce(_domain || '.', '') || substring(_xml from 4);
					end if;
				end loop;

				if user_name like ('%@' || _domain)
				then
					_xml = left(user_name, char_length(user_name) - char_length(_domain) - 1);
					us_id = (select uid from users where ldap_login = _xml and lid = _xml);
				end if;

				--raise exception '_domain = %, _p %, _xml %, us_id %', _domain,  _p, _xml, us_id; --xpath('/config/ldapSync/searchDN', _x_conf);
			end if;
		end if;

		if not (us_id is null)
		then
			_xml = xmlserialize(DOCUMENT _x_conf as text);

			BEGIN
				if "webCheckLdapPass"(_xml, (select lid from users where uid=us_id), user_pass) then
					perform "webCheckHBA"(us_id, 'ldapPassword');
					return us_id;
				end if;
			EXCEPTION
				WHEN internal_error THEN
					RAISE NOTICE 'ldap-bind failed (1)';
			END;

			BEGIN
				if "webCheckLdapPass"(_xml, (select ldap_dn from users where uid=us_id), user_pass) then
					perform "webCheckHBA"(us_id, 'ldapPassword');
					return us_id;
				end if;
			EXCEPTION
				WHEN internal_error THEN
					RAISE NOTICE 'ldap-bind failed (2)';
			END;
		end if;
	end if;

	return NULL;
end
$$;
