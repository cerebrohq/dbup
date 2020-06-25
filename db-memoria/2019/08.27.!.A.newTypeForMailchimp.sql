
CREATE TYPE public."tUserMailchimp_01" AS
(
	mtm timestamp with time zone,
	uid integer,
	email text,
	firstname text,
	lastname text,
	phone text,
	universe text,
	tariff text,
	langid integer
);

ALTER TYPE public."tUserMailchimp_01"
    OWNER TO sa;
