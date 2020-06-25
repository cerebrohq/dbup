-- FUNCTION: public."userMailchimpList"()
-- DROP FUNCTION public."userMailchimpList"();

CREATE OR REPLACE FUNCTION public."userMailchimpList"(
	)
RETURNS SETOF "tUserMailchimp" 
    LANGUAGE 'sql'
    COST 100
    STABLE STRICT SECURITY DEFINER 
    ROWS 1000
AS $BODY$
	select u.mtm
	, u.uid
	, u.email
	, u.firstname
	, u.lastname	
	, u.phone
	, un.name
	, (select (tarrif_id::text || '+' || (case when (bills.stop_date > now()::date) then 'lic_valid' else 'lic_expired' end))::text from bills where bills.unid=uu.unid order by stop_date desc limit 1) 
	from users as u join users_universes as uu on u.uid=uu.userid join universes as un on un.uid=uu.unid 
	where 
	uu.del=0 and u.del=0 and u.email is not null and u.lid is not null
	and (("perm_Root"(u.uid, uu.unid) & -2)=-2);
			
$BODY$;

ALTER FUNCTION public."userMailchimpList"()
    OWNER TO sa;
