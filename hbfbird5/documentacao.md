# 📘 Documentacao Tecnica do Projeto
> Gerado em: 26/10/2026 16:25:38

## 🏗️ Estrutura de Modulos (PRGs)

### 📄 Arquivo: `Fb5class`
- Function FBClass_SetLoadBlobs()
- Function FBClass_SetLoadMemos()
- Method New()
- Method SetError()
- Method StartTransaction()
- Method Close()
- Method Destroy()
- Method Rollback()
- Method Commit()
- Method Execute()
- Method Query()
- Method TableExists()
- Method ListTables()
- Method TableStruct()
- Method Delete()
- Method Append()
- Method Update()
- Method New()
- Method LastRec()
- Method SetError()
- Method Refresh()
- Method Destroy()
- Method Fetch()
- Method Struct()
- Method FieldPos()
- Method FieldName()
- Method FieldType()
- Method FieldLen()
- Method FieldDec()
- Method FieldGet()
- Method Getrow()
- Method GetBlankRow()
- Method GetKeyField()
- Method new()
- Method Changed()
- Method FieldGet()
- Method FieldPut()
- Method FieldName()
- Method FieldPos()
- Method FieldType()
- Method FieldLen()
- Method FieldDec()
- Method GetKeyField()
- Static Function KeyField()
- Method GetServerInfo()
- Static Function DataToSql()
- Static Function ToNumber()
- Static Function StructConvert()
- Static Function RemoveSpaces()
- Static Function strlogicClasse()
- Static Function StrDateclass()
- Function FBClass_PegarMemo()
- Function FBClass_GravarMemo()
- Function FBClass_PegarBlobJpg()
- Function FBClass_GravarBlobJpg()
- Static Function UniversalDateTime()

### 📄 Arquivo: `FB5RDD`
- Function DBFB5CONNECTION()
- Function DBFB5GETHANDLE()
- Function DBFB5CLEARCONNECTION()
- Function DBFB5COMMIT()
- Function DBFB5ROLLBACK()
- Function FB5_SETPK()
- Static Function FB5_INIT()
- Static Function FB5_NEW()
- Static Function FB5_ADDFIELD()
- Static Function FB5_OPEN()
- Static Function FB5_CLOSE()
- Static Function FB5_GETVALUE()
- Static Function FB5_PUTVALUE()
- Static Function FB5_SKIP()
- Static Function FB5_GOTOP()
- Static Function FB5_GOBOTTOM()
- Static Function FB5_GOTOID()
- Static Function FB5_GOTO()
- Static Function FB5_RECCOUNT()
- Static Function FB5_BOF()
- Static Function FB5_EOF()
- Static Function FB5_RECID()
- Static Function FB5_APPEND()
- Static Function FB5_FLUSH()
- Static Function FB5_DELETE()
- Static Function FB5_ValToSql()
- Static Function FB5_ToNumber()
- Static Function FB5_RDDINFO()
- Static Function FB5_INFO()
- Static Function FB5_CREATE()
- Static Function FB5_HydrateRow()
- Function FB5RDD_GETFUNCTABLE()
- Init Procedure FB5_INIT_REGISTER()
- Static Function FB5_RealFetchBlob()
- Procedure FB5_SetLoadBlobs()
- Procedure FB5_SetLoadMemos()
- Function FB5_PegarMemo()
- Function FB5_GravarMemo()
- Function FB5_PegarBlobJpg()
- Function FB5_GravarBlobJpg()
- Static Function strlogicrdd()
- Static Function StrDateRdd()
- Static Function UniversalDateTime()

## 📊 Dicionario de Dados e Acessos

## 🕸️ Diagrama de Relacionamento (Mermaid)
```mermaid
graph TD
    destroy --> __close["::close       <externa>"]
    refresh --> __destroy["::destroy     <externa>"]
    append --> __execute["::execute     <externa>"]
    update --> __fetch["::fetch       <externa>"]
    getrow --> __fieldget["::fieldget    <externa>"]
    fieldput --> __fieldtype["::fieldtype   <externa>"]
    update --> __getblankrow["::getblankrow <externa>"]
    getserverinfo --> __query["::query       <externa>"]
    new --> __refresh["::refresh     <externa>"]
    close --> __rollback["::rollback    <externa>"]
    commit --> __seterror["::seterror    <externa>"]
    getblankrow --> _new[":new          <externa>"]
    fbclass_setloadmemos --> append["append        in fb5class.prg"]
    update --> blank["blank         <externa>"]
    getkeyfield --> changed["changed       in fb5class.prg"]
    fbclass_setloadmemos --> close["close         in fb5class.prg"]
    fbclass_setloadmemos --> commit["commit        in fb5class.prg"]
    fbclass_setloadmemos --> datatosql["datatosql     in fb5class.prg"]
    fbclass_setloadmemos --> delete["delete        in fb5class.prg"]
    fbclass_setloadmemos --> destroy["destroy       in fb5class.prg"]
    static fb5_create --> errornew["errornew      <externa>"]
    fbclass_setloadmemos --> errorno["errorno       <externa>"]
    fbclass_setloadmemos --> execute["execute       in fb5class.prg"]
    fb5rdd_getfunctable --> fb5_addfield["fb5_addfield  in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_append["fb5_append    in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_bof["fb5_bof       in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_close["fb5_close     in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_create["fb5_create    in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_delete["fb5_delete    in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_eof["fb5_eof       in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_flush["fb5_flush     in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_getvalue["fb5_getvalue  in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_gobottom["fb5_gobottom  in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_goto["fb5_goto      in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_gotoid["fb5_gotoid    in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_gotop["fb5_gotop     in fb5rdd.prg"]
    static fb5_delete --> fb5_hydraterow["fb5_hydraterow in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_info["fb5_info      in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_init["fb5_init      in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_new["fb5_new       in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_open["fb5_open      in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_putvalue["fb5_putvalue  in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_rddinfo["fb5_rddinfo   in fb5rdd.prg"]
    static fb5_getvalue --> fb5_rddinfo["fb5_rddinfo   in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_reccount["fb5_reccount  in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_recid["fb5_recid     in fb5rdd.prg"]
    fb5_gravarblobjpg --> fb5_recid["fb5_recid     in fb5rdd.prg"]
    fb5_gravarmemo --> fb5_recid["fb5_recid     in fb5rdd.prg"]
    fb5rdd_getfunctable --> fb5_skip["fb5_skip      in fb5rdd.prg"]
    static fb5_hydraterow --> fb5_tonumber["fb5_tonumber  in fb5rdd.prg"]
    static fb5_delete --> fb5_valtosql["fb5_valtosql  in fb5rdd.prg"]
    fbclass_gravarblobjpg --> fb5_valtosql["fb5_valtosql  in fb5rdd.prg"]
    fbclass_gravarmemo --> fb5_valtosql["fb5_valtosql  in fb5rdd.prg"]
    close --> fbclose["fbclose       <externa>"]
    commit --> fbcommit["fbcommit      <externa>"]
    new --> fbconnect["fbconnect     <externa>"]
    fbclass_setloadmemos --> fberror["fberror       <externa>"]
    execute --> fbexecute["fbexecute     <externa>"]
    append --> fbfetch["fbfetch       <externa>"]
    append --> fbfree["fbfree        <externa>"]
    fieldget --> fbgetblob["fbgetblob     <externa>"]
    append --> fbgetdata["fbgetdata     <externa>"]
    append --> fbquery["fbquery       <externa>"]
    rollback --> fbrollback["fbrollback    <externa>"]
    starttransaction --> fbrollback["fbrollback    <externa>"]
    update --> fetch["fetch         in fb5class.prg"]
    getkeyfield --> fielddec["fielddec      in fb5class.prg"]
    getkeyfield --> fieldlen["fieldlen      in fb5class.prg"]
    getkeyfield --> fieldtype["fieldtype     in fb5class.prg"]
    update --> getblankrow["getblankrow   in fb5class.prg"]
    getkeyfield --> getkeyfield["getkeyfield   in fb5class.prg"]
    update --> getrow["getrow        in fb5class.prg"]
    fbclass_setloadmemos --> getserverinfo["getserverinfo in fb5class.prg"]
    getkeyfield --> gettables["gettables     <externa>"]
    refresh --> hb_ascan["hb_ascan      in harbour.lib"]
    static strdateclass --> hb_atokens["hb_atokens    in harbour.lib"]
    static universaldatetime --> hb_datetime["hb_datetime   in harbour.lib"]
    new --> hb_default["hb_default    in harbour.lib"]
    fbclass_gravarblobjpg --> hb_fileexists["hb_fileexists in harbour.lib"]
    static datatosql --> hb_hour["hb_hour       in harbour.lib"]
    append --> hb_isarray["hb_isarray    in harbour.lib"]
    fbclass_setloadblobs --> hb_islogical["hb_islogical  in harbour.lib"]
    append --> hb_isnumeric["hb_isnumeric  in harbour.lib"]
    fbclass_gravarblobjpg --> hb_memoread["hb_memoread   in harbour.lib"]
    fbclass_pegarblobjpg --> hb_memowrit["hb_memowrit   in harbour.lib"]
    static datatosql --> hb_minute["hb_minute     in harbour.lib"]
    dbfb5connection --> hb_ntos["hb_ntos       in harbour.lib"]
    static datatosql --> hb_sec["hb_sec        in harbour.lib"]
    fieldget --> hb_stod["hb_stod       in harbour.lib"]
    fieldget --> hb_stot["hb_stot       in harbour.lib"]
    static datatosql --> hb_strtohex["hb_strtohex   in harbour.lib"]
    dbfb5commit --> hb_strtohex["hb_strtohex   in harbour.lib"]
    static strlogicclasse --> hb_valtostr["hb_valtostr   in harbour.lib"]
    getkeyfield --> keyfield["keyfield      in fb5class.prg"]
    update --> lastrecerror["lastrecerror  <externa>"]
    fbclass_setloadmemos --> listtables["listtables    in fb5class.prg"]
    fbclass_setloadmemos --> new["new           in fb5class.prg"]
    fbclass_pegarblobjpg --> oobj_fieldget["oobj:fieldget <externa>"]
    fbclass_pegarblobjpg --> oobj_fieldpos["oobj:fieldpos <externa>"]
    lastrec --> oobj_fieldpos["oobj:fieldpos <externa>"]
    lastrec --> oobj_fieldpos["oobj:fieldpos <externa>"]
    lastrec --> oqcount_fetch["oqcount:fetch <externa>"]
    lastrec --> oqcount_fetch["oqcount:fetch <externa>"]
    lastrec --> oqcount_neterr["oqcount:neterr <externa>"]
    getserverinfo --> oquery_destroy["oquery:destroy <externa>"]
    getserverinfo --> oquery_eof["oquery:eof    <externa>"]
    getserverinfo --> oquery_fetch["oquery:fetch  <externa>"]
    getserverinfo --> oquery_fetch["oquery:fetch  <externa>"]
    append --> orow_changed["orow:changed  <externa>"]
    append --> orow_fcount["orow:fcount   <externa>"]
    append --> orow_fieldget["orow:fieldget <externa>"]
    append --> orow_fieldname["orow:fieldname <externa>"]
    fbclass_gravarblobjpg --> orow_fieldpos["orow:fieldpos <externa>"]
    fbclass_gravarblobjpg --> orow_fieldput["orow:fieldput <externa>"]
    append --> orow_fieldtype["orow:fieldtype <externa>"]
    append --> orow_fieldtype["orow:fieldtype <externa>"]
    append --> orow_gettables["orow:gettables <externa>"]
    fbclass_setloadmemos --> query["query         in fb5class.prg"]
    update --> refresh["refresh       in fb5class.prg"]
    listtables --> removespaces["removespaces  in fb5class.prg"]
    fbclass_setloadmemos --> rollback["rollback      in fb5class.prg"]
    fbclass_setloadmemos --> seterror["seterror      in fb5class.prg"]
    update --> skip["skip          <externa>"]
    fbclass_setloadmemos --> skip["skip          <externa>"]
    static strdateclass --> stod["stod          in harbour.lib"]
    fieldget --> strdateclass["strdateclass  in fb5class.prg"]
    static fb5_hydraterow --> strdaterdd["strdaterdd    in fb5rdd.prg"]
    fieldget --> strlogicclasse["strlogicclasse in fb5class.prg"]
    static fb5_hydraterow --> strlogicrdd["strlogicrdd   in fb5rdd.prg"]
    update --> struct["struct        in fb5class.prg"]
    refresh --> structconvert["structconvert in fb5class.prg"]
    fbclass_setloadmemos --> tableexists["tableexists   in fb5class.prg"]
    fbclass_setloadmemos --> tablestruct["tablestruct   in fb5class.prg"]
    lastrec --> tfbquery["tfbquery      in hbfbird.lib"]
    getblankrow --> tfbrow["tfbrow        in hbfbird.lib"]
    append --> tonumber["tonumber      in fb5class.prg"]
    fieldget --> tonumber["tonumber      in fb5class.prg"]
    fbclass_setloadmemos --> update["update        in fb5class.prg"]
    static fb5_addfield --> update["update        in fb5class.prg"]
    static fb5_close --> ur_super_close["ur_super_close in hbusrrdd.lib"]
    static fb5_create --> ur_super_error["ur_super_error in hbusrrdd.lib"]
    static fb5_info --> ur_super_info["ur_super_info in hbusrrdd.lib"]
    static fb5_open --> ur_super_open["ur_super_open in hbusrrdd.lib"]
    static fb5_rddinfo --> ur_super_open["ur_super_open in hbusrrdd.lib"]
    static fb5_open --> ur_super_open["ur_super_open in hbusrrdd.lib"]
    fb5_setpk --> ur_super_open["ur_super_open in hbusrrdd.lib"]
    fb5rdd_getfunctable --> ur_super_open["ur_super_open in hbusrrdd.lib"]
    static fb5_init --> usrrdd_rdddata["usrrdd_rdddata in hbusrrdd.lib"]
    fbclass_setloadmemos --> valtosql["valtosql      <externa>"]
```
