-- FUNCTION: public."zLangUpdate"()

-- DROP FUNCTION public."zLangUpdate"();

CREATE OR REPLACE FUNCTION public."zLangUpdate"(
	)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
begin
	INSERT INTO langs (uid, name, code, flags, code2, fts_conf) 
	VALUES 
	(1,'English','eng',3,'en','english'),
	(2,'Русский','rus',1,'ru','russian'),
	(3,'简体中文','zho',3,'zh',null),
	(4,'Français','fra',3,'fr','french'),
	(5,'Deutsch','deu',0,'de','german'),	
	(6,'Español','spa',0,'es','spanish'),
	(7,'Italiana','ita',0,'it','italian'),
	(8,'Dansk','dan',0,'da','danish'),
	(9,'Nederlandse','nld',0,'nl','dutch'),
	(10,'Suomi','fin',0,'fi','finnish'),
	(11,'Magyar','hun',0,'hu','hungarian'),
	(12,'Norsk','nor',0,'no','norwegian'),
	(13,'Portuguesa','por',0,'pt','portuguese'),
	(14,'Română','ron',0,'ro','romanian'),
	(15,'Svenska','swe',0,'sv','swedish'),
	(16,'Türk dili','tur',0,'tr','turkish'),
	(17,'한국어','kor',3,'ko',null),
	(18,'日本語','jpn',3,'ja',null)
	ON CONFLICT (uid) DO UPDATE 
	  SET name = EXCLUDED.name, 
	      code = EXCLUDED.code,
	      flags = EXCLUDED.flags,
	      code2 = EXCLUDED.code2,
	      fts_conf = EXCLUDED.fts_conf;
end

$BODY$;

ALTER FUNCTION public."zLangUpdate"()
    OWNER TO sa;

select "zLangUpdate"();
