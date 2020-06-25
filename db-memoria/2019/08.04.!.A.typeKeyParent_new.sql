-- Type: tKeyParent

-- DROP TYPE public."tKeyParent";

CREATE TYPE public."tKeyParent" AS
(
	mtm timestamp with time zone,
	uid bigint,
	parentid bigint
);

ALTER TYPE public."tKeyParent"
    OWNER TO sa;
