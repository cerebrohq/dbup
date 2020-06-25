-- FUNCTION: public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying)

-- DROP FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public."zCreatePromoUniverseEnd"(
	uname character varying,
	mail character varying,
	log_name character varying,
	"firstName" text,
	"lastName" text,
	lang_id integer,
	creator_icq character varying,
	creator_phone character varying,
	uni_desc character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$

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
	low_mail character varying = lower(mail);	
	
begin	
	if(age(now(), (select last_create_promo_universe from cur_state where uid=0)) < interval '5 sec')
	then
		raise exception 'Due to anti DOS-attack policy creating promo can be performed in %', (interval '1 minutes')-age((select last_create_promo_universe from cur_state where uid=0));
	end if;

	un_id = "uniNew"(uname);

	update universes set bill_maxlogins=50, bill_maxtask=null, description=uni_desc where uid=un_id;
	--insert into bill_univere_tarrif(tarrif, unid) values(1, un_id);
	--perform "billIncome"(un_id, get_usid(), 2, 0);

	if(not exists (select 1 from users where email=low_mail))
	then		
		--EXECUTE 'CREATE ROLE "' || low_mail || '" WITH LOGIN INHERIT';

		INSERT INTO users (firstname, lastname, lid, langid, email, icq, phone, flags) 
			select "firstName", "lastName", low_mail, (select lang from universes where uid=un_id), low_mail, creator_icq, creator_phone, 8
			; --(DROP_ROLE) from pg_roles where rolname=log_name;

		usid = (select uid from users where email=low_mail);
		
		perform "userSetLang"(usid, lang_id);
		perform "unwatchEmailUpdateUser"(usid, '2000-01-01 10:00:00+03'::timestamp with time zone, 0, 86400);		
		
		/*if((select "server" from cur_state where uid=0) = 0)
		then
			insert into users_universes(userid, unid) values (usid, us_demo);
			INSERT INTO users_groups(userID, groupID) VALUES (usid, gid_spectro);
		end if;*/
		   
	else
		if((select lid from users where email=low_mail) is null)
		then
			--EXECUTE 'CREATE ROLE "' || low_mail || '" WITH LOGIN INHERIT';
			update users set lid=low_mail where email=low_mail;
		end if;	

		update users set del=0 where email=low_mail;
	end if;	
		
	usid = (select uid from users where email=low_mail);
	insert into users_universes(userid, unid, flags) values (usid, un_id, 2);

	--gid = "newGroup"(uname || ' admins', un_id);
	INSERT INTO groups(name, unid) VALUES (gname, un_id);
	gid = (select uid from groups where name=gname and unid=un_id);

	--perform "perm_GrantToGroup"(0, gid, -2);
	INSERT INTO perm_groups(groupid, taskid, privileg) VALUES (gid, 0, -2);
	INSERT INTO users_groups(userID, groupID) VALUES (get_usid(), gid);

	perform "userGroupAddTo"(usid, gid);

	perform "zActivityUniverseInit"(un_id);
	--perform "zDupTag"(un_id, us_template);

	pid = "newProject_00"(uname || ' First Project', un_id);

	--sid = "siteNew"(uname || ' remote storage', 'storage.cerebrohq.com:45431:4080', un_id);
	--update sites set size_quota=15::bigint*1024*1024*1024, storageid=1 where uid=sid;
	sid = "siteSizeQuotaSet"(un_id, 30::bigint*1024*1024*1024);
	
	perform "siteProjectSet"(true, sid, pid);

	perform "uniSetLang"(un_id, lang_id);	

	perform "userActivityAddTo"(usid, 0);				

	update cur_state set last_create_promo_universe=now() where uid = 0;

	perform "statusUniverseInit"(un_id);
	perform "roleInitForUniverse"(un_id);

	--perform "userGroupRemoveFrom"(get_usid(), gid);
	DELETE FROM users_groups WHERE userID=get_usid() and groupID = gid;

	perform "zUniPopulateDefaultNotify"(un_id);

	perform "log"(0, un_id, usid, 'new promo universe: <' || uname || '>. admin: <' || log_name || '>. email: ' || mail);

	return un_id;
end

$BODY$;

ALTER FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying)
    OWNER TO sa;

GRANT EXECUTE ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) TO sa_web;

GRANT EXECUTE ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) TO sa;

GRANT EXECUTE ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) TO system_readers;

GRANT EXECUTE ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) TO sa_passrecover;

GRANT EXECUTE ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) TO sa_cabinet;

REVOKE ALL ON FUNCTION public."zCreatePromoUniverseEnd"(character varying, character varying, character varying, text, text, integer, character varying, character varying, character varying) FROM PUBLIC;
 