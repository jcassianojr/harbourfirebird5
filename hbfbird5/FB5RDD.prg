// +--------------------------------------------------------------------
// +    Programa  : fb5rdd.prg
// +    Sistema   : RDD Nativo para Firebird 5 (Sem Classes)
// +    Linguagem : Harbour
// +--------------------------------------------------------------------

#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"

#define AREA_CONN         1
#define AREA_TABLE        2
#define AREA_PK           3
#define AREA_CACHE        4
#define AREA_RECNO        5
#define AREA_ROWBUF       6
#define AREA_APPEND       7
#define AREA_EOF          8
#define AREA_BOF          9
#define AREA_FIELDS       10
#define AREA_STRUCT       11
#define AREA_QUERY        12
#define AREA_FETCHED_EOF  13
#define AREA_TYPES        14
#define AREA_LEN          14

ANNOUNCE FB5RDD

STATIC s_aConnections := {}

// +--------------------------------------------------------------------
// +    Funções de Gerenciamento de Conexão Firebird 5
// +--------------------------------------------------------------------

FUNCTION DBFB5CONNECTION( cServer, cUser, cPassword, nDialect )
   LOCAL db
   
   hb_default( @nDialect, 3 )

   // Conecta diretamente usando a API C (firebird5.c)
   db := FBConnect( cServer, cUser, cPassword )
   
   IF HB_ISNUMERIC( db )
      Alert( "Erro ao conectar Firebird via RDD (Cód): " + hb_ntos( db ) )
      RETURN 0
   ENDIF

   // Armazena o handle nativo e o dialeto[cite: 11]
   AAdd( s_aConnections, { db, nDialect } )
   
   RETURN Len( s_aConnections )
   
// <--- ADICIONE ESTA FUNÇÃO AQUI PARA RESOLVER O ERRO DE FUNÇÃO DESCONHECIDA --->
FUNCTION DBFB5GETHANDLE( nConn )
   IF nConn > 0 .AND. nConn <= Len( s_aConnections )
      RETURN s_aConnections[ nConn ]
   ENDIF
   RETURN NIL   

FUNCTION DBFB5CLEARCONNECTION( nConn )
   LOCAL db
   IF nConn > 0 .AND. nConn <= Len( s_aConnections )
      db := s_aConnections[ nConn ][ 1 ]
      IF !Empty( db )
         FBClose( db ) // Libera no C
         s_aConnections[ nConn ] := NIL
      ENDIF
   ENDIF
   RETURN SUCCESS

// +--------------------------------------------------------------------
// +    Configuração de Chave Primária
// +--------------------------------------------------------------------

FUNCTION FB5_SETPK( cAlias, cFields )
   LOCAL nWA, aWAData
   
   IF PCount() == 1
      cFields := cAlias
      nWA := Select()
   ELSE
      nWA := Select( cAlias )
      IF nWA == 0
         nWA := Select() 
      ENDIF
   ENDIF
   
   IF nWA > 0
      aWAData := USRRDD_AREADATA( nWA )
      IF aWAData != NIL
         aWAData[ AREA_PK ] := hb_ATokens( StrTran( cFields, " ", "" ), "," )
         RETURN .T.
      ENDIF
   ENDIF
   RETURN .F.

// +--------------------------------------------------------------------
// +    Métodos Internos da RDD
// +--------------------------------------------------------------------

STATIC FUNCTION FB5_INIT( nRDD )
   USRRDD_RDDDATA( nRDD )
   RETURN SUCCESS

STATIC FUNCTION FB5_NEW( pWA )
   USRRDD_AREADATA( pWA, Array( AREA_LEN ) )
   RETURN SUCCESS

STATIC FUNCTION FB5_ADDFIELD( nWA, aField )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF aWAData != NIL
      IF aWAData[ AREA_STRUCT ] == NIL
         aWAData[ AREA_STRUCT ] := {}
      ENDIF
      AAdd( aWAData[ AREA_STRUCT ], AClone( aField ) )
   ENDIF
   RETURN UR_SUPER_ADDFIELD( nWA, aField )

STATIC FUNCTION FB5_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db, dialect, qry, oError
   LOCAL i, nCols, aStru, cTableName, aField
   LOCAL cName, nType, nSize, nDec, cType

   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db      := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 1 ]
      dialect := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 2 ]
   ELSEIF Len( s_aConnections ) > 0
      db      := s_aConnections[ Len( s_aConnections ) ][ 1 ]
      dialect := s_aConnections[ Len( s_aConnections ) ][ 2 ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Nenhuma conexao Firebird ativa."
      oError:FileName    := aOpenInfo[ UR_OI_NAME ]
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] )

   // Prepara a Query Nativa
   qry := FBQuery( db, "SELECT * FROM " + cTableName, dialect )
   
   IF HB_ISNUMERIC( qry )
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:Description := "Falha ao ler estrutura da tabela."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   aWAData[ AREA_CONN ]        := { db, dialect }
   aWAData[ AREA_TABLE ]       := cTableName
   aWAData[ AREA_PK ]          := {}
   aWAData[ AREA_RECNO ]       := 0
   aWAData[ AREA_APPEND ]      := .F.
   aWAData[ AREA_FIELDS ]      := {}
   aWAData[ AREA_TYPES ]       := {}
   aWAData[ AREA_CACHE ]       := {}
   aWAData[ AREA_QUERY ]       := qry
   aWAData[ AREA_FETCHED_EOF ] := .F.

   nCols := qry[ 4 ]
   aStru := qry[ 6 ]
   
   UR_SUPER_SETFIELDEXTENT( nWA, nCols )

   FOR i := 1 TO nCols
      cName := RTrim( aStru[ i ][ 7 ] )
      IF Empty( cName )
         cName := RTrim( aStru[ i ][ 1 ] )
      ENDIF
      
      nType := aStru[ i ][ 2 ]
      nSize := aStru[ i ][ 3 ]
      nDec  := aStru[ i ][ 4 ] * -1

      // Mapeamento nativo dos códigos de tipo do C-API
      SWITCH nType
         CASE 527 // SQL_BOOLEAN
            cType := HB_FT_LOGICAL
            nSize := 1
            nDec := 0
            EXIT
         CASE 452 // SQL_TEXT
         CASE 448 // SQL_VARYING
            cType := HB_FT_STRING
            EXIT
         CASE 500 // SQL_SHORT
            cType := HB_FT_INTEGER
            nSize := 5
            EXIT
         CASE 496 // SQL_LONG
         CASE 580 // SQL_INT64
            cType := HB_FT_LONG
            nSize := 10
            EXIT
         CASE 482 // SQL_FLOAT
         CASE 480 // SQL_DOUBLE
            cType := HB_FT_DOUBLE
            nSize := 18
            EXIT
         CASE 510 // SQL_TIMESTAMP
         CASE 570 // SQL_TYPE_DATE
            cType := HB_FT_DATE
            nSize := 8
            nDec := 0
            EXIT
         CASE 520 // SQL_BLOB
            cType := HB_FT_MEMO
            nSize := 10
            nDec := 0
            EXIT
         OTHERWISE
            cType := HB_FT_STRING
            nDec := 0
      ENDSWITCH

      aField := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ] := cName
      aField[ UR_FI_TYPE ] := cType
      aField[ UR_FI_LEN ]  := nSize
      aField[ UR_FI_DEC ]  := nDec
      
      AAdd( aWAData[ AREA_FIELDS ], cName )
      AAdd( aWAData[ AREA_TYPES ],  cType )
      UR_SUPER_ADDFIELD( nWA, aField )
   NEXT

   // Traz a primeira linha para cache[cite: 11]
   FB5_FETCH_NEXT( nWA )
   
   IF Len( aWAData[ AREA_CACHE ] ) > 0
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
   ELSE
      aWAData[ AREA_RECNO ] := 0
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .T.
   ENDIF

   RETURN UR_SUPER_OPEN( nWA, aOpenInfo )

STATIC FUNCTION FB5_FETCH_NEXT( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL qry := aWAData[ AREA_QUERY ]
   LOCAL db  := aWAData[ AREA_CONN ][ 1 ]
   LOCAL aRow, i, nCols, xVal, cType, aBlob, cBlob

   IF aWAData[ AREA_FETCHED_EOF ]
      RETURN .F.
   ENDIF

   IF FBFetch( qry ) == 0
      nCols := qry[ 4 ]
      aRow  := Array( nCols )
      
      FOR i := 1 TO nCols
         xVal  := FBGetData( qry, i )
         cType := aWAData[ AREA_TYPES ][ i ]

         // Tratamento de conversões (BLOBs, Booleano, etc.)
         IF xVal == NIL
            DO CASE
               CASE cType == HB_FT_STRING .OR. cType == HB_FT_MEMO; xVal := ""
               CASE cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER; xVal := 0
               CASE cType == HB_FT_LOGICAL; xVal := .F.
               CASE cType == HB_FT_DATE; xVal := CToD("")
            ENDCASE
         ELSE
            IF cType == HB_FT_MEMO
               aBlob := FBGetBlob( db, xVal )
               cBlob := ""
               FOR EACH xVal IN aBlob
                  cBlob += xVal
               NEXT
               xVal := cBlob
            ELSEIF cType == HB_FT_LOGICAL
               xVal := ( Val( xVal ) == 1 .OR. Upper( AllTrim( xVal ) ) == "T" .OR. xVal == .T. )
            ELSEIF cType == HB_FT_DATE
               xVal := hb_SToD( Left( xVal, 4 ) + SubStr( xVal, 5, 2 ) + SubStr( xVal, 7, 2 ) )
            ELSEIF cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER
               xVal := Val( xVal )
            ENDIF
         ENDIF
         aRow[ i ] := xVal
      NEXT
      
      AAdd( aWAData[ AREA_CACHE ], aRow )
      RETURN .T.
   ELSE
      aWAData[ AREA_FETCHED_EOF ] := .T.
      RETURN .F.
   ENDIF
   RETURN .T.

STATIC FUNCTION FB5_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_QUERY ] )
      FBFree( aWAData[ AREA_QUERY ] )
      aWAData[ AREA_QUERY ] := NIL
   ENDIF
   aWAData[ AREA_CACHE ]  := {}
   aWAData[ AREA_ROWBUF ] := NIL
   RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION FB5_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ AREA_APPEND ] .AND. !Empty( aWAData[ AREA_ROWBUF ] )
      xValue := aWAData[ AREA_ROWBUF ][ nField ]
   ELSEIF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      xValue := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nField ]
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_ROWBUF ] := AClone( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] )
      ELSE
         aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
      ENDIF
   ENDIF
   aWAData[ AREA_ROWBUF ][ nField ] := xValue
   RETURN SUCCESS

STATIC FUNCTION FB5_SKIP( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL nNewRec
   
   IF !Empty( aWAData[ AREA_ROWBUF ] )
      FB5_FLUSH( nWA )
   ENDIF

   nNewRec := aWAData[ AREA_RECNO ] + nRecords
   
   WHILE nNewRec > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      FB5_FETCH_NEXT( nWA )
   ENDDO

   IF Len( aWAData[ AREA_CACHE ] ) == 0
      aWAData[ AREA_BOF ] := .T.
      aWAData[ AREA_EOF ] := .T.
   ELSEIF nNewRec > Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := Len( aWAData[ AREA_CACHE ] ) + 1
      aWAData[ AREA_EOF ]   := .T.
      aWAData[ AREA_BOF ]   := .F.
   ELSEIF nNewRec < 1
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .F.
   ELSE
      aWAData[ AREA_RECNO ] := nNewRec
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_GOTOP( nWA )
   RETURN FB5_GOTO( nWA, 1 )

STATIC FUNCTION FB5_GOBOTTOM( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   WHILE !aWAData[ AREA_FETCHED_EOF ]
      FB5_FETCH_NEXT( nWA )
   ENDDO
   RETURN FB5_GOTO( nWA, Len( aWAData[ AREA_CACHE ] ) )

STATIC FUNCTION FB5_GOTOID( nWA, nRecord )
   RETURN FB5_GOTO( nWA, nRecord )

STATIC FUNCTION FB5_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] )
      FB5_FLUSH( nWA )
   ENDIF
   
   WHILE nRecord > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      FB5_FETCH_NEXT( nWA )
   ENDDO
   
   IF nRecord >= 1 .AND. nRecord <= Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := nRecord
      aWAData[ AREA_EOF ] := .F.
      aWAData[ AREA_BOF ] := .F.
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecords := Len( aWAData[ AREA_CACHE ] )
   RETURN SUCCESS

STATIC FUNCTION FB5_BOF( nWA, lBof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lBof := aWAData[ AREA_BOF ]
   RETURN SUCCESS

STATIC FUNCTION FB5_EOF( nWA, lEof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lEof := aWAData[ AREA_EOF ]
   RETURN SUCCESS

STATIC FUNCTION FB5_RECID( nWA, nRecNo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecNo := aWAData[ AREA_RECNO ]
   RETURN SUCCESS

STATIC FUNCTION FB5_APPEND( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   HB_SYMBOL_UNUSED( nRecords )
   aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_APPEND ] := .T.
   aWAData[ AREA_EOF ]    := .T.
   RETURN SUCCESS

STATIC FUNCTION FB5_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL cSql, cFields, cValues, cWhere, i, nPosPK, oError, nRes

   IF !Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_APPEND ]
         cFields := ""
         cValues := ""
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_ROWBUF ][ i ] != NIL
               IF !( cFields == "" )
                  cFields += ", "
                  cValues += ", "
               ENDIF
               cFields += aWAData[ AREA_FIELDS ][ i ]
               cValues += FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ] )
            ENDIF
         NEXT
         cSql := "INSERT INTO " + aWAData[ AREA_TABLE ] + " (" + cFields + ") VALUES (" + cValues + ")"
      ELSE
         IF Empty( aWAData[ AREA_PK ] )
            oError := ErrorNew()
            oError:GenCode := EG_DATATYPE
            oError:Description := "FB5RDD: REPLACE abortado. Defina a Primary Key (FB5_SETPK) primeiro."
            UR_SUPER_ERROR( nWA, oError )
            RETURN FAILURE
         ENDIF
         
         cSql := "UPDATE " + aWAData[ AREA_TABLE ] + " SET "
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_ROWBUF ][ i ] != NIL
               IF i > 1
                  cSql += ", "
               ENDIF
               cSql += aWAData[ AREA_FIELDS ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ] )
            ENDIF
         NEXT
         
         cWhere := ""
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               IF i > 1
                  cWhere += " AND "
               ENDIF
               cWhere += aWAData[ AREA_PK ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
            ENDIF
         NEXT
         cSql += " WHERE " + cWhere
      ENDIF

      nRes := FBExecute( db, cSql, dialect )
      IF nRes < 0
         oError := ErrorNew()
         oError:GenCode := EG_DATATYPE
         oError:Description := "Erro SQL ao gravar: " + hb_ntos( nRes )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF

      IF aWAData[ AREA_APPEND ]
         AAdd( aWAData[ AREA_CACHE ], AClone( aWAData[ AREA_ROWBUF ] ) )
         aWAData[ AREA_APPEND ] := .F.
         aWAData[ AREA_RECNO ]  := Len( aWAData[ AREA_CACHE ] )
      ELSE
         aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] := AClone( aWAData[ AREA_ROWBUF ] )
      ENDIF
      
      aWAData[ AREA_ROWBUF ] := NIL
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL cSql, cWhere := "", i, nPosPK, oError, nRes

   IF Empty( aWAData[ AREA_PK ] )
      oError := ErrorNew()
      oError:GenCode := EG_DATATYPE
      oError:Description := "FB5RDD: DELETE abortado. Defina a Primary Key (FB5_SETPK) primeiro."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      FOR i := 1 TO Len( aWAData[ AREA_PK ] )
         nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
         IF nPosPK > 0
            IF i > 1
               cWhere += " AND "
            ENDIF
            cWhere += aWAData[ AREA_PK ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
         ENDIF
      NEXT
      
      cSql := "DELETE FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
      nRes := FBExecute( db, cSql, dialect )
      
      IF nRes < 0
         oError := ErrorNew()
         oError:GenCode := EG_DATATYPE
         oError:Description := "Erro SQL ao deletar: " + hb_ntos( nRes )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
      
      ADel( aWAData[ AREA_CACHE ], aWAData[ AREA_RECNO ] )
      ASize( aWAData[ AREA_CACHE ], Len( aWAData[ AREA_CACHE ] ) - 1 )
      
      IF aWAData[ AREA_RECNO ] > Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_EOF ] := .T.
      ENDIF
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_ValToSql( xField )
   SWITCH ValType( xField )
   CASE "C"
   CASE "M"
      RETURN "'" + StrTran( xField, "'", "''" ) + "'"
   CASE "D"
      IF Empty( xField )
         RETURN "NULL"
      ENDIF
      RETURN "'" + StrZero( Year( xField ), 4 ) + "-" + StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + "'"
   CASE "N"
      RETURN Str( xField )
   CASE "L"
      RETURN iif( xField, "TRUE", "FALSE" )
   ENDSWITCH
   RETURN "NULL"

// +--------------------------------------------------------------------
// +    Tabela de Roteamento de Metodos 
// +--------------------------------------------------------------------

FUNCTION FB5RDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID )
   LOCAL cSuperRDD := NIL
   LOCAL aMyFunc[ UR_METHODCOUNT ]

   aMyFunc[ UR_INIT ]     := ( @FB5_INIT() )
   aMyFunc[ UR_NEW ]      := ( @FB5_NEW() )
   aMyFunc[ UR_ADDFIELD ] := ( @FB5_ADDFIELD() ) 
   aMyFunc[ UR_OPEN ]     := ( @FB5_OPEN() )
   aMyFunc[ UR_CLOSE ]    := ( @FB5_CLOSE() )
   aMyFunc[ UR_GETVALUE ] := ( @FB5_GETVALUE() )
   aMyFunc[ UR_PUTVALUE ] := ( @FB5_PUTVALUE() )
   aMyFunc[ UR_SKIP ]     := ( @FB5_SKIP() )
   aMyFunc[ UR_GOTO ]     := ( @FB5_GOTO() )
   aMyFunc[ UR_GOTOID ]   := ( @FB5_GOTOID() )
   aMyFunc[ UR_GOTOP ]    := ( @FB5_GOTOP() )
   aMyFunc[ UR_GOBOTTOM ] := ( @FB5_GOBOTTOM() )
   aMyFunc[ UR_RECCOUNT ] := ( @FB5_RECCOUNT() )
   aMyFunc[ UR_RECID ]    := ( @FB5_RECID() )
   aMyFunc[ UR_BOF ]      := ( @FB5_BOF() )
   aMyFunc[ UR_EOF ]      := ( @FB5_EOF() )
   aMyFunc[ UR_FLUSH ]    := ( @FB5_FLUSH() )
   aMyFunc[ UR_APPEND ]   := ( @FB5_APPEND() )
   aMyFunc[ UR_DELETE ]   := ( @FB5_DELETE() )

   RETURN USRRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID, cSuperRDD, aMyFunc )

INIT PROC FB5_INIT_REGISTER()
   rddRegister( "FB5RDD", RDT_FULL )
   RETURN