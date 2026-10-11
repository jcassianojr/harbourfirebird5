# 📘 Harbour Documentation

**Generated:** 10/11/2026
**Total symbols:** 137

## 📑 Table of Contents

- [FBClass_SetLoadBlobs](#fbclass_setloadblobs) `[function]`
- [FBClass_SetLoadMemos](#fbclass_setloadmemos) `[function]`
- [New](#new) `[method]`
- [TableExists](#tableexists) `[method]`
- [ListTables](#listtables) `[method]`
- [TableStruct](#tablestruct) `[method]`
- [Close](#close) `[method]`
- [Destroy](#destroy) `[method]`
- [StartTransaction](#starttransaction) `[method]`
- [Commit](#commit) `[method]`
- [Rollback](#rollback) `[method]`
- [Execute](#execute) `[method]`
- [Query](#query) `[method]`
- [Update](#update) `[method]`
- [Delete](#delete) `[method]`
- [Append](#append) `[method]`
- [GetServerInfo](#getserverinfo) `[method]`
- [SetError](#seterror) `[method]`
- [NetErr](#neterr) `[method]`
- [Error](#error) `[method]`
- [ErrorNo](#errorno) `[method]`
- [ValToSql](#valtosql) `[method]`
- [New](#new) `[method]`
- [SetError](#seterror) `[method]`
- [StartTransaction](#starttransaction) `[method]`
- [Close](#close) `[method]`
- [Destroy](#destroy) `[method]`
- [Rollback](#rollback) `[method]`
- [Commit](#commit) `[method]`
- [Execute](#execute) `[method]`
- [Query](#query) `[method]`
- [TableExists](#tableexists) `[method]`
- [ListTables](#listtables) `[method]`
- [TableStruct](#tablestruct) `[method]`
- [Delete](#delete) `[method]`
- [Append](#append) `[method]`
- [Update](#update) `[method]`
- [New](#new) `[method]`
- [Destroy](#destroy) `[method]`
- [Close](#close) `[method]`
- [Refresh](#refresh) `[method]`
- [Fetch](#fetch) `[method]`
- [Skip](#skip) `[method]`
- [Bof](#bof) `[method]`
- [Eof](#eof) `[method]`
- [RecNo](#recno) `[method]`
- [NetErr](#neterr) `[method]`
- [Error](#error) `[method]`
- [ErrorNo](#errorno) `[method]`
- [FCount](#fcount) `[method]`
- [Struct](#struct) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldLen](#fieldlen) `[method]`
- [FieldDec](#fielddec) `[method]`
- [FieldType](#fieldtype) `[method]`
- [LastRec](#lastrec) `[method]`
- [LastRecError](#lastrecerror) `[method]`
- [FieldGet](#fieldget) `[method]`
- [GetRow](#getrow) `[method]`
- [GetBlankRow](#getblankrow) `[method]`
- [Blank](#blank) `[method]`
- [GetKeyField](#getkeyfield) `[method]`
- [SetError](#seterror) `[method]`
- [New](#new) `[method]`
- [LastRec](#lastrec) `[method]`
- [SetError](#seterror) `[method]`
- [Refresh](#refresh) `[method]`
- [Destroy](#destroy) `[method]`
- [Fetch](#fetch) `[method]`
- [Struct](#struct) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldType](#fieldtype) `[method]`
- [FieldLen](#fieldlen) `[method]`
- [FieldDec](#fielddec) `[method]`
- [FieldGet](#fieldget) `[method]`
- [Getrow](#getrow) `[method]`
- [GetBlankRow](#getblankrow) `[method]`
- [GetKeyField](#getkeyfield) `[method]`
- [New](#new) `[method]`
- [Changed](#changed) `[method]`
- [GetTables](#gettables) `[method]`
- [FCount](#fcount) `[method]`
- [FieldGet](#fieldget) `[method]`
- [FieldPut](#fieldput) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldLen](#fieldlen) `[method]`
- [FieldDec](#fielddec) `[method]`
- [FieldType](#fieldtype) `[method]`
- [GetKeyField](#getkeyfield) `[method]`
- [new](#new) `[method]`
- [Changed](#changed) `[method]`
- [FieldGet](#fieldget) `[method]`
- [FieldPut](#fieldput) `[method]`
- [FieldName](#fieldname) `[method]`
- [FieldPos](#fieldpos) `[method]`
- [FieldType](#fieldtype) `[method]`
- [FieldLen](#fieldlen) `[method]`
- [FieldDec](#fielddec) `[method]`
- [GetKeyField](#getkeyfield) `[method]`
- [GetServerInfo](#getserverinfo) `[method]`
- [FBClass_PegarMemo](#fbclass_pegarmemo) `[function]`
- [FBClass_GravarMemo](#fbclass_gravarmemo) `[function]`
- [FBClass_PegarBlobJpg](#fbclass_pegarblobjpg) `[function]`
- [FBClass_GravarBlobJpg](#fbclass_gravarblobjpg) `[function]`
- [AREA_CONN](#area_conn) `[constant]`
- [AREA_TABLE](#area_table) `[constant]`
- [AREA_PK](#area_pk) `[constant]`
- [AREA_CACHE](#area_cache) `[constant]`
- [AREA_RECNO](#area_recno) `[constant]`
- [AREA_ROWBUF](#area_rowbuf) `[constant]`
- [AREA_APPEND](#area_append) `[constant]`
- [AREA_EOF](#area_eof) `[constant]`
- [AREA_BOF](#area_bof) `[constant]`
- [AREA_FIELDS](#area_fields) `[constant]`
- [AREA_STRUCT](#area_struct) `[constant]`
- [AREA_QUERY](#area_query) `[constant]`
- [AREA_TYPES](#area_types) `[constant]`
- [AREA_SQLTYPES](#area_sqltypes) `[constant]`
- [AREA_SQLSUBTYPES](#area_sqlsubtypes) `[constant]`
- [AREA_DIRTY](#area_dirty) `[constant]`
- [AREA_LEN](#area_len) `[constant]`
- [DBFB5CONNECTION](#dbfb5connection) `[function]`
- [DBFB5GETHANDLE](#dbfb5gethandle) `[function]`
- [DBFB5CLEARCONNECTION](#dbfb5clearconnection) `[function]`
- [DBFB5COMMIT](#dbfb5commit) `[function]`
- [DBFB5ROLLBACK](#dbfb5rollback) `[function]`
- [FB5_SETPK](#fb5_setpk) `[function]`
- [FB5RDD_GETFUNCTABLE](#fb5rdd_getfunctable) `[function]`
- [FB5_SetLoadBlobs](#fb5_setloadblobs) `[function]`
- [FB5_SetLoadMemos](#fb5_setloadmemos) `[function]`
- [FB5_PegarMemo](#fb5_pegarmemo) `[function]`
- [FB5_GravarMemo](#fb5_gravarmemo) `[function]`
- [FB5_PegarBlobJpg](#fb5_pegarblobjpg) `[function]`
- [FB5_GravarBlobJpg](#fb5_gravarblobjpg) `[function]`

---

## FBClass_SetLoadBlobs
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 14)

---

## FBClass_SetLoadMemos
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 21)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 65)

---

## TableExists
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 67)

---

## ListTables
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 68)

---

## TableStruct
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 69)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 70)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 71)

---

## StartTransaction
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 73)

---

## Commit
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 74)

---

## Rollback
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 75)

---

## Execute
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 77)

---

## Query
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 78)

---

## Update
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 80)

---

## Delete
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 81)

---

## Append
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 82)

---

## GetServerInfo
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 83)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 85)

---

## NetErr
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 86)

---

## Error
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 87)

---

## ErrorNo
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 88)

---

## ValToSql
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 89)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 93)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 113)

---

## StartTransaction
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 125)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 150)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 165)

---

## Rollback
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 169)

---

## Commit
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 189)

---

## Execute
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 209)

---

## Query
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 235)

---

## TableExists
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 238)

---

## ListTables
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 255)

---

## TableStruct
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 274)

---

## Delete
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 381)

---

## Append
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 413)

---

## Update
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 459)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 517)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 518)

---

## Close
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 519)

---

## Refresh
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 521)

---

## Fetch
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 522)

---

## Skip
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 523)

---

## Bof
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 525)

---

## Eof
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 526)

---

## RecNo
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 527)

---

## NetErr
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 529)

---

## Error
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 530)

---

## ErrorNo
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 531)

---

## FCount
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 533)

---

## Struct
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 534)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 535)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 536)

---

## FieldLen
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 537)

---

## FieldDec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 538)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 539)

---

## LastRec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 540)

---

## LastRecError
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 541)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 543)

---

## GetRow
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 544)

---

## GetBlankRow
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 545)

---

## Blank
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 546)

---

## GetKeyField
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 547)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 548)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 552)

---

## LastRec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 566)

---

## SetError
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 590)

---

## Refresh
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 602)

---

## Destroy
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 648)

---

## Fetch
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 666)

---

## Struct
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 689)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 702)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 712)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 722)

---

## FieldLen
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 732)

---

## FieldDec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 742)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 752)

---

## Getrow
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 812)

---

## GetBlankRow
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 830)

---

## GetKeyField
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 869)

---

## New
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 887)

---

## Changed
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 888)

---

## GetTables
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 889)

---

## FCount
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 890)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 891)

---

## FieldPut
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 892)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 893)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 894)

---

## FieldLen
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 895)

---

## FieldDec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 896)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 897)

---

## GetKeyField
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 898)

---

## new
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 902)

---

## Changed
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 913)

---

## FieldGet
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 923)

---

## FieldPut
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 933)

---

## FieldName
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 954)

---

## FieldPos
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 964)

---

## FieldType
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 967)

---

## FieldLen
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 977)

---

## FieldDec
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 987)

---

## GetKeyField
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 997)

---

## GetServerInfo
**Type:** `method`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 1040)

---

## FBClass_PegarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 1432)

---

## FBClass_GravarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 1439)

---

## FBClass_PegarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 1448)

---

## FBClass_GravarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\Fb5class.prg` (line 1459)

---

## AREA_CONN
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 15)

### 💎 Value
```harbour
"1"
```

---

## AREA_TABLE
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 16)

### 💎 Value
```harbour
"2"
```

---

## AREA_PK
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 17)

### 💎 Value
```harbour
"3"
```

---

## AREA_CACHE
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 18)

### 💎 Value
```harbour
"4"
```

---

## AREA_RECNO
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 19)

### 💎 Value
```harbour
"5"
```

---

## AREA_ROWBUF
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 20)

### 💎 Value
```harbour
"6"
```

---

## AREA_APPEND
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 21)

### 💎 Value
```harbour
"7"
```

---

## AREA_EOF
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 22)

### 💎 Value
```harbour
"8"
```

---

## AREA_BOF
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 23)

### 💎 Value
```harbour
"9"
```

---

## AREA_FIELDS
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 24)

### 💎 Value
```harbour
"10"
```

---

## AREA_STRUCT
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 25)

### 💎 Value
```harbour
"11"
```

---

## AREA_QUERY
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 26)

### 💎 Value
```harbour
"12"
```

---

## AREA_TYPES
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 27)

### 💎 Value
```harbour
"14"
```

---

## AREA_SQLTYPES
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 28)

### 💎 Value
```harbour
"15"
```

---

## AREA_SQLSUBTYPES
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 29)

### 💎 Value
```harbour
"16"
```

---

## AREA_DIRTY
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 30)

### 💎 Value
```harbour
"17"
```

---

## AREA_LEN
**Type:** `constant`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 31)

### 💎 Value
```harbour
"17"
```

---

## DBFB5CONNECTION
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 43)

---

## DBFB5GETHANDLE
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 59)

---

## DBFB5CLEARCONNECTION
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 65)

---

## DBFB5COMMIT
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 86)

---

## DBFB5ROLLBACK
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 93)

---

## FB5_SETPK
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 101)

---

## FB5RDD_GETFUNCTABLE
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 996)

---

## FB5_SetLoadBlobs
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1042)

---

## FB5_SetLoadMemos
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1043)

---

## FB5_PegarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1045)

---

## FB5_GravarMemo
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1052)

---

## FB5_PegarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1060)

---

## FB5_GravarBlobJpg
**Type:** `function`
**Source:** `c:\develop\harbour\firebird5\hbfbird5\FB5RDD.prg` (line 1068)

---

