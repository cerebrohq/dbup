-- SELECT count(1) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cur_state' and column_name = 'db_version'

CREATE TABLE update_log
(
  mtm timestamp with time zone NOT NULL DEFAULT now(),
  flags integer NOT NULL DEFAULT 0,

  revision integer NOT NULL,
  script_name text NOT NULL,
  
  CONSTRAINT pk_update_log PRIMARY KEY (revision, script_name) --(mtm)
)
WITH (FILLFACTOR=100, OIDS=FALSE);

-- ALTER TABLE update_log ADD CONSTRAINT k_update_log_revision_script_name UNIQUE (revision, script_name);
CREATE INDEX ix_update_log_mtm ON update_log USING btree (mtm);

