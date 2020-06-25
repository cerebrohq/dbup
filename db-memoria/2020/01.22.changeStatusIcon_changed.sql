
CREATE OR REPLACE FUNCTION public."statusSetIcon_02"(
	_uid bigint,
	_icon text)
	RETURNS bigint
	LANGUAGE 'plpgsql'

	COST 100
	VOLATILE SECURITY DEFINER 
AS $BODY$

declare

begin
	-- _icon argument is plain SVG or base64-encoded image
	perform "perm_checkGlobal"((SELECT unid FROM status WHERE uid=_uid), 'mng_tag_act');
	
	IF COALESCE(_icon, '') = ''
	THEN
		UPDATE status SET mtm = now(), icon = NULL, icon_xpm = NULL, icon_hash = NULL WHERE uid = _uid;
	ELSE
		UPDATE status SET mtm = now(), icon = _icon WHERE uid = _uid;
	END IF;
	
	return _uid;
end

$BODY$;

--------------------------------------------------------

CREATE OR REPLACE FUNCTION public."statusResetIcon"(
	_unid integer)
	RETURNS void
	LANGUAGE 'plpgsql'

	COST 100
	VOLATILE SECURITY DEFINER 
AS $BODY$

declare

begin
	perform "perm_checkGlobal"(_unid, 'mng_tag_act');
	
	update status
	set
		mtm = now()
		, color = -5927847
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 8 10">
<path d="M7,10H6a1,1,0,0,1-1-.91V.91A1,1,0,0,1,6,0H7A1,1,0,0,1,8,.91V9.09A1,1,0,0,1,7,10ZM2,10H1a1,1,0,0,1-1-.91V.91A1,1,0,0,1,1,0H2A1,1,0,0,1,3,.91V9.09A1,1,0,0,1,2,10Z" fill="#a58c59"/>
</svg>'
	where unid=$1 and (name='на паузе' or name='paused');
	
	update status
	set
		mtm=now()
		, color = -8996650
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 12.03 10.03">
<path d="M12,5.4a1.15,1.15,0,0,1-.21.33l-4,4A1,1,0,1,1,6.31,8.32L8.61,6H1A1,1,0,0,1,1,4H8.61l-2.3-2.3A1,1,0,1,1,7.73.29l4,4a1,1,0,0,1,.22.32A1,1,0,0,1,12,5.4Z" fill="#76b8d6"/>
</svg>'
	where unid=$1 and (name='готова к работе' or name='ready to start');
	
	update status
	set
		mtm=now()
		, color = -4494477
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 14 16">
<path d="M11.56,16H7.19a3.64,3.64,0,0,1-2.81-1.33L2.43,12.31,0,10.46A1.4,1.4,0,0,1,1.47,9.23a1.83,1.83,0,0,1,.76.17,28.86,28.86,0,0,1,2.64,1.54V2.15a.92.92,0,0,1,1.83,0V6.77h.6V.92a.92.92,0,0,1,1.83,0V6.77h.6V2.15a.92.92,0,0,1,1.83,0V6.77h.61V4A.92.92,0,1,1,14,4v9.54A2.45,2.45,0,0,1,11.56,16ZM9.43,12.36h0L11,14a.68.68,0,0,0,1,0h0a.69.69,0,0,0,0-1L10.4,11.39,12,9.8a.69.69,0,0,0,0-1,.67.67,0,0,0-1,0h0L9.44,10.4,7.86,8.82a.68.68,0,0,0-1,0h0a.69.69,0,0,0,0,1l1.57,1.59L6.9,13a.69.69,0,0,0,0,1,.68.68,0,0,0,1,0h0l1.57-1.59Z" fill="#bb6b73"/>
</svg>'
	where unid=$1 and (name='на переработку' or name='could be better');
	
	update status
	set
		mtm=now()
		, color = -6975521
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 10.81 11.9">
<path d="M.49,0A.49.49,0,0,0,0,.5H0V11.4H0a.49.49,0,0,0,.49.49.52.52,0,0,0,.29-.09h0l9.75-5.4a.51.51,0,0,0,.23-.67.53.53,0,0,0-.25-.24L.78.09h0A.52.52,0,0,0,.49,0Z" fill="#958fdf"/>
</svg>'
	where unid=$1 and (name='в работе' or name='in progress');
	
	update status
	set
		mtm=now()
		, color = -3358100
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 15.5 14.26">
<path d="M14.32,14.26H1.18a.6.6,0,0,1,0-1.19H14.32a.59.59,0,0,1,.52.66A.6.6,0,0,1,14.32,14.26Zm0-2.34H1.19A1.19,1.19,0,0,1,0,10.73V9.84A.9.9,0,0,1,.67,9H.75c.2-.05,4.07-.86,4.6-1,.7-.14,1.21-.24,1.21-1.19V6.56a1.87,1.87,0,0,0-.64-1.1A3.51,3.51,0,0,1,4.77,3a3,3,0,0,1,6,0A3.5,3.5,0,0,1,9.59,5.46a1.84,1.84,0,0,0-.65,1.1V6.8c0,1,.51,1.06,1.21,1.19l4.16.87.45.1h.06a.9.9,0,0,1,.68.87v.89a1.19,1.19,0,0,1-1.19,1.19Z" fill="#ccc26c"/>
</svg>'
	where unid=$1 and (name='на утверждение' or name='pending review');
	
	update status
	set
		mtm = now()
		, color = -10507146
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 14.76 11.06">
<path d="M13.5,0a1.21,1.21,0,0,0-.84.37L4.93,8.1,2.11,5.28A1.23,1.23,0,1,0,.33,7s0,0,0,0L4.06,10.7a1.23,1.23,0,0,0,1.74,0l8.59-8.59a1.24,1.24,0,0,0,0-1.74A1.25,1.25,0,0,0,13.5,0Z" fill="#5fac76"/>
</svg>'
	where unid=$1 and (name='выполнена' or name='completed');
	
	update status
	set
		mtm = now()
		, color = -6194326
		, icon = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 14.08 16">
<path d="M12.8,16H1.28A1.28,1.28,0,0,1,0,14.72V7A1.28,1.28,0,0,1,1.28,5.76H2.56V4.48A4.49,4.49,0,0,1,7,0a.59.59,0,0,1,.23.05,4.46,4.46,0,0,1,4.25,4.43V5.76H12.8A1.28,1.28,0,0,1,14.08,7v7.68A1.28,1.28,0,0,1,12.8,16ZM7,9a2,2,0,1,0,2,2A2,2,0,0,0,7,9ZM7,1.28a3.2,3.2,0,0,0-3.2,3.2h0V5.76h6.4V4.48A3.2,3.2,0,0,0,7,1.28Z" fill="#a17b6a"/>
</svg>'
	where unid=$1 and (name='закрыта' or name='closed');
	
end

$BODY$;

--------------------------------------------------------

CREATE OR REPLACE FUNCTION public."statusUniverseInit"(
	_unid integer)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	_pause bigint = "newID"();
	_ready bigint = "newID"();
	_refac bigint = "newID"();
	_working bigint = "newID"();
	_wait_confirm bigint = "newID"();
	_done bigint = "newID"();
	_closed bigint = "newID"();
	_rule bigint = "newID"();
	_lang int = (select lang from universes where uid=_unid);
begin
	if exists (select 1 from status where unid=_unid)
	then
		raise notice 'skip for %', _unid;
		return;
	end if;

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_pause, (case when _lang=2 then 'на паузе' else 'paused' end)
			, 2, 0, '', -5927847, _unid, 3, 3
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 8 10">
<path d="M7,10H6a1,1,0,0,1-1-.91V.91A1,1,0,0,1,6,0H7A1,1,0,0,1,8,.91V9.09A1,1,0,0,1,7,10ZM2,10H1a1,1,0,0,1-1-.91V.91A1,1,0,0,1,1,0H2A1,1,0,0,1,3,.91V9.09A1,1,0,0,1,2,10Z" fill="#a58c59"/>
</svg>');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_ready, (case when _lang=2 then 'готова к работе' else 'ready to start' end)
			, 0 ,1 ,'', -8996650, _unid, 39, 3
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 12.03 10.03">
<path d="M12,5.4a1.15,1.15,0,0,1-.21.33l-4,4A1,1,0,1,1,6.31,8.32L8.61,6H1A1,1,0,0,1,1,4H8.61l-2.3-2.3A1,1,0,1,1,7.73.29l4,4a1,1,0,0,1,.22.32A1,1,0,0,1,12,5.4Z" fill="#76b8d6"/>
</svg>');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_refac, (case when _lang=2 then 'на переработку' else 'could be better' end)
			, 0, 2, '', -4494477, _unid, 39, 3
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 14 16">
<path d="M11.56,16H7.19a3.64,3.64,0,0,1-2.81-1.33L2.43,12.31,0,10.46A1.4,1.4,0,0,1,1.47,9.23a1.83,1.83,0,0,1,.76.17,28.86,28.86,0,0,1,2.64,1.54V2.15a.92.92,0,0,1,1.83,0V6.77h.6V.92a.92.92,0,0,1,1.83,0V6.77h.6V2.15a.92.92,0,0,1,1.83,0V6.77h.61V4A.92.92,0,1,1,14,4v9.54A2.45,2.45,0,0,1,11.56,16ZM9.43,12.36h0L11,14a.68.68,0,0,0,1,0h0a.69.69,0,0,0,0-1L10.4,11.39,12,9.8a.69.69,0,0,0,0-1,.67.67,0,0,0-1,0h0L9.44,10.4,7.86,8.82a.68.68,0,0,0-1,0h0a.69.69,0,0,0,0,1l1.57,1.59L6.9,13a.69.69,0,0,0,0,1,.68.68,0,0,0,1,0h0l1.57-1.59Z" fill="#bb6b73"/>
</svg>');
		
	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_working, (case when _lang=2 then 'в работе' else 'in progress' end)
			, 4, 3, '', -6975521, _unid, 7, 36
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 10.81 11.9">
<path d="M.49,0A.49.49,0,0,0,0,.5H0V11.4H0a.49.49,0,0,0,.49.49.52.52,0,0,0,.29-.09h0l9.75-5.4a.51.51,0,0,0,.23-.67.53.53,0,0,0-.25-.24L.78.09h0A.52.52,0,0,0,.49,0Z" fill="#958fdf"/>
</svg>');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
		_wait_confirm, (case when _lang=2 then 'на утверждение' else 'pending review' end) 
		, 0, 4, '', -3358100, _unid, 3, 36
		, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 15.5 14.26">
<path d="M14.32,14.26H1.18a.6.6,0,0,1,0-1.19H14.32a.59.59,0,0,1,.52.66A.6.6,0,0,1,14.32,14.26Zm0-2.34H1.19A1.19,1.19,0,0,1,0,10.73V9.84A.9.9,0,0,1,.67,9H.75c.2-.05,4.07-.86,4.6-1,.7-.14,1.21-.24,1.21-1.19V6.56a1.87,1.87,0,0,0-.64-1.1A3.51,3.51,0,0,1,4.77,3a3,3,0,0,1,6,0A3.5,3.5,0,0,1,9.59,5.46a1.84,1.84,0,0,0-.65,1.1V6.8c0,1,.51,1.06,1.21,1.19l4.16.87.45.1h.06a.9.9,0,0,1,.68.87v.89a1.19,1.19,0,0,1-1.19,1.19Z" fill="#ccc26c"/>
</svg>');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_done, (case when _lang=2 then 'выполнена' else 'completed' end)
			, 10, 5, '', -10507146, _unid, 3, 3
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 14.76 11.06">
<path d="M13.5,0a1.21,1.21,0,0,0-.84.37L4.93,8.1,2.11,5.28A1.23,1.23,0,1,0,.33,7s0,0,0,0L4.06,10.7a1.23,1.23,0,0,0,1.74,0l8.59-8.59a1.24,1.24,0,0,0,0-1.74A1.25,1.25,0,0,0,13.5,0Z" fill="#5fac76"/>
</svg>');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits, icon)
		VALUES ( 
			_closed, (case when _lang=2 then 'закрыта' else 'closed' end)
			, 10 , 6, '', -6194326, _unid, 3, 3
			, 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 14.08 16">
<path d="M12.8,16H1.28A1.28,1.28,0,0,1,0,14.72V7A1.28,1.28,0,0,1,1.28,5.76H2.56V4.48A4.49,4.49,0,0,1,7,0a.59.59,0,0,1,.23.05,4.46,4.46,0,0,1,4.25,4.43V5.76H12.8A1.28,1.28,0,0,1,14.08,7v7.68A1.28,1.28,0,0,1,12.8,16ZM7,9a2,2,0,1,0,2,2A2,2,0,0,0,7,9ZM7,1.28a3.2,3.2,0,0,0-3.2,3.2h0V5.76h6.4V4.48A3.2,3.2,0,0,0,7,1.28Z" fill="#a17b6a"/>
</svg>');

	_rule = "newID"();
	INSERT INTO status_rules(uid, order_no, unid, flags, result_status)
		VALUES (_rule, 1, _unid, 0, _ready);
		
		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 1, 0, 4, 3, _done);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 2, 0, 2, 5, _pause);

	_rule = "newID"();
	INSERT INTO status_rules(uid, order_no, unid, flags, result_status)
		VALUES (_rule, 2, _unid, 0, _pause);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 1, 0, 4, 4, _done);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 2, 0, 2, 2, _pause);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 3, 0, 2, 1, _closed);

end

$BODY$;
