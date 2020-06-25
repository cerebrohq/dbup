/*

1. Реализация связи статуса с видами деятельности задачи, на которых данный статус можно поставить.
Если для статуса не определён ни один вид деятельности, считается, что статус возможен на задачах с любым видом деятельности

2. Реализован функционал для расширения возможных форматов иконок статуса, без преобразования в XPM (там проблемы с прозрачностью)
Для этого добавлено поле icon_hash, где будет хранится хеш иконки статуса. 
Сама иконка будет отправлять в наше хранилище storage.cerebrohq.com, по тому же принципу что и аватарки пользователей
Поддерживаемые форматы:
PNG
JPEG
SVG - для поддержки экранов разного разрешения (dpi). (В мобильной версии их нужно будет преобразовывать в поддерживаемый формат в зависимости от разрешения экрана, я тогда опишу в ТЗ)


Добавлены:

таблица:
status_activities

Новое поле таблицы status для хранения хеша иконки статуса
icon_hash

*/


ALTER TABLE status ADD COLUMN icon_hash text;


-- Table: status_activities

-- DROP TABLE status_activities;

CREATE TABLE status_activities
(
  mtm timestamp with time zone NOT NULL DEFAULT now(),
  muid integer NOT NULL DEFAULT "getUserID_bySession"(),
  flags integer NOT NULL DEFAULT 0,
  statusid bigint NOT NULL,
  activityid bigint NOT NULL,
  CONSTRAINT ix_status_activities PRIMARY KEY (statusid, activityid),
  CONSTRAINT fk_status_activities_activitytypes FOREIGN KEY (activityid)
      REFERENCES activitytypes (uid) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT fk_status_activities_status FOREIGN KEY (statusid)
      REFERENCES status (uid) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT fk_status_activities_users FOREIGN KEY (muid)
      REFERENCES users (uid) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
ALTER TABLE status_activities
  OWNER TO sa;
GRANT ALL ON TABLE status_activities TO sa;
GRANT SELECT ON TABLE status_activities TO system_readers;

-- Index: ix_status_activities_activity

-- DROP INDEX ix_status_activities_activity;

CREATE INDEX ix_status_activities_activity
  ON status_activities
  USING btree
  (activityid);

-- Index: ix_status_activities_muid

-- DROP INDEX ix_status_activities_muid;

CREATE INDEX ix_status_activities_muid
  ON status_activities
  USING btree
  (muid);

-- Index: ix_status_activities_user

-- DROP INDEX ix_status_activities_user;

CREATE INDEX ix_status_activities_user
  ON status_activities
  USING btree
  (statusid);


-- Trigger: status_activities_PrimeTest on status_activities

-- DROP TRIGGER "status_activities_PrimeTest" ON status_activities;

CREATE TRIGGER "status_activities_PrimeTest"
  BEFORE INSERT OR UPDATE OR DELETE
  ON status_activities
  FOR EACH STATEMENT
  EXECUTE PROCEDURE "testPrimaryServer"();

