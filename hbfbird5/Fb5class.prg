/*
 * Firebird RDBMS low-level (client API) interface code for Firebird 5.
 * Adapted for Harbour Project (Fb5class - Versão Final Otimizada)
 */

#include "hbclass.ch"

/* Macros oficiais do Firebird 5 / InterBase para tipos SQL e Dialetos */
#define IB_SQL_TEXT                           452
#define IB_SQL_VARYING                        448
#define IB_SQL_SHORT                          500
#define IB_SQL_LONG                           496
#define IB_SQL_FLOAT                          482
#define IB_SQL_DOUBLE                         480
#define IB_SQL_D_FLOAT                        530
#define IB_SQL_TIMESTAMP                      510
#define IB_SQL_BLOB                           520
#define IB_SQL_ARRAY                          540
#define IB_SQL_QUAD                           550
#define IB_SQL_TYPE_TIME                      560
#define IB_SQL_TYPE_DATE                      570
#define IB_SQL_INT64                          580
#define IB_SQL_DATE                           IB_SQL_TIMESTAMP
#define IB_SQL_BOOLEAN                        32764

#define IB_DIALECT_V5                         1
#define IB_DIALECT_V6_TRANSITION              2
#define IB_DIALECT_V6                         3
#define IB_DIALECT_CURRENT                    IB_DIALECT_V6

CREATE CLASS Fb5class

   VAR db
   VAR trans
   VAR StartedTrans
   VAR nError
   VAR lError
   VAR dialect
   VAR charset

   METHOD New( cServer, cUser, cPassword, nDialect, cCharSet )
   METHOD Destroy()  INLINE FBClose( ::db )
   METHOD Close()    INLINE FBClose( ::db )

   METHOD TableExists( cTable )
   METHOD ListTables()
   METHOD TableStruct( cTable )

   METHOD StartTransaction()
   METHOD Commit()
   METHOD Rollback()

   METHOD Execute( cQuery )
   METHOD Query( cQuery )

   METHOD Update( oRow, cWhere )
   METHOD Delete( oRow, cWhere )
   METHOD Append( oRow )
   METHOD   GetServerInfo()


   METHOD NetErr()   INLINE ::lError
   METHOD Error()    INLINE FBError( ::nError )
   METHOD ErrorNo()  INLINE ::nError

ENDCLASS

METHOD New( cServer, cUser, cPassword, nDialect, cCharSet ) CLASS Fb5class

   hb_default( @nDialect, IB_DIALECT_CURRENT )
   hb_default( @cCharSet, "UTF8" )

   ::lError := .F.
   ::nError := 0
   ::StartedTrans := .F.
   ::Dialect := nDialect
   ::charset := cCharSet

   ::db := FBConnect( cServer, cUser, cPassword, ::charset )

   IF HB_ISNUMERIC( ::db )
      ::lError := .T.
      ::nError := ::db
   ENDIF

   RETURN Self

METHOD StartTransaction() CLASS Fb5class

   LOCAL result := .F.

   ::trans := FBStartTransaction( ::db )

   IF HB_ISNUMERIC( ::trans )
      ::lError := .T.
      ::nError := ::trans
   ELSE
      result := .T.
      ::lError := .F.
      ::nError := 0
      ::StartedTrans := .T.
   ENDIF

   RETURN result

METHOD Rollback() CLASS Fb5class

   LOCAL result := .F.
   LOCAL n

   IF ::StartedTrans
      IF ( n := FBRollback( ::trans ) ) < 0
         ::lError := .T.
         ::nError := n
      ELSE
         ::lError := .F.
         ::nError := 0
         result := .T.
         ::StartedTrans := .F.
      ENDIF
   ENDIF

   RETURN result

METHOD Commit() CLASS Fb5class

   LOCAL result := .F.
   LOCAL n

   IF ::StartedTrans
      IF ( n := FBCommit( ::trans ) ) < 0
         ::lError := .T.
         ::nError := n
      ELSE
         ::lError := .F.
         ::nError := 0
         result := .T.
         ::StartedTrans := .F.
      ENDIF
   ENDIF

   RETURN result

METHOD Execute( cQuery ) CLASS Fb5class

   LOCAL result
   LOCAL n

   cQuery := RemoveSpaces( cQuery )

   IF ::StartedTrans
      n := FBExecute( ::db, cQuery, ::dialect, ::trans )
   ELSE
      n := FBExecute( ::db, cQuery, ::dialect )
   ENDIF

   IF n < 0
      ::lError := .T.
      ::nError := n
      result := .F.
   ELSE
      ::lError := .F.
      ::nError := 0
      result := .T.
   ENDIF

   RETURN result

METHOD Query( cQuery ) CLASS Fb5class
   RETURN TFBQuery():New( ::db, cQuery, ::dialect )

METHOD TableExists( cTable ) CLASS Fb5class

   LOCAL cQuery
   LOCAL result := .F.
   LOCAL qry

   cQuery := "select rdb$relation_name from rdb$relations where rdb$relation_name = '" + Upper( AllTrim( cTable ) ) + "'"

   qry := FBQuery( ::db, cQuery, ::dialect )

   IF HB_ISARRAY( qry )
      result := ( FBFetch( qry ) == 0 )
      FBFree( qry )
   ENDIF

   RETURN result

METHOD ListTables() CLASS Fb5class

   LOCAL result := {}
   LOCAL cQuery
   LOCAL qry

   cQuery := "SELECT TRIM(RDB$RELATION_NAME) AS TABLE_NAME FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG, 0) = 0 AND RDB$VIEW_BLR IS NULL ORDER BY RDB$RELATION_NAME"

   qry := FBQuery( ::db, RemoveSpaces( cQuery ), ::dialect )

   IF HB_ISARRAY( qry )
      DO WHILE FBFetch( qry ) == 0
         AAdd( result, FBGetData( qry, 1 ) )
      ENDDO
      FBFree( qry )
   ENDIF

   RETURN result

METHOD TableStruct( cTable ) CLASS Fb5class

   LOCAL result := {}
   LOCAL cQuery, cType, nSize, cDomain, cField, nType, nDec
   LOCAL qry

   cQuery := "select "
   cQuery += "  TRIM(a.rdb$field_name),"
   cQuery += "  b.rdb$field_type,"
   cQuery += "  b.rdb$field_length,"
   cQuery += "  b.rdb$field_scale * -1,"
   cQuery += "  a.rdb$field_source "
   cQuery += "from "
   cQuery += "  rdb$relation_fields a, rdb$fields b "
   cQuery += "where "
   cQuery += "  a.rdb$field_source = b.rdb$field_name "
   cQuery += "  and a.rdb$relation_name = '" + Upper( AllTrim( ctable ) ) + "' "
   cQuery += "order by "
   cQuery += "  a.rdb$field_position "

   qry := FBQuery( ::db, RemoveSpaces( cQuery ), ::dialect )

   IF HB_ISARRAY( qry )
      DO WHILE FBFetch( qry ) == 0
         cField  := RTrim( iif( FBGetData( qry, 1 ) == NIL, "", FBGetData( qry, 1 ) ) )
         nType   := Val( iif( FBGetData( qry, 2 ) == NIL, "0", FBGetData( qry, 2 ) ) )
         nSize   := Val( iif( FBGetData( qry, 3 ) == NIL, "0", FBGetData( qry, 3 ) ) )
         nDec    := Val( iif( FBGetData( qry, 4 ) == NIL, "0", FBGetData( qry, 4 ) ) )
         cDomain := RTrim( iif( FBGetData( qry, 5 ) == NIL, "", FBGetData( qry, 5 ) ) )

         // Tratamento explícito para evitar ambiguidade (W0001) e uso correto de nType (W0032)
         SWITCH nType
            CASE IB_SQL_BOOLEAN
               cType := "L"
               nSize := 1
               nDec  := 0
               EXIT
            CASE 7 // SMALLINT
               IF "BOOL" $ cDomain
                  cType := "L"
                  nSize := 1
                  nDec  := 0
               ELSE
                  cType := "N"
                  nSize := 5
               ENDIF
               EXIT
            CASE 8 // INTEGER
            CASE 9
               cType := "N"
               nSize := 9
               EXIT
            CASE 10 // FLOAT
            CASE 11
               cType := "N"
               nSize := 15
               EXIT
            CASE 12 // DATE
               cType := "D"
               nSize := 8
               EXIT
            CASE 13 // TIME
               cType := "C"
               nSize := 10
               EXIT
            CASE 14 // CHAR
               cType := "C"
               EXIT
            CASE 16 // INT64
               cType := "N"
               nSize := 9
               EXIT
            CASE 27 // DOUBLE
               cType := "N"
               nSize := 15
               EXIT
            CASE 35 // TIMESTAMP
               cType := "D"
               nSize := 8
               EXIT
            CASE 37 // VARCHAR
            CASE 40
               cType := "C"
               EXIT
            CASE 261 // BLOB
               cType := "M"
               nSize := 10
               EXIT
            OTHERWISE
               cType := "C"
               nDec  := 0
         ENDSWITCH

         AAdd( result, { cField, cType, nSize, nDec } )

      ENDDO
      FBFree( qry )
   ENDIF

   RETURN result

METHOD Delete( oRow, cWhere ) CLASS Fb5class

   LOCAL result := .F.
   LOCAL aKeys, i, nField, xField, cQuery, aTables

   aTables := oRow:GetTables()

   IF ! HB_ISNUMERIC( ::db ) .AND. Len( aTables ) == 1
      IF cWhere == NIL
         aKeys := oRow:GetKeyField()

         cWhere := ""
         FOR i := 1 TO Len( aKeys )
            nField := oRow:FieldPos( aKeys[ i ] )
            xField := oRow:FieldGet( nField )

            cWhere += aKeys[ i ] + "=" + DataToSql( xField )

            IF i != Len( aKeys )
               cWhere += ","
            ENDIF
         NEXT
      ENDIF

      IF !( cWhere == "" )
         cQuery := 'DELETE FROM ' + aTables[ 1 ] + ' WHERE ' + cWhere
         result := ::Execute( cQuery )
      ENDIF
   ENDIF

   RETURN result

METHOD Append( oRow ) CLASS Fb5class

   LOCAL result := .F.
   LOCAL cQuery, i, aTables, aKeys, qryIns, nPosPK

   aTables := oRow:GetTables()

   IF ! HB_ISNUMERIC( ::db ) .AND. Len( aTables ) == 1
      cQuery := 'INSERT INTO ' + aTables[ 1 ] + '('
      FOR i := 1 TO oRow:FCount()
         IF oRow:Changed( i )
            cQuery += oRow:FieldName( i ) + ","
         ENDIF
      NEXT

      cQuery := Left( cQuery, Len( cQuery ) - 1 ) +  ") VALUES ("

      FOR i := 1 TO oRow:FCount()
         IF oRow:Changed( i )
            cQuery += DataToSql( oRow:FieldGet( i ) ) + ","
         ENDIF
      NEXT

      cQuery := Left( cQuery, Len( cQuery ) - 1  ) + ")"

      aKeys := oRow:GetKeyField()
      IF Len( aKeys ) == 1
         cQuery += " RETURNING " + aKeys[ 1 ]
         qryIns := FBQuery( ::db, cQuery, ::dialect )
         IF HB_ISARRAY( qryIns )
            IF FBFetch( qryIns ) == 0
               nPosPK := oRow:FieldPos( aKeys[ 1 ] )
               IF nPosPK > 0
                  oRow:FieldPut( nPosPK, Val( FBGetData( qryIns, 1 ) ) )
               ENDIF
            ENDIF
            FBFree( qryIns )
            result := .T.
         ENDIF
      ELSE
         result := ::Execute( cQuery )
      ENDIF
   ENDIF

   RETURN result

METHOD Update( oRow, cWhere ) CLASS Fb5class

   LOCAL result := .F.
   LOCAL aKeys, cQuery, i, nField, xField, aTables

   aTables := oRow:GetTables()

   IF ! HB_ISNUMERIC( ::db ) .AND. Len( aTables ) == 1
      IF cWhere == NIL
         aKeys := oRow:GetKeyField()

         cWhere := ""
         FOR i := 1 TO Len( aKeys )
            nField := oRow:FieldPos( aKeys[ i ] )
            xField := oRow:FieldGet( nField )

            cWhere += aKeys[ i ] + "=" + DataToSql( xField )

            IF i != Len( aKeys )
               cWhere += ", "
            ENDIF
         NEXT
      ENDIF

      cQuery := "UPDATE " + aTables[ 1 ] + " SET "
      FOR i := 1 TO oRow:FCount()
         IF oRow:Changed( i )
            cQuery += oRow:FieldName( i ) + " = " + DataToSql( oRow:FieldGet( i ) ) + ","
         ENDIF
      NEXT

      IF !( cWhere == "" )
         cQuery := Left( cQuery, Len( cQuery ) - 1 ) + " WHERE " + cWhere
         result := ::Execute( cQuery )
      ENDIF
   ENDIF

   RETURN result

CREATE CLASS TFBQuery

   VAR      nError
   VAR      lError
   VAR      Dialect
   VAR      lBof
   VAR      lEof
   VAR      nRecno
   VAR      qry
   VAR      aStruct
   VAR      numcols
   VAR      closed
   VAR      db
   VAR      query
   VAR      aKeys
   VAR      aTables

   METHOD   New( nDB, cQuery, nDialect )
   METHOD   Destroy()
   METHOD   Close()            INLINE ::Destroy()

   METHOD   Refresh()
   METHOD   Fetch()
   METHOD   Skip()             INLINE ::Fetch()

   METHOD   Bof()              INLINE ::lBof
   METHOD   Eof()              INLINE ::lEof
   METHOD   RecNo()            INLINE ::nRecno

   METHOD   NetErr()           INLINE ::lError
   METHOD   Error()            INLINE FBError( ::nError )
   METHOD   ErrorNo()          INLINE ::nError

   METHOD   FCount()           INLINE ::numcols
   METHOD   Struct()
   METHOD   FieldName( nField )
   METHOD   FieldPos( cField )
   METHOD   FieldLen( nField )
   METHOD   FieldDec( nField )
   METHOD   FieldType( nField )
   METHOD   LastRec()

   METHOD   FieldGet( nField )
   METHOD   GetRow()
   METHOD   GetBlankRow()
   METHOD   Blank()            INLINE ::GetBlankRow()
   METHOD   GetKeyField()
  
ENDCLASS

METHOD New( nDB, cQuery, nDialect ) CLASS TFBQuery

   ::db := nDb
   ::query := RemoveSpaces( cQuery )
   ::dialect := nDialect
   ::closed := .T.
   ::aKeys := NIL

   ::Refresh()

   RETURN Self

METHOD LastRec() CLASS TFBQuery
   LOCAL nTotal := 0
   // Se você quiser manter a contagem exata para a barra de progresso:
   // Como a query está ativa, podemos fazer um clone ou contar os elementos se já estiverem em cache,
   // ou executar um COUNT rápido na mesma string de SQL.
   // Para manter simples e compatível com sua lógica:
   LOCAL oQCount := TFBQuery():New( ::db, "SELECT COUNT(*) FROM (" + ::query + ")", ::dialect )
   IF oQCount != NIL
      nTotal := Val( oQCount:FieldGet( 1 ) )
      oQCount:Destroy()
   ENDIF
   RETURN nTotal

METHOD Refresh() CLASS TFBQuery

   LOCAL qry, result, i, aTable := {}

   IF ! ::closed
      ::Destroy()
   ENDIF

   ::lBof := .T.
   ::lEof := .F.
   ::nRecno := 0
   ::closed := .F.
   ::numcols := 0
   ::aStruct := {}
   ::nError := 0
   ::lError := .F.

   result := .T.

   qry := FBQuery( ::db, ::query, ::dialect )

   IF HB_ISARRAY( qry )
      ::numcols := qry[ 4 ]
      ::aStruct := StructConvert( qry[ 6 ], ::db, ::dialect )

      ::lError := .F.
      ::nError := 0
      ::qry := qry

      FOR i := 1 TO Len( ::aStruct )
         IF hb_AScan( aTable, ::aStruct[ i ][ 5 ], , , .T. ) == 0
            AAdd( aTable, ::aStruct[ i ][ 5 ] )
         ENDIF
      NEXT

      ::aTables := aTable

   ELSE
      ::lError := .T.
      ::nError := qry
   ENDIF

   RETURN result

METHOD Destroy() CLASS TFBQuery

   LOCAL result := .T.
   LOCAL n

   IF ! ::lError .AND. ( n := FBFree( ::qry ) ) < 0
      ::lError := .T.
      ::nError := n
   ENDIF

   ::closed := .T.

   RETURN result

METHOD Fetch() CLASS TFBQuery

   LOCAL result := .F.
   LOCAL fetch_stat

   IF ! ::lError .AND. ! ::lEof
      IF ! ::Closed
         fetch_stat := FBFetch( ::qry )
         ::nRecno++

         IF fetch_stat == 0
            ::lBof := .F.
            result := .T.
         ELSE
            ::lEof := .T.
         ENDIF
      ENDIF
   ENDIF

   RETURN result

METHOD Struct() CLASS TFBQuery

   LOCAL result := {}
   LOCAL i

   IF ! ::lError
      FOR i := 1 TO Len( ::aStruct )
         AAdd( result, { ::aStruct[ i ][ 1 ], ::aStruct[ i ][ 2 ], ::aStruct[ i ][ 3 ], ::aStruct[ i ][ 4 ] } )
      NEXT
   ENDIF

   RETURN result

METHOD FieldPos( cField ) CLASS TFBQuery

   LOCAL result := 0

   IF ! ::lError
      result := AScan( ::aStruct, {| x | x[ 1 ] == RTrim( Upper( cField ) ) } )
   ENDIF

   RETURN result

METHOD FieldName( nField ) CLASS TFBQuery

   LOCAL result

   IF ! ::lError .AND. nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 1 ]
   ENDIF

   RETURN result

METHOD FieldType( nField ) CLASS TFBQuery

   LOCAL result

   IF ! ::lError .AND. nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 2 ]
   ENDIF

   RETURN result

METHOD FieldLen( nField ) CLASS TFBQuery

   LOCAL result

   IF ! ::lError .AND. nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 3 ]
   ENDIF

   RETURN result

METHOD FieldDec( nField ) CLASS TFBQuery

   LOCAL result

   IF ! ::lError .AND. nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 4 ]
   ENDIF

   RETURN result

METHOD FieldGet( nField ) CLASS TFBQuery

   LOCAL result, aBlob, i, cType

   IF ! ::lError .AND. nField >= 1 .AND. nField <= Len( ::aStruct ) .AND. ! ::closed
      result := FBGetData( ::qry, nField )
      cType := ::aStruct[ nField ][ 2 ]

      IF cType == "M"
         IF result != NIL
            aBlob := FBGetBlob( ::db, result )
            result := ""
            FOR i := 1 TO Len( aBlob )
               result += aBlob[ i ]
            NEXT
         ELSE
            result := ""
         ENDIF

      ELSEIF cType == "N"
         IF result != NIL
            result := Val( result )
         ELSE
            result := 0
         ENDIF

      ELSEIF cType == "D"
         IF result != NIL
            result := hb_SToD( Left( result, 4 ) + SubStr( result, 5, 2 ) + SubStr( result, 7, 2 ) )
         ELSE
            result := hb_SToD()
         ENDIF

      ELSEIF cType == "L"
         IF result != NIL
            result := ( Val( result ) == 1 .OR. Upper( AllTrim( result ) ) == "T" .OR. result == .T. )
         ELSE
            result := .F.
         ENDIF
      ENDIF
   ENDIF

   RETURN result

METHOD Getrow() CLASS TFBQuery

   LOCAL result
   LOCAL aRow
   LOCAL i

   IF ! ::lError .AND. ! ::closed
      aRow := Array( ::numcols )

      FOR i := 1 TO ::numcols
         aRow[ i ] := ::FieldGet( i )
      NEXT

      result := TFBRow():New( aRow, ::aStruct, ::db, ::dialect, ::aTables )
   ENDIF

   RETURN result

METHOD GetBlankRow() CLASS TFBQuery

   LOCAL result
   LOCAL aRow
   LOCAL i

   IF ! ::lError
      aRow := Array( ::numcols )

      FOR i := 1 TO ::numcols
         SWITCH ::aStruct[ i ][ 2 ]
         CASE "C"
         CASE "M"
            aRow[ i ] := ""
            EXIT
         CASE "N"
            aRow[ i ] := 0
            EXIT
         CASE "L"
            aRow[ i ] := .F.
            EXIT
         CASE "D"
            aRow[ i ] := hb_SToD()
            EXIT
         ENDSWITCH
      NEXT

      result := TFBRow():New( aRow, ::aStruct, ::db, ::dialect, ::aTables )
   ENDIF

   RETURN result

METHOD GetKeyField() CLASS TFBQuery

   IF ::aKeys == NIL
      ::aKeys := KeyField( ::aTables, ::db, ::dialect )
   ENDIF

   RETURN ::aKeys

CREATE CLASS TFBRow

   VAR      aRow
   VAR      aStruct
   VAR      aChanged
   VAR      aKeys
   VAR      db
   VAR      dialect
   VAR      aTables

   METHOD   New( row, struct, nDB, nDialect, aTable )
   METHOD   Changed( nField )
   METHOD   GetTables()        INLINE ::aTables
   METHOD   FCount()           INLINE Len( ::aRow )
   METHOD   FieldGet( nField )
   METHOD   FieldPut( nField, Value )
   METHOD   FieldName( nField )
   METHOD   FieldPos( cField )
   METHOD   FieldLen( nField )
   METHOD   FieldDec( nField )
   METHOD   FieldType( nField )
   METHOD   GetKeyField()

ENDCLASS

METHOD new( row, struct, nDb, nDialect, aTable ) CLASS TFBRow

   ::aRow := row
   ::aStruct := struct
   ::db := nDB
   ::dialect := nDialect
   ::aTables := aTable
   ::aChanged := Array( Len( row ) )

   RETURN Self

METHOD Changed( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. Len( ::aChanged ) >= nField .AND. ::aChanged != NIL
      result := ( ::aChanged[ nField ] != NIL )
   ENDIF

   RETURN result

METHOD FieldGet( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aRow )
      result := ::aRow[ nField ]
   ENDIF

   RETURN result

METHOD FieldPut( nField, Value ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aRow )
      ::aChanged[ nField ] := .T.
      result := ::aRow[ nField ] := Value
   ENDIF

   RETURN result

METHOD FieldName( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 1 ]
   ENDIF

   RETURN result

METHOD FieldPos( cField ) CLASS TFBRow
   RETURN AScan( ::aStruct, {| x | x[ 1 ] == RTrim( Upper( cField ) ) } )

METHOD FieldType( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 2 ]
   ENDIF

   RETURN result

METHOD FieldLen( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 3 ]
   ENDIF

   RETURN result

METHOD FieldDec( nField ) CLASS TFBRow

   LOCAL result

   IF nField >= 1 .AND. nField <= Len( ::aStruct )
      result := ::aStruct[ nField ][ 4 ]
   ENDIF

   RETURN result

METHOD GetKeyField() CLASS TFBRow

   IF ::aKeys == NIL
      ::aKeys := KeyField( ::aTables, ::db, ::dialect )
   ENDIF

   RETURN ::aKeys

STATIC FUNCTION KeyField( aTables, db, dialect )

   LOCAL cTable, cQuery
   LOCAL qry
   LOCAL aKeys := {}

   IF Len( aTables ) == 1
      cTable := aTables[ 1 ]

      cQuery := " select "
      cQuery += "   a.rdb$field_name "
      cQuery += " from "
      cQuery += "   rdb$index_segments a, "
      cQuery += "   rdb$relation_constraints b "
      cQuery += " where "
      cQuery += "   a.rdb$index_name = b.rdb$index_name and "
      cQuery += "   b.rdb$constraint_type = 'PRIMARY KEY' and "
      cQuery += "   b.rdb$relation_name = " + DataToSql( cTable )
      cQuery += " order by "
      cQuery += "   b.rdb$relation_name, "
      cQuery += "   a.rdb$field_position "

      qry := FBQuery( db, RemoveSpaces( cQuery ), dialect )

      IF HB_ISARRAY( qry )
         DO WHILE FBFetch( qry ) == 0
            AAdd( aKeys, RTrim( FBGetData( qry, 1 ) ) )
         ENDDO
         FBFree( qry )
      ENDIF
   ENDIF

   RETURN aKeys

   
METHOD GetServerInfo() CLASS Fb5class
   LOCAL oQuery, cVersion := ""

   oQuery := ::Query("SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') AS FB_VER FROM rdb$database")
   
   IF oQuery != NIL
      IF !oQuery:Eof()
         cVersion := oQuery:FieldGet( 1 )
      ENDIF
      oQuery:Destroy()
   ENDIF

   RETURN AllTrim( cVersion )
   

STATIC FUNCTION DataToSql( xField )

   SWITCH ValType( xField )
   CASE "C"
   CASE "M"
      RETURN "'" + StrTran( xField, "'", "''" ) + "'"
   CASE "D"
      IF Empty( xField ); RETURN "NULL"; ENDIF
      RETURN "'" + StrZero( Year( xField ), 4 ) + "-" + StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + "'"
   CASE "N"
      RETURN Str( xField )
   CASE "L"
      RETURN iif( xField, "TRUE", "FALSE" )
   ENDSWITCH

   RETURN "NULL"

STATIC FUNCTION StructConvert( aStru, db, dialect )

   LOCAL aNew := {}
   LOCAL cField
   LOCAL nType
   LOCAL cType
   LOCAL nSize
   LOCAL nDec
   LOCAL cTable
   LOCAL cDomain
   LOCAL i
   LOCAL qry
   LOCAL cQuery
   LOCAL aDomains := {}
   LOCAL nVal

   LOCAL xTables := ""
   LOCAL xFields := ""

   FOR i := 1 TO Len( aStru )
      xtables += DataToSql( aStru[ i ][ 5 ] )
      xfields += DataToSql( aStru[ i ][ 1 ] )

      IF i != Len( aStru )
         xtables += ","
         xfields += ","
      ENDIF
   NEXT
  
   cQuery := "select rdb$relation_name, rdb$field_name, rdb$field_source "
   cQuery += "  from rdb$relation_fields "
   cQuery += " where rdb$field_name not like 'RDB$%' "
   cQuery += "   and rdb$relation_name in (" + xtables + ")"
   cQuery += "   and rdb$field_name in (" + xfields + ")"

   qry := FBQuery( db, RemoveSpaces( cQuery ), dialect )

   IF HB_ISARRAY( qry )

      DO WHILE FBFetch( qry ) == 0
         AAdd( aDomains, { ;
            iif( FBGetData( qry, 1 ) == NIL, "", FBGetData( qry, 1 ) ), ;
            iif( FBGetData( qry, 2 ) == NIL, "", FBGetData( qry, 2 ) ), ;
            iif( FBGetData( qry, 3 ) == NIL, "", FBGetData( qry, 3 ) ) } )
      ENDDO

      FBFree( qry )

      FOR i := 1 TO Len( aStru )
         cField  := RTrim( aStru[ i ][ 7 ] )
         nType   := aStru[ i ][ 2 ]
         nSize   := aStru[ i ][ 3 ]
         nDec    := aStru[ i ][ 4 ] * -1
         cTable  := RTrim( aStru[ i ][ 5 ] )

         nVal := AScan( aDomains, {| x | RTrim( x[ 1 ] ) == cTable .AND. RTrim( x[ 2 ] ) == cField } )

         IF nVal != 0
            cDomain := aDomains[ nVal, 3 ]
         ELSE
            cDomain := ""
         ENDIF

         SWITCH nType
         CASE IB_SQL_BOOLEAN
            cType := "L"; nSize := 1; nDec := 0; EXIT

         CASE IB_SQL_TEXT
         CASE IB_SQL_VARYING
            cType := "C"; EXIT

         CASE IB_SQL_SHORT
            IF "BOOL" $ cDomain
               cType := "L"; nSize := 1; nDec := 0
            ELSE
               cType := "N"; nSize := 5
            ENDIF
            EXIT

         CASE IB_SQL_LONG
         CASE IB_SQL_INT64
            cType := "N"; nSize := 9; EXIT

         CASE IB_SQL_FLOAT
         CASE IB_SQL_DOUBLE
            cType := "N"; nSize := 15; EXIT

         CASE IB_SQL_TIMESTAMP
            cType := "T"; nSize := 8; EXIT

         CASE IB_SQL_TYPE_DATE
            cType := "D"; nSize := 8; EXIT

         CASE IB_SQL_TYPE_TIME
            cType := "C"; nSize := 8; EXIT

         CASE IB_SQL_BLOB
            cType := "M"; nSize := 10; EXIT

         OTHERWISE
            cType := "C"; nDec := 0
         ENDSWITCH

         AAdd( aNew, { cField, cType, nSize, nDec, cTable, cDomain } )
      NEXT
   ENDIF

   RETURN aNew

STATIC FUNCTION RemoveSpaces( cQuery )

   DO WHILE At( "  ", cQuery ) != 0
      cQuery := StrTran( cQuery, "  ", " " )
   ENDDO

   RETURN cQuery
   
