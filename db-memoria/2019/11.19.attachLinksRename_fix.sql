-- FUNCTION: public."attachLinksRename"(bigint, text, text)

-- DROP FUNCTION public."attachLinksRename"(bigint, text, text);

CREATE OR REPLACE FUNCTION public."attachLinksRename"(
	_prj_id bigint,
	name_start text,
	new_name_start text)
    RETURNS integer
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$
-- e.g. select "attachLinksRename"(12353412561, '//server/folder', '//new_server/folder1');
declare
	_unid int = "getUnid_byPrj"(_prj_id);
	count_to_change integer;
begin

	perform "perm_checkTask"(0, 'mng_task', _unid);
	   
	count_to_change = (select count(*) from attachments as a inner join events as e on e.uid=a.eventid inner join tasks as t on t.uid= e.taskid inner join projects as p on p.uid=t.prj_id 
						where ((t.flags & 0000001)=0) and p.unid=_unid and p.uid=_prj_id and a.tag=5 and a.originalfilename like (name_start || '%'));
																											  
	update attachments set originalfilename=replace(originalfilename, name_start, new_name_start) 
	where
	uid=any(select a.uid from attachments as a inner join events as e on e.uid=a.eventid inner join tasks as t on t.uid= e.taskid inner join projects as p on p.uid=t.prj_id 
	where ((t.flags & 0000001)=0) and p.unid=_unid and p.uid=_prj_id and a.tag=5 and a.originalfilename like (name_start || '%'));
																						  
	--raise exception 'good';
																											  
	return count_to_change;
end
$BODY$;

ALTER FUNCTION public."attachLinksRename"(bigint, text, text)
    OWNER TO sa;
