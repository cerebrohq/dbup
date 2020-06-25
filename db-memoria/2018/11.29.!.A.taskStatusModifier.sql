/*

Реализованы процедуры:
Для получения пользователя и даты переключения статуса. Данные берутся из таблицы logs
Для получения задач в определенном статусе

Новый тип для данных по изменению статуса: кто, когда, какой статус
tTaskStatusModified

*/


CREATE TYPE "tTaskStatusModified" AS
   (uid bigint,
    mtm timestamp with time zone,    
    userid integer,
    statusid bigint);
ALTER TYPE "tTaskStatusModified"
  OWNER TO sa;


