

-- FUNCTION: public."zActivityUniverseInit"(integer)

-- DROP FUNCTION public."zActivityUniverseInit"(integer);

CREATE OR REPLACE FUNCTION public."zActivityUniverseInit"(
	_unid integer)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	nid bigint;
begin
	if exists (select 1 from activitytypes where unid=_unid)
	then
		raise notice 'skip init activities for %', _unid;
		return;
	end if;

	nid = "newID"();
	insert into activitytypes(uid, "name", cp_default_weight, del, unid, color)
		values (nid, 'texturing', 1, 0, _unid, -6197570);
			
	nid = "newID"();
	insert into activitytypes(uid, "name", cp_default_weight, del, unid, color)
		values (nid, 'modeling', 1, 0, _unid, -11430916);

	nid = "newID"();
	insert into activitytypes(uid, "name", cp_default_weight, del, unid, color)
		values (nid, 'layout', 1, 0, _unid, -4887920);

	nid = "newID"();
	insert into activitytypes(uid, "name", cp_default_weight, del, unid, color)
		values (nid, 'animation', 1, 0, _unid, -9652134);

	nid = "newID"();
	insert into activitytypes(uid, "name", cp_default_weight, del, unid, color)
		values (nid, 'compositing', 1, 0, _unid, -5282980);

end

$BODY$;

ALTER FUNCTION public."zActivityUniverseInit"(integer)
    OWNER TO sa;

-- FUNCTION: public."statusUniverseInit"(integer)

-- DROP FUNCTION public."statusUniverseInit"(integer);

CREATE OR REPLACE FUNCTION public."statusUniverseInit"(
	_unid integer)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 1000
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	_pause bigint = "newID"();
	_ready bigint = "newID"();
	_refac bigint = "newID"();
	_working bigint = "newID"();
	_wait_confirm bigint = "newID"();
	_done bigint = "newID"();
	_closed bigint = "newID"();
	_rule bigint = "newID"();
	_lang int = (select lang from universes where uid=_unid);
begin
	if exists (select 1 from status where unid=_unid)
	then
		raise notice 'skip for %', _unid;
		return;
	end if;

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_pause, (case when _lang=2 then 'на паузе' else 'paused' end)
			, 2, 0, '', -5927847, _unid, 3, 3
			, 'DC521E66D8C5460CDB153B6C4EAC2165345C7825B64374DC4DB46972B9B15063'
			, '/* XPM */
				static char *dummy[]={
				"16 16 95 2",
				"Qt c None",
				".d c #000000",
				"#l c #0d0d0d",
				".E c #111111",
				".# c #141414",
				"#v c #262626",
				"#o c #272727",
				".s c #333333",
				".e c #383838",
				"#A c #2a2a2a",
				"#g c #2e2e2e",
				".Q c #363636",
				".a c #424242",
				"#c c #404040",
				".X c #474747",
				"#B c #3a3a3a",
				".b c #5c5c5c",
				"#s c #3d3d3d",
				".j c #565656",
				"#C c #494949",
				"#. c #545454",
				".5 c #575757",
				".c c #737373",
				"#w c #505050",
				"#m c #525252",
				".F c #686868",
				".f c #767676",
				"#a c #000000",
				"#e c #1b1b1b",
				".8 c #222222",
				"#k c #363636",
				".2 c #404040",
				".6 c #4b4b4b",
				"## c #4d4d4d",
				"#t c #4f4f4f",
				"#p c #505050",
				"#d c #525252",
				"#h c #545454",
				"#x c #5d5d5d",
				"#j c #5e5e5e",
				"#z c #5f5f5f",
				".7 c #606060",
				".R c #616161",
				"#f c #646464",
				".Y c #666666",
				"#n c #676767",
				".4 c #686868",
				"#u c #696969",
				".t c #6b6b6b",
				".1 c #6c6c6c",
				".k c #6f6f6f",
				".g c #727272",
				".G c #737373",
				".P c #747474",
				".h c #757575",
				"#y c #767676",
				".r c #777777",
				".l c #787878",
				".9 c #7c7c7c",
				"#b c #7d7d7d",
				".i c #7f7f7f",
				".V c #858585",
				"#q c #868686",
				".D c #8d8d8d",
				".u c #8e8e8e",
				".0 c #929292",
				".U c #989898",
				"#r c #9a9a9a",
				"#i c #b8b8b8",
				".m c #bababa",
				".S c #bebebe",
				".Z c #cecece",
				".n c #d0d0d0",
				".v c #d3d3d3",
				".q c #d4d4d4",
				".H c #d5d5d5",
				".o c #d9d9d9",
				".p c #dbdbdb",
				".C c #dddddd",
				".O c #e2e2e2",
				".w c #e8e8e8",
				".3 c #e9e9e9",
				".B c #eaeaea",
				".T c #ececec",
				".I c #ededed",
				".x c #efefef",
				".A c #f1f1f1",
				".y c #f2f2f2",
				".z c #f3f3f3",
				".J c #f6f6f6",
				".N c #fafafa",
				".K c #fbfbfb",
				".M c #fcfcfc",
				".L c #fdfdfd",
				".W c #ffffff",
				"QtQtQtQt.#.a.b.c.c.b.a.#QtQtQtQt",
				"QtQt.d.e.f.g.h.i.i.h.g.f.e.dQtQt",
				"Qt.d.j.k.l.m.n.o.p.q.m.r.k.j.dQt",
				"Qt.s.t.u.v.w.x.y.z.A.B.C.D.t.sQt",
				".E.F.G.H.I.J.K.L.L.M.N.A.O.P.F.E",
				".Q.R.S.T.J.U.V.W.W.r.R.M.A.n.R.Q",
				".X.Y.Z.A.M.0.1.W.W.k.2.W.N.3.4.X",
				".5.P.n.x.M.r.6.W.W.7.8.W.M.x.9.5",
				"#..G.H.A.L###a.W.W###a.W.L.A#b#.",
				"#c.7.n.x.M#d#e.W.W#d#e.W.M.x#f#c",
				"#g#h#i.3.N#j#k.W.W#j#k.W.N.p#h#g",
				"#l#m#n.C.A.M.W.W.W.W.W.M.A.G#m#l",
				"Qt#o#p#q.O.A.N.M.L.M.N.A#r#p#oQt",
				"Qt.d#s#t#u.n.3.x.A.x.p.G#t#s.dQt",
				"QtQt.d#v#w#t#x#y.l#z#t#w#v.dQtQt",
				"QtQtQtQt#l#A#B#C#C#B#A#lQtQtQtQt"};
				');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_ready, (case when _lang=2 then 'готова к работе' else 'ready to start' end)
			, 0 ,1 ,'', -8996650, _unid, 39, 3
			, '10DCFA2085F30B8EF98A6A9F5104BC6355586953F942289DF83AA2A35600CCD5'
			, '/* XPM */
				static char *dummy[]={
				"16 16 116 2",
				"Qt c None",
				"#M c #000000",
				".q c #000101",
				"#V c #000102",
				".e c #020509",
				"#F c #02050a",
				".D c #040911",
				"#R c #03070e",
				".j c #081324",
				"#u c #081426",
				"#X c #020811",
				".Q c #0b1b32",
				".a c #0d1f3a",
				"#L c #081527",
				".p c #122a4e",
				".# c #122a4f",
				"#g c #132d54",
				".3 c #143059",
				"#U c #051121",
				"#W c #041123",
				".d c #173562",
				"#E c #0f2649",
				".C c #1b4079",
				"#Q c #091b36",
				".i c #1d4784",
				"#t c #183a6d",
				".P c #235194",
				"#v c #081d3c",
				".r c #133363",
				"#K c #132d54",
				".o c #28579e",
				"#f c #28518c",
				".2 c #2c5a9b",
				"#A c #061020",
				"#G c #071428",
				"#z c #071529",
				"#N c #07172e",
				"#S c #071832",
				"#T c #071a34",
				"#y c #081a35",
				"#x c #0a2041",
				"#w c #0a2245",
				"#h c #0a2348",
				".w c #0c1e3a",
				".4 c #0d2850",
				".v c #0e2444",
				".R c #0f2d58",
				".u c #112c54",
				".k c #122b52",
				".E c #123160",
				".t c #153667",
				".s c #16396e",
				".f c #183a6c",
				".b c #1f4a8a",
				"#D c #204070",
				".c c #204d90",
				"#s c #274a7e",
				"#P c #314a6e",
				".5 c #37598c",
				"#i c #3a5d91",
				".B c #3c6aaa",
				"#r c #44689d",
				"#J c #476795",
				".h c #476fa1",
				".6 c #4c71a6",
				"#C c #4e72a7",
				"#j c #5379af",
				"#q c #5479af",
				"#e c #55759d",
				".O c #567eb1",
				".S c #5a7aa2",
				"#p c #5f85bb",
				"#k c #6489bf",
				".1 c #6688af",
				".7 c #678cbd",
				"#o c #688dc2",
				"#d c #6c8baf",
				"#l c #6c91c7",
				"#n c #6d92c7",
				".n c #6f94bc",
				"#m c #6f94c9",
				"#I c #7499cd",
				"#B c #779bd0",
				"#c c #7a9abd",
				"#O c #7a9bcc",
				".8 c #7a9dca",
				".0 c #809fbd",
				"#H c #80a3d7",
				".T c #82a2c4",
				"#b c #82a3c7",
				".9 c #85a7d0",
				".Z c #86a6c5",
				"#a c #88a9ce",
				"#. c #8aacd2",
				".F c #8ba9c4",
				".Y c #8babcb",
				"## c #8badd1",
				".A c #8cadce",
				".U c #8eaecf",
				".N c #8fafcb",
				".X c #8fb0d0",
				".G c #91b0cc",
				".V c #92b3d4",
				".W c #94b5d5",
				".M c #95b4d0",
				".H c #96b5d2",
				".g c #96b7d3",
				".L c #98b7d4",
				".I c #99b8d5",
				".K c #9ab9d6",
				".J c #9abad7",
				".z c #a2c1da",
				".y c #a3c2db",
				".x c #a3c3dc",
				".m c #adcde3",
				".l c #aecde3",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQt.#.aQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQt.b.c.d.eQtQtQtQtQtQtQt",
				"QtQtQtQtQt.f.g.h.i.jQtQtQtQtQtQt",
				"QtQtQtQtQt.k.l.m.n.o.p.qQtQtQtQt",
				".r.s.t.u.v.w.x.y.z.A.B.C.DQtQtQt",
				".E.F.G.H.I.J.J.K.L.M.N.O.P.QQtQt",
				".R.S.T.U.V.W.W.V.X.Y.Z.0.1.2.3Qt",
				".4.5.6.7.8.9#.###a#b#c#d#e#f#gQt",
				"#h#i#j#k#l#m#n#o#p#q#r#s#t#uQtQt",
				"#v#w#x#y#z#A#B#m#k#C#D#E#FQtQtQt",
				"QtQtQtQtQt#G#H#I#J#K#L#MQtQtQtQt",
				"QtQtQtQtQt#N#O#P#Q#RQtQtQtQtQtQt",
				"QtQtQtQtQt#S#T#U#VQtQtQtQtQtQtQt",
				"QtQtQtQtQt#W#XQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt"};
			');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_refac, (case when _lang=2 then 'на переработку' else 'could be better' end)
			, 0, 2, '', -4494477, _unid, 39, 3
			, '3F30ACDF3E302C02C4610B500A25084F4EE22E9D1858481A9623CC63ABDFD54C'
			, '/* XPM */
				static char *dummy[]={
				"16 16 115 2",
				"Qt c None",
				"#L c #000000",
				".q c #020100",
				"#U c #030200",
				".e c #0b0900",
				"#E c #0c0a00",
				".D c #151200",
				"#Q c #110e00",
				".j c #2c2500",
				"#t c #2e2700",
				"#W c #131000",
				".Q c #3d3400",
				".a c #473c00",
				"#K c #2f2700",
				".p c #5f5100",
				".# c #615200",
				"#g c #665600",
				".3 c #6d5d00",
				"#T c #272100",
				"#V c #272100",
				".d c #796600",
				"#D c #584a00",
				".C c #947e00",
				"#P c #3f3600",
				".i c #a18700",
				"#s c #857100",
				".P c #b69901",
				"#u c #443800",
				".r c #766400",
				"#J c #675900",
				".o c #c1a505",
				"#f c #aa9009",
				".2 c #bc9f0a",
				"#z c #262100",
				"#F c #2f2800",
				"#y c #302800",
				"#M c #352c00",
				"#R c #393100",
				"#S c #3b3100",
				"#x c #3d3400",
				".w c #463c00",
				"#w c #4b4000",
				"#v c #4f4200",
				".v c #524500",
				".4 c #5d4e00",
				".k c #645600",
				".u c #655500",
				".R c #675600",
				".E c #726100",
				".t c #7c6900",
				"#O c #80701e",
				".f c #846f00",
				".s c #847000",
				"#C c #887408",
				"#r c #98820d",
				".5 c #a5901d",
				".b c #a98f00",
				"#h c #ab9520",
				"#I c #ac972f",
				".c c #b09500",
				"#e c #b29c3f",
				".S c #b7a144",
				"#q c #b8a229",
				".h c #bca02c",
				".6 c #c1a931",
				"#B c #c2ac33",
				"#d c #c3ac58",
				".1 c #c5ab50",
				"#i c #cab237",
				"#p c #cab338",
				".B c #cbad1b",
				".O c #ccb03a",
				".0 c #cfb56d",
				"#c c #d1b866",
				".n c #d3b658",
				".F c #d5bc7a",
				"#o c #d6be43",
				".7 c #d7be4d",
				".Z c #d8be73",
				".T c #d8bf6e",
				"#j c #dac348",
				"#b c #dcc26d",
				".N c #ddc27d",
				".G c #ddc37f",
				"#n c #ddc54d",
				".Y c #dec478",
				".M c #e1c783",
				".A c #e2c778",
				".U c #e2c87a",
				".8 c #e2c962",
				"#m c #e2ca52",
				"#k c #e2cb50",
				".X c #e3c87b",
				"#a c #e3ca73",
				".H c #e4ca84",
				"#l c #e4cc54",
				"#N c #e4d061",
				".g c #e5c883",
				"## c #e6cb76",
				".L c #e6cc86",
				".9 c #e6cd6e",
				"#. c #e7cd74",
				".I c #e7cd87",
				".V c #e8cd7e",
				".W c #e8cd80",
				".K c #e8ce88",
				"#H c #e8d059",
				".J c #e9ce87",
				".z c #ebd091",
				"#A c #ebd55c",
				".y c #ecd192",
				".x c #edd192",
				"#G c #f1db66",
				".m c #f3d59d",
				".l c #f3d69e",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQt.#.aQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQt.b.c.d.eQtQtQtQtQtQtQt",
				"QtQtQtQtQt.f.g.h.i.jQtQtQtQtQtQt",
				"QtQtQtQtQt.k.l.m.n.o.p.qQtQtQtQt",
				".r.s.t.u.v.w.x.y.z.A.B.C.DQtQtQt",
				".E.F.G.H.I.J.J.K.L.M.N.O.P.QQtQt",
				".R.S.T.U.V.W.W.V.X.Y.Z.0.1.2.3Qt",
				".4.5.6.7.8.9#.###a#b#c#d#e#f#gQt",
				".v#h#i#j#k#l#m#n#o#p#q#r#s#tQtQt",
				"#u#v#w#x#y#z#A#l#j#B#C#D#EQtQtQt",
				"QtQtQtQtQt#F#G#H#I#J#K#LQtQtQtQt",
				"QtQtQtQtQt#M#N#O#P#QQtQtQtQtQtQt",
				"QtQtQtQtQt#R#S#T#UQtQtQtQtQtQtQt",
				"QtQtQtQtQt#V#WQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt"};
			'
		);
		
	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_working, (case when _lang=2 then 'в работе' else 'in progress' end)
			, 4, 3, '', -6975521, _unid, 7, 36
			, '6CB08471861638C597F3E88EB0318E37EE751791B5F2C642A1353D47D2942456'
			, '/* XPM */
				static char *dummy[]={
				"16 16 147 2",
				"Qt c None",
				"aj c #000000",
				".A c #080808",
				".d c #090909",
				".g c #0c0c0c",
				"ab c #090909",
				"#8 c #0a0a0a",
				"an c #080808",
				"ai c #090909",
				".c c #232323",
				".Y c #242424",
				".# c #252525",
				"#L c #1d1d1d",
				"#z c #1e1e1e",
				"aq c #1f1f1f",
				"ao c #1f1f1f",
				".q c #353535",
				".h c #2e2e2e",
				"ah c #2e2e2e",
				"ac c #2f2f2f",
				".e c #515151",
				"#a c #5a5a5a",
				".Z c #5b5b5b",
				"am c #4e4e4e",
				"ak c #4e4e4e",
				"#A c #4f4f4f",
				"#K c #4f4f4f",
				".X c #5c5c5c",
				".k c #6e6e6e",
				".n c #707070",
				".M c #636363",
				"#M c #5e5e5e",
				"af c #646464",
				".B c #6b6b6b",
				".j c #6d6d6d",
				".a c #808080",
				".b c #818181",
				"#o c #5f5f5f",
				"#7 c #626262",
				"#X c #636363",
				"#n c #646464",
				"#b c #666666",
				".L c #676767",
				".o c #808080",
				"ae c #696969",
				"ag c #696969",
				"ap c #727272",
				".l c #d1d1d1",
				"## c #b8b8b8",
				".0 c #b9b9b9",
				"#B c #aeaeae",
				".z c #cbcbcb",
				".p c #dedede",
				".r c #cbcbcb",
				".i c #d8d8d8",
				"#9 c #b9b9b9",
				"ad c #bdbdbd",
				"#r c #1a3661",
				"#x c #1b3762",
				"#P c #213d67",
				"#U c #233f6a",
				"#D c #244475",
				"#I c #244576",
				"#2 c #27436f",
				"#3 c #27446f",
				"#s c #30507f",
				"#w c #315180",
				"#T c #385a8d",
				"#Q c #385b8e",
				"#k c #3c5478",
				"#C c #526685",
				"#J c #536785",
				"#1 c #566a88",
				"#H c #577cb2",
				"#4 c #596d8b",
				"#j c #5f7596",
				"#d c #647794",
				".8 c #677b98",
				"#S c #688dc1",
				"#R c #6c90c4",
				"#e c #7084a3",
				".7 c #788aa5",
				".9 c #79889e",
				".U c #8291a8",
				".3 c #8a99b0",
				".T c #919eb3",
				".2 c #98a3b4",
				".S c #99a6ba",
				"#G c #9cb6dd",
				"#E c #9db2cf",
				".R c #9eaabc",
				".P c #a1acbd",
				".6 c #a3acb9",
				".Q c #a5b0c1",
				".H c #a8b1bf",
				".G c #a8b2c2",
				".F c #aeb8c6",
				"#0 c #b4b8be",
				"#O c #b5b9bf",
				".E c #b6bec9",
				"#V c #babec4",
				"#Y c #bfbfbf",
				"#Z c #c2c2c2",
				".4 c #c2c8d0",
				"#p c #c5c5c5",
				".V c #c5c8cd",
				"#N c #c6c6c6",
				"#W c #c7c7c7",
				"#v c #c7d0de",
				"a. c #c9c9c9",
				"#6 c #cacaca",
				"#. c #cbcbcb",
				"#5 c #cbcfd5",
				"a# c #cdcdcd",
				"#t c #cdd6e4",
				".W c #d0d0d0",
				".O c #d0d2d6",
				".I c #d0d3d7",
				"#m c #d1d1d1",
				"#l c #d2d2d2",
				"#q c #d3d3d3",
				"#y c #d4d4d4",
				"#F c #d4deec",
				"al c #d5d5d5",
				"#c c #d7d7d7",
				"#f c #d8dee7",
				"aa c #d9d9d9",
				".5 c #d9dadb",
				"#i c #d9dadd",
				".1 c #dadada",
				".K c #dcdcdc",
				".N c #dedede",
				".D c #e0e3e6",
				"#u c #e1e1e1",
				"#h c #e4e4e4",
				".C c #e5e5e5",
				".J c #e6e6e6",
				".y c #e7e7e7",
				".w c #ebebeb",
				"#g c #ececec",
				".v c #ededed",
				".x c #eeeeee",
				".s c #f1f1f1",
				".m c #f4f4f4",
				".u c #f5f5f5",
				".t c #f6f6f6",
				".f c #f8f8f8",
				"QtQtQtQtQtQt.#.a.b.cQtQtQtQtQtQt",
				"QtQtQt.dQtQt.e.f.f.eQtQt.gQtQtQt",
				"QtQt.h.i.j.k.l.m.m.l.n.o.p.qQtQt",
				"Qt.d.r.s.t.t.u.v.w.x.v.w.y.z.AQt",
				"QtQt.B.C.t.D.E.F.G.H.I.J.K.LQtQt",
				"QtQt.M.N.O.P.Q.R.S.T.U.V.W.XQtQt",
				".Y.Z.0.1.2.3.4.5.6.7.8.9#.###a.Y",
				"#b#..W#c#d#e#f#g#h#i#j#k#l#m#.#n",
				"#o#p#.#q#r#s#t#g#u#v#w#x#y#.#p#o",
				"#z#A#B#.#C#D#E#F#G#H#I#J#.#B#K#L",
				"QtQt#M#N#O#P#Q#R#S#T#U#V#W#MQtQt",
				"QtQt#X#Y#Z#0#1#2#3#4#5#u#6#7QtQt",
				"Qt#8#9a.a##m#q#caaaa.1aa#l#9abQt",
				"QtQtacadaeaf.0#y#y.0afagadahQtQt",
				"QtQtQtaiajQtakalalamQtajanQtQtQt",
				"QtQtQtQtQtQtaoapapaqQtQtQtQtQtQt"};
			'
		);

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
		_wait_confirm, (case when _lang=2 then 'на утверждение' else 'pending review' end) 
		, 0, 4, '', -3358100, _unid, 3, 36
		, '84523D49556B71A52D5ECC9E876A0237DFCE03B62C46014697E56272DFF68809'
		, '/* XPM */
			static char *dummy[]={
			"16 16 116 2",
			"Qt c None",
			"#G c #000000",
			".k c #020000",
			"#S c #030100",
			".b c #0b0200",
			"#v c #0c0200",
			".r c #150400",
			"#N c #110300",
			".f c #2b0800",
			"#h c #2e0800",
			"#W c #130300",
			".E c #3d0b00",
			".# c #470d00",
			"#H c #2f0800",
			".l c #5f1200",
			".a c #601200",
			".4 c #661200",
			".R c #6d1400",
			"#T c #270700",
			"#X c #270600",
			".c c #781701",
			"#w c #581000",
			".s c #931c01",
			"#O c #3f0c00",
			".g c #a01d00",
			"#i c #851900",
			".F c #b52203",
			"#F c #440b00",
			".D c #761600",
			"#I c #661401",
			".m c #bf2907",
			".5 c #a9270b",
			".S c #bb2a0c",
			"#A c #260800",
			"#M c #2f0900",
			"#B c #300800",
			"#R c #350900",
			"#V c #390b00",
			"#U c #3b0900",
			"#C c #3d0b00",
			".y c #460d00",
			"#D c #4b0e00",
			"#E c #4f0e00",
			".z c #520e00",
			"#u c #520f00",
			"#g c #5d1100",
			".q c #641300",
			".A c #651200",
			".3 c #671200",
			".Q c #721500",
			".B c #7c1600",
			"#P c #7f2f1f",
			".j c #841800",
			".C c #841900",
			"#x c #872009",
			"#j c #97270e",
			"#f c #a4371f",
			".e c #a81f00",
			"#t c #aa3a21",
			"#J c #ab4631",
			".d c #b02000",
			".6 c #b15040",
			"#k c #b6432a",
			".2 c #b65545",
			".h c #ba412d",
			"#e c #bf4a32",
			"#y c #c04d34",
			".7 c #c26659",
			".T c #c45e51",
			".t c #c9381c",
			"#s c #c95239",
			"#l c #c9533a",
			".G c #cb513c",
			".U c #ce756e",
			".8 c #d07267",
			".n c #d26559",
			".P c #d47f7a",
			"#m c #d55e45",
			"#d c #d5634e",
			".1 c #d7796f",
			".V c #d77b74",
			"#r c #d9634a",
			".9 c #da796e",
			"#n c #db664e",
			".H c #dc837e",
			".W c #dd8179",
			".O c #dd8580",
			"#o c #e06b53",
			"#q c #e16b52",
			"#c c #e17563",
			".u c #e18279",
			".0 c #e1847b",
			".I c #e18984",
			"#p c #e26d55",
			"#. c #e28074",
			".X c #e2847c",
			"#Q c #e37962",
			".N c #e38b85",
			".i c #e48884",
			"#b c #e57e6f",
			"## c #e58277",
			".J c #e58d87",
			"#K c #e6725a",
			"#a c #e68275",
			".M c #e68e88",
			".Y c #e7887f",
			".Z c #e78981",
			".K c #e78f89",
			".L c #e88e88",
			"#z c #e9765d",
			".v c #ea9592",
			".w c #eb9693",
			".x c #ec9492",
			"#L c #f08067",
			".o c #f29d9e",
			".p c #f29f9f",
			"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
			"QtQtQtQtQtQtQtQt.#.aQtQtQtQtQtQt",
			"QtQtQtQtQtQt.b.c.d.eQtQtQtQtQtQt",
			"QtQtQtQtQt.f.g.h.i.jQtQtQtQtQtQt",
			"QtQtQt.k.l.m.n.o.p.qQtQtQtQtQtQt",
			"QtQt.r.s.t.u.v.w.x.y.z.A.B.C.DQt",
			"Qt.E.F.G.H.I.J.K.L.L.M.N.O.P.QQt",
			".R.S.T.U.V.W.X.Y.Z.Z.Y.0.1.2.3Qt",
			".4.5.6.7.8.9#.###a#b#c#d#e#f#gQt",
			"Qt#h#i#j#k#l#m#n#o#p#q#r#s#t#uQt",
			"QtQt#v#w#x#y#r#p#z#A#B#C#D#E#FQt",
			"QtQtQt#G#H#I#J#K#L#MQtQtQtQtQtQt",
			"QtQtQtQtQt#N#O#P#Q#RQtQtQtQtQtQt",
			"QtQtQtQtQtQt#S#T#U#VQtQtQtQtQtQt",
			"QtQtQtQtQtQtQtQt#W#XQtQtQtQtQtQt",
			"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt"};
		');

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_done, (case when _lang=2 then 'выполнена' else 'completed' end)
			, 10, 5, '', -10507146, _unid, 3, 3
			, '3A1347FACD94E20C6A392F1C1E7E7FEA1D219FB130F4BC4AA60023548949065E'
			, '/* XPM */
				static char *dummy[]={
				"16 16 83 2",
				"Qt c None",
				"#p c #010301",
				"#h c #020401",
				".q c #020402",
				".T c #040603",
				"#q c #020502",
				"#m c #030502",
				"#a c #030603",
				".4 c #040703",
				".x c #192c16",
				".r c #1c3119",
				".H c #1d331a",
				".s c #294824",
				".M c #254622",
				".A c #294b25",
				".d c #23451f",
				".j c #1e401b",
				".a c #294e25",
				".N c #2c5528",
				".B c #2f592a",
				".t c #2f5a2b",
				".k c #305a2b",
				".e c #305b2b",
				".# c #315c2c",
				".I c #5ba251",
				".y c #5ca453",
				"#o c #367930",
				".S c #3a7e34",
				".G c #3b7f35",
				".w c #3c8036",
				".L c #59a450",
				".3 c #3a7e34",
				"#l c #387c32",
				"#g c #397d33",
				"## c #3a7e34",
				"#n c #3d8337",
				".p c #408539",
				"#i c #478e40",
				"#b c #519a49",
				"#k c #579f4f",
				"#f c #59a051",
				"#. c #5aa252",
				".5 c #5aa651",
				".2 c #5ca353",
				"#j c #5ca354",
				".R c #5da454",
				".F c #5fa556",
				".i c #60a657",
				".o c #61a758",
				".U c #63b059",
				"#c c #64ac5b",
				".O c #67ad5c",
				".C c #68ae5e",
				".c c #69af5f",
				".l c #6ab060",
				".Y c #6ab260",
				".f c #6cb262",
				".b c #6db363",
				".Z c #6db463",
				".6 c #6db563",
				".V c #76bd6b",
				".z c #79c06d",
				"#e c #7ec874",
				".9 c #81c976",
				".8 c #81ca76",
				"#d c #82ca77",
				".1 c #82cb78",
				".0 c #83c978",
				".h c #85c87a",
				".X c #85c97a",
				".Q c #85cb79",
				".J c #86c979",
				".P c #86cc7c",
				".7 c #87cc7b",
				".E c #87cd7c",
				".D c #89cd7d",
				".v c #89ce7e",
				".u c #8ace7f",
				".n c #8bcf7f",
				".K c #8dce80",
				".m c #8dcf81",
				".g c #8fd182",
				".W c #90d284",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQt.#.aQtQt",
				"QtQtQtQtQtQtQtQtQtQtQt.#.b.c.dQt",
				"QtQtQtQtQtQtQtQtQtQt.e.f.g.h.i.j",
				"QtQtQtQtQtQtQtQtQt.k.l.m.n.o.p.q",
				"QtQt.r.sQtQtQtQt.t.c.u.v.i.w.qQt",
				"Qt.x.y.z.AQtQt.B.C.D.E.F.G.qQtQt",
				".H.I.J.K.L.M.N.O.P.Q.R.S.qQtQtQt",
				".T.U.V.W.X.Y.Z.0.1.2.3.qQtQtQtQt",
				"Qt.4.5.6.v.7.8.9#.##.qQtQtQtQtQt",
				"QtQt#a#b#c#d#e#f#g#hQtQtQtQtQtQt",
				"QtQtQt#a#i#j#k#l#hQtQtQtQtQtQtQt",
				"QtQtQtQt#m#n#o#pQtQtQtQtQtQtQtQt",
				"QtQtQtQtQt#q#pQtQtQtQtQtQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt"};
				'
		);

	INSERT INTO status(uid, name
			, flags, order_no, description, color, unid, perm_leave_bits, perm_enter_bits
			, icon_hash, icon_xpm)
		VALUES ( 
			_closed, (case when _lang=2 then 'закрыта' else 'closed' end)
			, 10 , 6, '', -6194326, _unid, 3, 3
			, '2FC17BC3275F4160945EEAEB5C1CD4E352C386256B850A61F83AD06AA0418E52'
			, '/* XPM */
				static char *dummy[]={
				"16 16 139 2",
				"Qt c None",
				".# c #010101",
				".P c #020302",
				"#L c #030303",
				"ai c #040404",
				".g c #040505",
				".D c #050505",
				"#W c #0a0a0a",
				".r c #0d0e0e",
				".q c #101111",
				"#5 c #1f201f",
				".h c #0f1112",
				".C c #181a19",
				"#X c #272726",
				"ab c #2a2b29",
				".f c #17191a",
				".Q c #1c1e1e",
				"#K c #373735",
				"ac c #373836",
				".a c #131616",
				".0 c #282928",
				"#D c #2c2e2d",
				"ah c #393937",
				".e c #2a2e2f",
				"#C c #5f615e",
				"ad c #666864",
				".1 c #3c4040",
				".b c #262a2c",
				"#u c #4c4f4d",
				"ag c #686a66",
				"#. c #525553",
				"#j c #4d514f",
				"#i c #5d605d",
				"af c #737571",
				".c c #3d4244",
				"#M c #696c68",
				"aa c #7a7c77",
				".i c #3d4243",
				"## c #4c504f",
				".O c #595d5c",
				"#t c #6c6e6b",
				"ae c #7c7e79",
				".d c #424748",
				"#V c #7d7f7b",
				".E c #484c4d",
				".p c #4a4e4f",
				"#Y c #7c7d7a",
				"#4 c #848681",
				".s c #535859",
				".B c #636766",
				"#n c #585a58",
				"#a c #5a5e5d",
				"#x c #5b5d5b",
				"#k c #5e6260",
				"#p c #5f615f",
				"#F c #606260",
				"#l c #606462",
				"#d c #616362",
				"#m c #626664",
				"#z c #646563",
				"#e c #646564",
				".4 c #646565",
				"#H c #656664",
				"#P c #666866",
				"#v c #666967",
				"#b c #666a69",
				"#N c #686a67",
				"#w c #686b69",
				".7 c #696969",
				"#S c #696a68",
				".W c #6a6c6c",
				".S c #6a6d6d",
				".V c #6b6d6d",
				"#I c #6c6d6b",
				"#c c #6c6f6e",
				"#0 c #6d6d6b",
				"#E c #6d716e",
				".R c #6d7171",
				"#3 c #6f706d",
				".I c #6f7070",
				"#Z c #70716e",
				"#q c #70736f",
				"#h c #707370",
				".Y c #717372",
				".L c #727474",
				".2 c #727675",
				"#r c #737572",
				".3 c #747776",
				"#U c #757773",
				".F c #757778",
				"#s c #757874",
				"#g c #787a78",
				"#A c #797c78",
				"#f c #797c7a",
				".u c #7b7c7d",
				"#B c #7c7f7b",
				".N c #7e8080",
				"#Q c #7e817c",
				".Z c #7f8180",
				".z c #808282",
				".t c #808283",
				"#R c #80837e",
				".8 c #828584",
				".j c #838687",
				"#J c #848681",
				".9 c #848885",
				".A c #868888",
				"#1 c #888a85",
				"#6 c #898b86",
				".o c #898c8d",
				"#2 c #8b8d88",
				"a# c #8f918c",
				".J c #8f9292",
				".K c #929595",
				"#7 c #949692",
				".v c #9c9e9e",
				".w c #9ea0a0",
				"a. c #9fa09c",
				".x c #9fa2a2",
				"#8 c #a0a29e",
				".y c #a0a3a3",
				".k c #a7a9aa",
				".n c #a9abac",
				"#9 c #aaaba8",
				".l c #acaeaf",
				".m c #adafb0",
				"#O c #b2b3b2",
				".G c #b4b4b4",
				".X c #d6d6d6",
				".M c #d7d7d7",
				"#y c #d9d9d9",
				"#G c #dddedd",
				"#o c #dfe0df",
				".6 c #e0e0e0",
				"#T c #e0e1e0",
				".H c #e1e1e1",
				".5 c #e2e2e2",
				".U c #e3e3e3",
				".T c #ffffff",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt",
				"QtQtQtQt.#.a.b.c.d.e.f.gQtQtQtQt",
				"QtQtQt.h.i.j.k.l.m.n.o.p.qQtQtQt",
				"QtQt.r.s.t.u.v.w.x.y.z.A.B.CQtQt",
				"Qt.D.E.F.G.H.I.J.K.L.M.G.N.O.PQt",
				"Qt.Q.R.S.H.T.U.V.W.X.T.H.Y.Z.0Qt",
				"Qt.1.2.3.4.5.T.U.X.T.6.7.8.9#.Qt",
				"Qt###a#b#c#d.5.T.T.6#e#f#g#h#iQt",
				"Qt#j#k#l#m#n.X.T.T#o#p#q#r#s#tQt",
				"Qt#u#v#w#x#y.T#o.6.T.6#z#A#B#CQt",
				"Qt#D#E#F#G.T.6#z#H.6.T.6#I#J#KQt",
				"Qt#L#M#N#O.6#P#Q#R#S#T.G#U#V#WQt",
				"QtQt#X#Y#Z#0#J#1#2#1#3#U#4#5QtQt",
				"QtQtQt#5#V#6#7#8#9a.a#aaabQtQtQt",
				"QtQtQtQt#WacadaeafagahaiQtQtQtQt",
				"QtQtQtQtQtQtQtQtQtQtQtQtQtQtQtQt"};
			'
		);

	_rule = "newID"();
	INSERT INTO status_rules(uid, order_no, unid, flags, result_status)
		VALUES (_rule, 1, _unid, 0, _ready);
		
		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 1, 0, 4, 3, _done);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 2, 0, 2, 5, _pause);

	_rule = "newID"();
	INSERT INTO status_rules(uid, order_no, unid, flags, result_status)
		VALUES (_rule, 2, _unid, 0, _pause);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 1, 0, 4, 4, _done);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 2, 0, 2, 2, _pause);

		INSERT INTO status_cond(ruleid, order_no, flags, var, op, cmp_status)
			VALUES (_rule, 3, 0, 2, 1, _closed);

end

$BODY$;

ALTER FUNCTION public."statusUniverseInit"(integer)
    OWNER TO sa;


-- FUNCTION: public."statusResetIcon"(integer)

-- DROP FUNCTION public."statusResetIcon"(integer);

CREATE OR REPLACE FUNCTION public."statusResetIcon"(
	_unid integer)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE SECURITY DEFINER 
AS $BODY$

declare
	
begin	
	perform "perm_checkGlobal"(_unid, 'mng_tag_act');
	
	update status set mtm=now(), icon_hash='DC521E66D8C5460CDB153B6C4EAC2165345C7825B64374DC4DB46972B9B15063', color=-5927847  where unid=$1 and (name='на паузе' or name='paused');
	update status set mtm=now(), icon_hash='10DCFA2085F30B8EF98A6A9F5104BC6355586953F942289DF83AA2A35600CCD5', color=-8996650  where unid=$1 and (name='готова к работе' or name='ready to start');
	update status set mtm=now(), icon_hash='3F30ACDF3E302C02C4610B500A25084F4EE22E9D1858481A9623CC63ABDFD54C', color=-4494477  where unid=$1 and (name='на переработку' or name='could be better');
	update status set mtm=now(), icon_hash='6CB08471861638C597F3E88EB0318E37EE751791B5F2C642A1353D47D2942456', color=-6975521  where unid=$1 and (name='в работе' or name='in progress');
	update status set mtm=now(), icon_hash='84523D49556B71A52D5ECC9E876A0237DFCE03B62C46014697E56272DFF68809', color=-3358100  where unid=$1 and (name='на утверждение' or name='pending review');
	update status set mtm=now(), icon_hash='3A1347FACD94E20C6A392F1C1E7E7FEA1D219FB130F4BC4AA60023548949065E', color=-10507146  where unid=$1 and (name='выполнена' or name='completed');
	update status set mtm=now(), icon_hash='2FC17BC3275F4160945EEAEB5C1CD4E352C386256B850A61F83AD06AA0418E52', color=-6194326  where unid=$1 and (name='закрыта' or name='closed');
end

$BODY$;

ALTER FUNCTION public."statusResetIcon"(integer)
    OWNER TO sa;

