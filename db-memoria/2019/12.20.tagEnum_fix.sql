
CREATE OR REPLACE FUNCTION public."tagEnumUpdate"(
	id bigint,
	dl smallint,
	nm character varying)
RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$

begin
	perform "perm_checkGlobal"((select unid from tag_schema inner join tag_enums on tag_enums.tagid=tag_schema.uid where tag_enums.uid=id), 'mng_tag_act');

	if(dl is not NULL)
	then
		update tag_enums set muid="getUserID_bySession"(), mtm=now(), del=NEXTVAL('del_seq')::smallint where uid=id;
	end if;

	if(nm is not NULL)
	then
		update tag_enums set muid="getUserID_bySession"(), mtm=now(), sval=nm where uid=id;
	end if;
end

$BODY$;

ALTER FUNCTION public."tagEnumUpdate"(bigint, smallint, character varying)
    OWNER TO sa;

CREATE OR REPLACE FUNCTION public."tagEnumAdd"(
	tag_id bigint,
	nm character varying)
    RETURNS bigint
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$

DECLARE
	id bigint;
begin
	perform "perm_checkGlobal"((select unid from tag_schema where uid=tag_id), 'mng_tag_act');

	id = (select uid from tag_enums where tagid=tag_id and sval=nm limit 1);
	if(id is null)
	then
		id = "newID"();
		INSERT INTO tag_enums(uid, sval, tagid) VALUES (id, nm, tag_id);
	else
		update tag_enums set del=0, muid="getUserID_bySession"(), mtm=now() where uid=id;
		
	end if;
	
	return id;
end

$BODY$;

ALTER FUNCTION public."tagEnumAdd"(bigint, character varying)
    OWNER TO sa;
