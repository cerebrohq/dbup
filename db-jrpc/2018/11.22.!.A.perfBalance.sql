CREATE TABLE public.perf_log
(
  mtm timestamp with time zone NOT NULL DEFAULT now(),
  sid bigint NOT NULL,

  duration double precision NOT NULL,
  sql text NOT NULL,
  
  CONSTRAINT pk_perf_log PRIMARY KEY (sid, mtm)
)
WITH (FILLFACTOR=100, OIDS=FALSE);

ALTER TABLE public.perf_log ADD COLUMN delay integer default 0;
CREATE INDEX ix_perf_log_mtm ON public.perf_log USING btree(mtm ASC NULLS LAST) TABLESPACE pg_default;
