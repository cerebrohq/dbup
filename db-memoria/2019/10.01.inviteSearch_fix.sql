CREATE OR REPLACE FUNCTION public."inviteSearch_Email"(
	var character varying)
    RETURNS SETOF user_t 
    LANGUAGE 'sql'

    COST 100
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$

	select 
		mtm
		, uid
		, coalesce(firstName, '') || ' ' || coalesce(lastName, '')
		, 0
	from users where lower(email)=lower($1) and lid is not null;
		-- LUMPEN: and users.del=0 and (users.flags & 2) = 0

$BODY$;

ALTER FUNCTION public."inviteSearch_Email"(character varying)
    OWNER TO sa;
	
-- FUNCTION: public."inviteSearch_FullName"(character varying)

-- DROP FUNCTION public."inviteSearch_FullName"(character varying);

CREATE OR REPLACE FUNCTION public."inviteSearch_FullName"(
	var character varying)
    RETURNS SETOF user_t 
    LANGUAGE 'sql'

    COST 100
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select 
		mtm
		, uid
		, (coalesce(firstName, '') || ' ' || coalesce(lastName, '')) as fn
		, 0
	from 
		users 
	where 
		length($1)>5
		and (lower((firstName || ' ' || lastName)) like lower("getEscapedLike"($1)) or lower((lastName || ' ' || firstName)) like lower("getEscapedLike"($1)))
		and lid is not null
		-- LUMPEN: and users.del = 0 and (users.flags & 2) = 0
	order by
		fn
	limit 30;
$BODY$;

ALTER FUNCTION public."inviteSearch_FullName"(character varying)
    OWNER TO sa;

-- FUNCTION: public."inviteSearch_Login"(character varying)

-- DROP FUNCTION public."inviteSearch_Login"(character varying);

CREATE OR REPLACE FUNCTION public."inviteSearch_Login"(
	var character varying)
    RETURNS SETOF user_t 
    LANGUAGE 'sql'

    COST 100
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$

	select 
		mtm
		, uid
		, (coalesce(firstName, '') || ' ' || coalesce(lastName, ''))
		, 0
	from users where lower(lid)=lower($1);

$BODY$;

ALTER FUNCTION public."inviteSearch_Login"(character varying)
    OWNER TO sa;
