-- FUNCTION: public."adUserConvertToBasic"(integer, text)

-- DROP FUNCTION public."adUserConvertToBasic"(integer, text);

CREATE OR REPLACE FUNCTION public."adUserConvertToBasic"(
	user_id integer,
	password_str text)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_u	users;
	un_id integer;
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

	select unid into un_id from users_universes where userid=user_id limit 1;
	perform "userSetWebPassword"(user_id, password_str);
	perform "log"(1, un_id, user_id, 'user coverted to basic. login: <' || login_name || '>');

	return user_id;
end
$BODY$;

ALTER FUNCTION public."adUserConvertToBasic"(integer, text)
    OWNER TO sa;
