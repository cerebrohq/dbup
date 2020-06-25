
CREATE OR REPLACE FUNCTION "zzRemovePostgresRoles"() RETURNS void
    LANGUAGE plpgsql STRICT
    AS $$
declare
	del_role text;
begin
	for del_role in
	(
		select rolname
			from pg_roles
				where
					not rolname in (
					'sa', 'sa_sirena', 'sa_cabinet', 'sa_stat', 'sa_passrecover', 'sa_web', 'sa_replicant', 'sa_mail_replier', 'sa_notifier'
					, 'sa_estadistica', 'sa_reader_estadistica', 'sa_writer_estadistica'
					, 'backupus', 'develop', 'mamots', 'shepherds', 'system_readers', 'writer_estadistica', 'reader_estadistica'
					, 'postgres', 'pg_read_all_settings', 'pg_read_all_stats', 'pg_stat_scan_tables', 'pg_signal_backend', 'pg_monitor'
					, 'pootle', 'roundcube', 'codestriker'
				)
	)
	loop
		EXECUTE 'DROP ROLE "' || del_role || '"';
		-- EXECUTE 'ALTER ROLE "' || del_role || '" RENAME TO "' || ('-' || del_role) || '"';
	end loop;
end
$$;

-- ALTER TABLE users ADD COLUMN rolpassword text;
-- UPDATE users set rolpassword = (select rolpassword from pg_authid where rolname = users.lid);
select "zzRemovePostgresRoles"();
