/*

Процедура обновления таблицы категории логов
zUpdateLogsCategory

в конце она вызывается.

!!! Я не знаю на сколько она теперь актуальна. 
У нас в изначалбной базе, которую мы ставим клиентам нет этой таблицы, и она получается пустая. 
Предполагалось что эта функция будет вызываться при апдейте базы через cerebro.db.update.
С этой функцие таже проблема, что и с zUpdateMessages. Она не запустится на s2 

*/



-- FUNCTION: public."zUpdateLogsCategory"()

-- DROP FUNCTION public."zUpdateLogsCategory"();

CREATE OR REPLACE FUNCTION public."zUpdateLogsCategory"()
RETURNS void
    LANGUAGE 'plpgsql'
    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

begin
	INSERT INTO logs_category(uid,skey,"desc",flags,oposite_category,oposite_group_interval,similar_group_interval,api_level)
		VALUES
			(0,'UniNew','new promo universe was created',0,null,null,null,0),
			(1,'UsrNew','user was created/added',0,null,null,null,0),
			(2,'UsrDel','user was removed/killed',0,null,null,null,0),
			(3,'UsrPsw','user change password',0,null,null,null,0),
			(4,'LogAs','user loginas',0,null,null,null,0),
			(100,'PrjNew','project was created/restored',0,null,null,null,0),
			(101,'PrjDel','project was archived',0,null,null,null,0),
			(200,'UsrPerm','perm grant to user -> OBSOLETE -> TaskPerm',0,null,null,null,0),
			(201,'GrpPerm','perm grant to group -> OBSOLETE -> TaskPerm',0,null,null,null,0),
			(300,'UsrGrpAdd','user was added to group',0,301,'00:01:00',null,0),
			(301,'UsrGrpDel','user was removed to group',0,300,'00:01:00',null,0),
			(400,'UsrVisGrpAdd','user got visibility of group',0,401,'00:01:00',null,0),
			(401,'UsrVisGrpDel','user forgot visibility of group',0,400,'00:01:00',null,0),
			(402,'UsrVisAllAdd','user got visibility of all universe users',0,403,'00:01:00',null,0),
			(403,'UsrVisAllDel','user forgot visibility of all universe users',0,402,'00:01:00',null,0),
			(500,'GrpNew','group was created',0,null,null,null,0),
			(501,'GrpDel','group was deleted',0,null,null,null,0),
			(1000,'Nt','{"ru":"Новая задача", "en":"New task"}',263,null,null,null,0),
			(1001,'Dt','удаление задачи',0,null,null,null,1),
			(1002,'Mt','изменение родительской задачи',0,null,null,null,1),
			(1003,'Bm','task bookmark',1,null,null,'01:00:00',0),
			(1010,'St','{"ru":"Статус изменен", "en":"Status changed"}',132359,null,null,'00:03:00',0),
			(1100,'Prg','{"ru":"Прогресс", "en":"Progress"
				, "dec": {"ru":"Регресс", "en":"Regress"}
				}',261,null,null,'00:01:00',1),
			(1101,'Pri','{"ru":"Приоритет изменен", "en":"Priority changed"
				, "inc": {"ru":"Приоритет повышен", "en":"Priority increased"}
				, "dec": {"ru":"Приоритет понижен", "en":"Priority decreased"}
				}',263,null,null,'00:01:00',1),
			(1102,'Actvt','Change Task activity',0,null,null,'00:01:00',1),
			(1103,'Attr','Атрибуты (теги) таска',0,null,null,'00:01:00',1),
			(1105,'TskPerm','change task perms',0,null,null,'00:01:00',1),
			(1110,'ArcSet','задача установка "Архив"',0,1111,'00:01:00',null,1),
			(1111,'ArcRst','задача снятие "Архив"',0,1110,'00:01:00',null,1),
			(1200,'Beg','{"ru":"Дата старта изменена", "en":"Date of task start changed"
				, "inc": {"ru":"Дата старта приближена", "en":"Task starts sooner"}
				, "dec": {"ru":"Дата старта отдалена", "en":"Task starts later"}
				}',261,null,null,'00:01:00',1),
			(1210,'In','{"ru":"Пора начинать", "en":"Task start coming"}',263,null,null,null,0),
			(1220,'End','{"ru":"Дедлайн изменен", "en":"Deadline of task changed"
				, "inc": {"ru":"Дедлайн отдален", "en":"Deadline moved later"}
				, "dec": {"ru":"Дедлайн приближен", "en":"Deadline moved closer"}
				}',261,null,null,'00:01:00',1),
			(1230,'Ix','{"ru":"Дедлайн по задаче", "en":"Task deadline"}',263,null,null,null,0),
			(1301,'Pln','{"ru":"Запланированные часы изменены", "en":"Planned hours changed"
				, "inc": {"ru":"Запланированные часы увеличены", "en":"Planned hours increased"}
				, "dec": {"ru":"Запланированные часы уменьшены", "en":"Planned hours decreased"}
				}',261,null,null,'00:01:00',1),
			(1302,'Dclr','Изменение заявленных. часов',0,null,null,'00:01:00',1),
			(1303,'Apr','{"ru":"Часы подтверждены", "en":"Hours confirmed"
				, "dec": {"ru":"Часы подтверждены частично", "en":"Hours confirmed partially"}
				}',261,null,null,'00:01:00',1),
			(1401,'Bgt','{"ru":"Бюджет изменен", "en":"Budget changed"
				, "inc": {"ru":"Бюджет увеличен", "en":"Budget increased"}
				, "dec": {"ru":"Бюджет уменьшены", "en":"Budget decreased"}
				}',261,null,null,'00:01:00',1),
			(1410,'InvsN','{"ru":"Новый платеж", "en":"New invoice"}',261,null,null,null,1),
			(1411,'InvsC','{"ru":"Отмена платежа", "en":"Invoice cancelled"}',261,null,null,null,1),
			(1500,'As','{"ru":"Добавлен исполнитель", "en":"Allocated to task"
				, "me": {"ru":"Вы назначены на задачу", "en":"You are allocated to task"}
				}',1287,1501,'00:01:00',null,0),
			(1501,'Aw','{"ru":"Исполнитель удален", "en":"Revoked from task"
				, "me": {"ru":"Вы сняты с задачи", "en":"You are revoked from task"}
				}',263,1500,'00:01:00',null,0),
			(1510,'AsS','assigned subscriber',0,1511,'00:01:00',null,1),
			(1511,'AwS','withdrawn subscriber',0,1510,'00:01:00',null,1),
			(2000,'Nm','{"ru" : "Коментарий", "en": "Comment"
					, "0" : { "ru" : "Постановка задания"   , "en": "Definition" }
					, "1" : { "ru" : "Коментарий к задаче"  , "en": "Review" }
					, "2" : { "ru" : "Отчет"                , "en": "Report"  }
					, "3" : { "ru" : "Коментарий"           , "en": "Comment" }
					, "4" : { "ru" : "Коментарий клиента"   , "en": "Client review" }
					, "5" : { "ru" : "Отчет по ресурсу"     , "en": "Resource report" }
				}',1287,null,null,null,0),
			(2001,'Dm','del message',0,null,null,'00:03:00',1),
			(2110,'CliShow','{"ru":"Отметкa установена", "en":"Mark set"
				, "msg": {"ru":"Показывать клиенту", "en":"Show to client"}
				}',1285,2111,'00:01:00',null,1),
			(2111,'CliHide','снятие отметки "показывать клиенту"',0,2110,'00:01:00',null,1),
			(3000,'AttNew','добавление атач',0,null,null,null,1),
			(3001,'AttDel','удаление атача',0,null,null,null,1),
			(3110,'Fin','{"ru":"Отметкa установена", "en":"Mark set"
				 , "msg": {"ru":"Финальная версия", "en":"Final version"}
				 }',1285,3111,'00:01:00',null,1),
			(3111,'FinRst','снятие отметки "финальная версия"',0,3110,'00:01:00',null,1)		
		
		ON CONFLICT (uid)
		DO UPDATE SET
			skey = EXCLUDED.skey,
			"desc" = EXCLUDED."desc",
			flags = EXCLUDED.flags,			
			oposite_category = EXCLUDED.oposite_category,
			oposite_group_interval = EXCLUDED.oposite_group_interval,
			similar_group_interval = EXCLUDED.similar_group_interval,
			api_level = EXCLUDED.api_level;

end

$BODY$;

ALTER FUNCTION public."zUpdateLogsCategory"()
    OWNER TO sa;


select "zUpdateLogsCategory"();
