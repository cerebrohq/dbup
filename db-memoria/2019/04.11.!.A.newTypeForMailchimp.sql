-- Type: tUserMailchimp
-- DROP TYPE public."tUserMailchimp";

CREATE TYPE public."tUserMailchimp" AS
(
	mtm timestamp with time zone,
	uid integer,
	email text,
	firstname text,
	lastname text,
	phone text,
	universe text,
	tariff text
);

ALTER TYPE public."tUserMailchimp"
    OWNER TO sa;
