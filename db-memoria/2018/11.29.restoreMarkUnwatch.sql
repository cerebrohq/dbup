/*

Восстановлен механизм пометки задачи, как непрочитанной.

Добавленo:

Процедура
logNote_singleMe 
для добавления нотификации для самого себя (пометить как непрочитанное)

Измененo:

Процедуры
unwatchAppendToList
notifyDefinition, для того чтобы на категорю Bm возвращалось имя категории а не пустая строка.

Изменены флаги категории Bm в таблице
logs_category. Убран флаг mark as SENT now

в конце вызывается update logs_category

*/

CREATE OR REPLACE FUNCTION public."logNote_singleMe"(
	_category text,
	_usid integer,
	_tid bigint,
	_param bigint,
	_details text)
    RETURNS bigint
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	_logid		bigint;
	_note_flags	int;
	_me			int = get_usid();
begin
	
	_logid = "log_row"(_category, _me, "getUnid"(_tid), _tid, _param, _details);

	
	if _logid is not null -- and _me != _usid
	then		
		_note_flags	= (select flags from logs_category where skey = _category);		
		perform "notifyEventUser"(_logid, _category, _usid, _tid, null, _note_flags);
	end if;

	return _logid;
end

$BODY$;

ALTER FUNCTION public."logNote_singleMe"(text, integer, bigint, bigint, text)
    OWNER TO sa;



-- Function: "unwatchAppendToList"(bigint)

-- DROP FUNCTION "unwatchAppendToList"(bigint);

CREATE OR REPLACE FUNCTION "unwatchAppendToList"(tid bigint)
  RETURNS void AS
$BODY$
begin
	-- rename to "followListAdd"
	
	perform "logNote_singleMe"('Bm', get_usid(), "refResolve"(tid), null, null);	
end
$BODY$
  LANGUAGE plpgsql VOLATILE STRICT SECURITY DEFINER
  COST 100;
ALTER FUNCTION "unwatchAppendToList"(bigint)
  OWNER TO sa;

-- FUNCTION: public."notifyDefinition"(integer, integer, text, bigint, bigint)

-- DROP FUNCTION public."notifyDefinition"(integer, integer, text, bigint, bigint);

CREATE OR REPLACE FUNCTION public."notifyDefinition"(
	_scope integer,
	_usid integer,
	_cat text,
	_tid bigint,
	_eid bigint)
    RETURNS text
    LANGUAGE 'plpgsql'

    COST 100
    STABLE 
AS $BODY$

declare
	-- Enumerate User, Project, Universe attributes for Definition
	_attrib		text;
	_pid		bigint = (select prj_id from tasks where uid = _tid);
	_unid		int = "getUnid_byPrj"(_pid);
	_task_perms	bigint = "perm"(_usid, _tid, 0);
	_category	text = _cat;
	_stAllDef	text;
	_status_id	bigint;
	_ret		text;
	_defa_res	boolean;

begin
	--raise notice 'ENTER: notifyDefinition (scope %, tid %)', _scope, _tid;
	
	if _category = 'Bm' -- bookmark
	then
		return 'Bm';
	end if;

	-- Clarify status Id
	if _cat = 'St'
	then
		if exists (select 1 from status where uid = _eid) -- check if _eid is status
		then
			_status_id = _eid;
		else
			_status_id = (select statusid from events where uid = _eid);
		end if;

		if _status_id is null 
		then
			_category = _category || '-null';
		else 
			_category = _category || '-' || _status_id::text;
		end if;
	end if;

	_attrib = (select val from attrib_user where usid = _usid and key = _scope);
	if _attrib is not null
	then
		if _cat = 'St' then -- check All Status Disable
			_stAllDef = "notifyDefinitionLookup"(_attrib, 'StAll', _task_perms);
			if _stAllDef = '-' then 
				return _stAllDef; 
			end if;
		end if;
		
		_ret = "notifyDefinitionLookup"(_attrib, _category, _task_perms);
		if _ret is not null then 
			return _ret;
		end if;
	end if;

	_attrib = (select val from attrib_project where pid = _pid and key = _scope);
	if _attrib is not null
	then
		_ret = "notifyDefinitionLookup"(_attrib, _category, _task_perms);
		if _ret is not null then 
			return _ret;
		end if;
	end if;

	_attrib = (select val from attrib_universe where unid = _unid and key = _scope);
	if _attrib is not null
	then
		_ret = "notifyDefinitionLookup"(_attrib, _category, _task_perms);
		if _ret is not null then 
			return _ret;
		end if;
	end if;


	if _ret is null then
		_defa_res = (select (flags & (1 <<(8 + _scope-100))!=0) from logs_category where skey = _cat);
		-- raise notice '.... use DEFA notify scope %, _ret %', _scope, _defa_res;
		
		if _defa_res then
			--raise exception 'DEFA ON scope %', _scope;
			return '';
		end if;
	end if;
	
	return null;
end

$BODY$;

ALTER FUNCTION public."notifyDefinition"(integer, integer, text, bigint, bigint)
    OWNER TO sa;


update logs_category set flags=1 where uid=1003;
