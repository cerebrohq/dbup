/*

Добвлены комментаририи к колонке key в таблицах
attrib_user
attrib_universe
attrib_project
*/


COMMENT ON COLUMN public.attrib_user.key
    IS '
100-102 - notifications
200 - push device IDs, space separated
300 - search history JSON array
301 - navigation history JSON array
500 - search pages XML data
501 - user pages XML data
';


COMMENT ON COLUMN public.attrib_universe.key
    IS '
100-102 - notifications
500 - company pages XML data
';

COMMENT ON COLUMN public.attrib_project.key
    IS '
100-102 - notifications
';
