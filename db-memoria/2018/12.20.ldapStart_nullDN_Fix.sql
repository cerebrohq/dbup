CREATE OR REPLACE FUNCTION public."webCheckLdapPass"(_conf text,_user text,_pass text)
    RETURNS boolean
    LANGUAGE 'c'
    STABLE STRICT SECURITY DEFINER
    PARALLEL UNSAFE
    COST 10
AS '$libdir/libmalosol.so', 'ldap_check_password';

CREATE OR REPLACE FUNCTION public."webCheckPass"(
	user_name name,
	user_pass name)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 10
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
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
	_dn		text;

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
					--RAISE NOTICE 'ldap-bind (1)';
					return us_id;
				end if;
			EXCEPTION
				WHEN internal_error THEN
					RAISE NOTICE 'ldap-bind failed (1)';
			END;

			_dn = (select ldap_dn from users where uid=us_id);
			if coalesce(_dn, '') != ''
			then
				BEGIN
					if "webCheckLdapPass"(_xml, _dn, user_pass) then
						perform "webCheckHBA"(us_id, 'ldapPassword');
						-- RAISE NOTICE 'ldap-bind (2) %', _dn;
						return us_id;
					end if;
				EXCEPTION
					WHEN internal_error THEN
						RAISE NOTICE 'ldap-bind failed (2)';
				END;
			end if;
		end if;
	end if;

	return NULL;
end
$BODY$;

