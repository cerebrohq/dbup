DROP FUNCTION public."webGenUserSID"(name, name);
DROP FUNCTION public."webStartBySID"(text);

delete from public.users_web_sids;
ALTER TABLE public.users_web_sids DROP CONSTRAINT users_web_sids_hash_key;
ALTER TABLE public.users_web_sids DROP CONSTRAINT users_web_sids_pkey;

ALTER TABLE public.users_web_sids ADD CONSTRAINT pk_users_web_sids PRIMARY KEY (sid);

ALTER TABLE public.web_sid ALTER COLUMN connid TYPE text;
ALTER TABLE public.web_sid RENAME connid TO token;
ALTER TABLE public.web_sid DROP CONSTRAINT k_web_sid_connid;
ALTER TABLE public.users_web_sids DROP COLUMN creationtime;

ALTER TABLE public.users_web_sids ADD COLUMN client_type integer NOT NULL;
COMMENT ON COLUMN public.users_web_sids.client_type IS '
0 - not specifed client_type -> DesktopClient
1 - mobile client
2 - web-client

10.. -  plugins:
';

ALTER TABLE public.users_web_sids ADD COLUMN expire_at timestamp with time zone not null;
ALTER TABLE public.users_web_sids ADD COLUMN client_ip text not null;
ALTER TABLE public.users_web_sids ADD COLUMN flags int not null default 0;
COMMENT ON COLUMN public.users_web_sids.flags IS '
0x1 - disabled
0x2 - disabled by Client IP
0x4 - disabled by Client Type
';


COMMENT ON COLUMN public.web_sid.token IS 'created with this longToken ';

CREATE INDEX ix_users_web_sids_mtm ON public.users_web_sids (mtm ASC NULLS LAST);

