
CREATE OR REPLACE FUNCTION public."htUpdate"(
	_uid bigint,
	_new_name text)
    RETURNS bigint
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
DECLARE	
	un_id int = (select unid from ht_schema where uid = _uid);
	
BEGIN	
	perform "perm_checkGlobal"(un_id, 'mng_tag_act');
	update ht_schema set mtm = now(), name = _new_name where uid = _uid;	

	return _uid;
END
$BODY$;

ALTER FUNCTION public."htUpdate"(bigint, text)
    OWNER TO sa;


