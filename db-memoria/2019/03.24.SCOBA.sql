
CREATE OR REPLACE FUNCTION public."userSetWebPassword"(
	user_id integer,
	pass character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
declare
	_hash	text;
	_salt	text;
begin
	--delete from web_sid where usid = user_id;
	--delete from users_web_sids where usid = user_id;
	
	if(pass is null)
	then
		delete from web_auth where usid=user_id;
	else
		if((select ad_sid from users where uid=user_id) is not null)
		then
			raise exception 'Can not change password for Active Directory imported user';
		end if;
		
		_salt = random()::text;
		_hash = 'md5' || encode(digest(pass || _salt, 'md5'), 'hex');
		
		if exists (select 1 from web_auth where usid=user_id)
		then
			update web_auth set hash=_hash, salt=_salt where usid=user_id;
		else
			insert into web_auth(usid, hash, salt) Values(user_id, _hash, _salt);
		end if;
	end if;

	return user_id;	
end
$BODY$;

