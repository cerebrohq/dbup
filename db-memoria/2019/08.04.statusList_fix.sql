-- FUNCTION: public."statusListByTask_01"(bigint)

-- DROP FUNCTION public."statusListByTask_01"(bigint);

CREATE OR REPLACE FUNCTION public."statusListByTask_01"(
	__tid bigint)
    RETURNS SETOF status 
    LANGUAGE 'plpgsql'

    COST 1000
    STABLE SECURITY DEFINER 
    ROWS 1000
AS $BODY$

declare
	_ret	status;
		_tid		bigint				= "refResolve"(__tid);
	_unid		int				= "getUnid"(_tid);
	_task_perms	bigint				=  perm(get_usid(), _tid, 0);
	_cur_status bigint; --				= (select cc_status from tasks where uid=_tid);
	_actid bigint;	
	_cur_status_leave_perms int; --			= "statusPerm"(_cur_status, _unid, false);
	_can_leave boolean; --				= "statusIsPerms"(_tid, _task_perms, _cur_status_leave_perms);
	_true_task boolean				= (not exists (select 1 from tasks where lnk_front_parent=_tid and del=0));
begin	

	select cc_status, activityid into _cur_status, _actid from tasks where uid=_tid;
	
	_cur_status_leave_perms = "statusPerm"(_cur_status, _unid, false);
	_can_leave = "statusIsPerms"(_tid, _task_perms, _cur_status_leave_perms);
												   
	for _ret in (select * from "statusList_01"())
	loop
		if _unid=_ret.unid and 
		(	_cur_status is not distinct from _ret.uid
			or (
				_can_leave and "statusIsPerms"(_tid, _task_perms, _ret.perm_enter_bits)
				and (_true_task or (_ret.uid is null) or (select (flags & 2)!=0 from status where uid=_ret.uid))
				and "statusHasActivity"(_ret.uid, _actid)
			)
		)
		then
			return next _ret;
		end if;
	end loop;
end

$BODY$;

ALTER FUNCTION public."statusListByTask_01"(bigint)
    OWNER TO sa;
