
ALTER TABLE public.tag_enums DROP CONSTRAINT k_tag_enum_tag_sval;
ALTER TABLE public.tag_enums ADD CONSTRAINT k_tag_enum_tag_sval UNIQUE (tagid, sval, del);

