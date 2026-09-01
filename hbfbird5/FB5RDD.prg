// +--------------------------------------------------------------------
// +    Programa  : fb5rdd.prg
// +    Sistema   : RDD Nativo para Firebird 5 (Com Otimizações SQLRDD)
// +    Linguagem : Harbour
// +--------------------------------------------------------------------

#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"
//#include "rddinfo.ch"  
#include "dbinfo.ch"   

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
// +    Funções de Gerenciamento de Conexão e Transação (Otimizadas)[cite: 17]
// +--------------------------------------------------------------------

FUNCTION DBFB5CONNECTION( cServer, cUser, cPassword, nDialect, cCharSet )
   LOCAL db
   
   hb_default( @nDialect, 3 )
   hb_default( @cCharSet, "UTF8" ) // Pode deixar aqui para uso futuro

   // CORREÇÃO: Removido o cCharSet da chamada até que o firebird5.c seja atualizado
   db := FBConnect( cServer, cUser, cPassword )
   
   IF HB_ISNUMERIC( db )
      Alert( "Erro ao conectar Firebird via RDD (Cód): " + hb_ntos( db ) )
      RETURN 0
   ENDIF

   AAdd( s_aConnections, { db, nDialect } )
   RETURN Len( s_aConnections )
   
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
         FBClose( db ) 
         s_aConnections[ nConn ] := NIL
      ENDIF
   ENDIF
   RETURN SUCCESS

FUNCTION DBFB5COMMIT( nConn )
   LOCAL db := s_aConnections[ nConn ][ 1 ]
   // Agora aponta para a C-API recém criada
   RETURN FBCommitTransaction( db )

FUNCTION DBFB5ROLLBACK( nConn )
   LOCAL db := s_aConnections[ nConn ][ 1 ]
   // Agora aponta para a C-API recém criada
   RETURN FBRollbackTransaction( db )
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
      IF nWA == 0; nWA := Select(); ENDIF
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

STATIC FUNCTION FB5_INIT( nRDD ); USRRDD_RDDDATA( nRDD ); RETURN SUCCESS
STATIC FUNCTION FB5_NEW( pWA ); USRRDD_AREADATA( pWA, Array( AREA_LEN ) ); RETURN SUCCESS

STATIC FUNCTION FB5_ADDFIELD( nWA, aField )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData != NIL
      IF aWAData[ AREA_STRUCT ] == NIL; aWAData[ AREA_STRUCT ] := {}; ENDIF
      AAdd( aWAData[ AREA_STRUCT ], AClone( aField ) )
   ENDIF
   RETURN UR_SUPER_ADDFIELD( nWA, aField )

STATIC FUNCTION FB5_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db, dialect, qry, oError, qryMeta
   LOCAL i, nCols, aStru, cTableName, aField
   LOCAL cName, nType, nSize, nDec, cType
   LOCAL aLocalPrecision := {}
   LOCAL nPosMeta
   LOCAL cFldName, xPrec, xLen

   // 1. Resgata a conexão e o dialeto guardados no array interno
   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db      := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 1 ]
      dialect := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 2 ]
   ELSEIF Len( s_aConnections ) > 0
      db      := s_aConnections[ Len( s_aConnections ) ][ 1 ]
      dialect := s_aConnections[ Len( s_aConnections ) ][ 2 ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "Nenhuma conexao Firebird ativa."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] )

   // 2. Consulta direta aos Metadados para obter a precisão exata dos campos
   qryMeta := FBQuery( db, "SELECT TRIM(A.RDB$FIELD_NAME), B.RDB$FIELD_PRECISION, B.RDB$CHARACTER_LENGTH FROM RDB$RELATION_FIELDS A JOIN RDB$FIELDS B ON A.RDB$FIELD_SOURCE = B.RDB$FIELD_NAME WHERE TRIM(A.RDB$RELATION_NAME) = '" + Upper( cTableName ) + "'", dialect )
   
   IF HB_ISARRAY( qryMeta )
      WHILE FBFetch( qryMeta ) == 0
         
         // Captura os retornos de forma segura
         cFldName := FBGetData( qryMeta, 1 )
         xPrec    := FBGetData( qryMeta, 2 )
         xLen     := FBGetData( qryMeta, 3 )
         
         // Trata possíveis valores NIL (NULL do banco) antes de converter para evitar o erro BASE/1098
         cFldName := iif( cFldName == NIL, "", Upper( AllTrim( cFldName ) ) )
         xPrec    := iif( xPrec == NIL, 0, Val( xPrec ) )
         xLen     := iif( xLen == NIL, 0, Val( xLen ) )
         
         AAdd( aLocalPrecision, { cFldName, xPrec, xLen } )
         
      ENDDO
      FBFree( qryMeta )
   ENDIF

   // 3. Executa a Query principal que vai alimentar a área de trabalho do RDD
   qry := FBQuery( db, "SELECT * FROM " + cTableName, dialect )
   IF HB_ISNUMERIC( qry )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "Falha ao ler estrutura da tabela."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   // 4. Prepara as informações da Área de Trabalho
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

   // 5. Mapeia os tipos de dados nativos do C-API para os tipos do Harbour
   FOR i := 1 TO nCols
      cName := Upper( AllTrim( aStru[ i ][ 1 ] ) )
      nType := aStru[ i ][ 2 ]
      nSize := aStru[ i ][ 3 ]
      nDec  := aStru[ i ][ 4 ] * -1

      // Ajusta tamanho real com base nos metadados do Firebird obtidos lá em cima
      nPosMeta := AScan( aLocalPrecision, {|x| x[1] == cName } )
      IF nPosMeta > 0
         IF aLocalPrecision[ nPosMeta, 2 ] > 0 // Numeric Precision
            nSize := aLocalPrecision[ nPosMeta, 2 ]
         ELSEIF aLocalPrecision[ nPosMeta, 3 ] > 0 // Varchar/Char length
            nSize := aLocalPrecision[ nPosMeta, 3 ]
         ENDIF
      ENDIF

      // Conversão do tipo interno do C para o DBF virtual
      SWITCH nType
         CASE 527
            cType := HB_FT_LOGICAL
            nSize := 1
            nDec := 0
            EXIT
         CASE 452
         CASE 448
            cType := HB_FT_STRING
            EXIT
         CASE 500
            cType := HB_FT_INTEGER
            EXIT
         CASE 496
         CASE 580
            cType := HB_FT_LONG
            EXIT
         CASE 482
         CASE 480
            cType := HB_FT_DOUBLE
            EXIT
         CASE 510
         CASE 570
            cType := HB_FT_DATE
            nSize := 8
            nDec := 0
            EXIT
         CASE 520
            cType := HB_FT_MEMO
            nSize := 10
            nDec := 0
            EXIT
         OTHERWISE
            cType := HB_FT_STRING
            nDec := 0
      ENDSWITCH

      // Registra o campo no Harbour
      aField := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ] := cName
      aField[ UR_FI_TYPE ] := cType
      aField[ UR_FI_LEN ]  := nSize
      aField[ UR_FI_DEC ]  := nDec
      
      AAdd( aWAData[ AREA_FIELDS ], cName )
      AAdd( aWAData[ AREA_TYPES ],  cType )
      UR_SUPER_ADDFIELD( nWA, aField )
   NEXT

   // 6. Traz a primeira linha para cache
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
   LOCAL qry := aWAData[ AREA_QUERY ] //, db := aWAData[ AREA_CONN ][ 1 ]
   LOCAL aRow, i, nCols, xVal, cType

   IF aWAData[ AREA_FETCHED_EOF ]; RETURN .F.; ENDIF

   // TODO: Melhoria Futura 3 - Descer o processamento de linha (Loop/Conversões)
   // inteiramente para uma função em C: SR_FBLINEPROCESSED5(qry, @aRow)[cite: 17]
   IF FBFetch( qry ) == 0
      nCols := qry[ 4 ]
      aRow  := Array( nCols )
      
      FOR i := 1 TO nCols
         xVal  := FBGetData( qry, i )
         cType := aWAData[ AREA_TYPES ][ i ]

         IF xVal == NIL
            DO CASE
               CASE cType == HB_FT_STRING .OR. cType == HB_FT_MEMO; xVal := ""
               CASE cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER; xVal := 0
               CASE cType == HB_FT_LOGICAL; xVal := .F.
               CASE cType == HB_FT_DATE; xVal := CToD("")
            ENDCASE
         ELSE
            IF cType == HB_FT_LOGICAL
               xVal := ( Val( xVal ) == 1 .OR. Upper( AllTrim( xVal ) ) == "T" .OR. xVal == .T. )
            //ELSEIF cType == HB_FT_DATE
               //xVal := hb_SToD( Left( xVal, 4 ) + SubStr( xVal, 5, 2 ) + SubStr( xVal, 7, 2 ) )
            ELSEIF cType == HB_FT_DATE
               xVal := hb_SToD( Left( xVal, 4 ) + SubStr( xVal, 6, 2 ) + SubStr( xVal, 9, 2 ) )   
               
            ELSEIF cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER
               xVal := Val( xVal )
            ENDIF
         ENDIF
         aRow[ i ] := xVal
      NEXT
      AAdd( aWAData[ AREA_CACHE ], aRow )
      RETURN .T.
   ENDIF
   
   aWAData[ AREA_FETCHED_EOF ] := .T.
   RETURN .F.

STATIC FUNCTION FB5_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_QUERY ] )
      FBFree( aWAData[ AREA_QUERY ] )
      aWAData[ AREA_QUERY ] := NIL
   ENDIF
   aWAData[ AREA_CACHE ]  := {}; aWAData[ AREA_ROWBUF ] := NIL
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
   LOCAL aWAData := USRRDD_AREADATA( nWA ), nNewRec
   IF !Empty( aWAData[ AREA_ROWBUF ] ); FB5_FLUSH( nWA ); ENDIF

   nNewRec := aWAData[ AREA_RECNO ] + nRecords
   WHILE nNewRec > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      FB5_FETCH_NEXT( nWA )
   ENDDO

   IF Len( aWAData[ AREA_CACHE ] ) == 0
      aWAData[ AREA_BOF ] := .T.; aWAData[ AREA_EOF ] := .T.
   ELSEIF nNewRec > Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := Len( aWAData[ AREA_CACHE ] ) + 1
      aWAData[ AREA_EOF ] := .T.; aWAData[ AREA_BOF ] := .F.
   ELSEIF nNewRec < 1
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ] := .T.; aWAData[ AREA_EOF ] := .F.
   ELSE
      aWAData[ AREA_RECNO ] := nNewRec
      aWAData[ AREA_BOF ] := .F.; aWAData[ AREA_EOF ] := .F.
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_GOTOP( nWA ); RETURN FB5_GOTO( nWA, 1 )
STATIC FUNCTION FB5_GOBOTTOM( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   WHILE !aWAData[ AREA_FETCHED_EOF ]; FB5_FETCH_NEXT( nWA ); ENDDO
   RETURN FB5_GOTO( nWA, Len( aWAData[ AREA_CACHE ] ) )

STATIC FUNCTION FB5_GOTOID( nWA, nRecord ); RETURN FB5_GOTO( nWA, nRecord )
STATIC FUNCTION FB5_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] ); FB5_FLUSH( nWA ); ENDIF
   WHILE nRecord > Len( aWAData[ AREA_CACHE ] ) .AND. !aWAData[ AREA_FETCHED_EOF ]
      FB5_FETCH_NEXT( nWA )
   ENDDO
   IF nRecord >= 1 .AND. nRecord <= Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := nRecord
      aWAData[ AREA_EOF ] := .F.; aWAData[ AREA_BOF ] := .F.
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecords := Len( aWAData[ AREA_CACHE ] )
   RETURN SUCCESS

STATIC FUNCTION FB5_BOF( nWA, lBof ); lBof := USRRDD_AREADATA( nWA )[ AREA_BOF ]; RETURN SUCCESS
STATIC FUNCTION FB5_EOF( nWA, lEof ); lEof := USRRDD_AREADATA( nWA )[ AREA_EOF ]; RETURN SUCCESS
STATIC FUNCTION FB5_RECID( nWA, nRecNo ); nRecNo := USRRDD_AREADATA( nWA )[ AREA_RECNO ]; RETURN SUCCESS

STATIC FUNCTION FB5_APPEND( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   HB_SYMBOL_UNUSED( nRecords )
   aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_APPEND ] := .T.; aWAData[ AREA_EOF ] := .T.
   RETURN SUCCESS

STATIC FUNCTION FB5_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL cSql, cFields, cValues, cWhere, i, nPosPK, oError, qryIns

   IF !Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_APPEND ]
         cFields := ""; cValues := ""
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_ROWBUF ][ i ] != NIL
               IF !( cFields == "" )
                  cFields += ", "; cValues += ", "
               ENDIF
               cFields += aWAData[ AREA_FIELDS ][ i ]
               cValues += FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ] )
            ENDIF
         NEXT
         
         // Melhoria 4: Uso do RETURNING para auto-incrementos nativos[cite: 17]
         cSql := "INSERT INTO " + aWAData[ AREA_TABLE ] + " (" + cFields + ") VALUES (" + cValues + ")"
         IF !Empty( aWAData[ AREA_PK ] )
            cSql += " RETURNING " + aWAData[ AREA_PK ][ 1 ]
         ENDIF
         
         // Se tiver RETURNING, executa como Query para capturar o ID, senão como Execute normal
         IF "RETURNING" $ cSql
             qryIns := FBQuery( db, cSql, dialect )
             IF HB_ISARRAY( qryIns )
                IF FBFetch( qryIns ) == 0
                   nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ 1 ] )
                   aWAData[ AREA_ROWBUF ][ nPosPK ] := Val( FBGetData( qryIns, 1 ) )
                ENDIF
                FBFree( qryIns )
             ENDIF
         ELSE
             FBExecute( db, cSql, dialect )
         ENDIF
      ELSE
         IF Empty( aWAData[ AREA_PK ] )
            oError := ErrorNew(); oError:Description := "FB5RDD: UPDATE abortado sem Primary Key."
            UR_SUPER_ERROR( nWA, oError ); RETURN FAILURE
         ENDIF
         
         cSql := "UPDATE " + aWAData[ AREA_TABLE ] + " SET "
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_ROWBUF ][ i ] != NIL
               IF i > 1; cSql += ", "; ENDIF
               cSql += aWAData[ AREA_FIELDS ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ] )
            ENDIF
         NEXT
         
         cWhere := ""
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               IF i > 1; cWhere += " AND "; ENDIF
               cWhere += aWAData[ AREA_PK ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
            ENDIF
         NEXT
         cSql += " WHERE " + cWhere
         FBExecute( db, cSql, dialect )
      ENDIF

      IF aWAData[ AREA_APPEND ]
         AAdd( aWAData[ AREA_CACHE ], AClone( aWAData[ AREA_ROWBUF ] ) )
         aWAData[ AREA_APPEND ] := .F.; aWAData[ AREA_RECNO ]  := Len( aWAData[ AREA_CACHE ] )
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
   LOCAL cSql, cWhere := "", i, nPosPK, oError //, nRes

   IF Empty( aWAData[ AREA_PK ] )
      oError := ErrorNew(); oError:Description := "FB5RDD: DELETE abortado sem Primary Key."
      UR_SUPER_ERROR( nWA, oError ); RETURN FAILURE
   ENDIF

   IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      FOR i := 1 TO Len( aWAData[ AREA_PK ] )
         nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
         IF nPosPK > 0
            IF i > 1; cWhere += " AND "; ENDIF
            cWhere += aWAData[ AREA_PK ][ i ] + " = " + FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ] )
         ENDIF
      NEXT
      
      cSql := "DELETE FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
      FBExecute( db, cSql, dialect )
      
      ADel( aWAData[ AREA_CACHE ], aWAData[ AREA_RECNO ] )
      ASize( aWAData[ AREA_CACHE ], Len( aWAData[ AREA_CACHE ] ) - 1 )
      IF aWAData[ AREA_RECNO ] > Len( aWAData[ AREA_CACHE ] ); aWAData[ AREA_EOF ] := .T.; ENDIF
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_ValToSql( xField )
   SWITCH ValType( xField )
   CASE "C"; CASE "M"; RETURN "'" + StrTran( xField, "'", "''" ) + "'"
   CASE "D"
      IF Empty( xField ); RETURN "NULL"; ENDIF
      RETURN "'" + StrZero( Year( xField ), 4 ) + "-" + StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + "'"
   CASE "N"; RETURN Str( xField )
   CASE "L"; RETURN iif( xField, "TRUE", "FALSE" )
   ENDSWITCH
   RETURN "NULL"
   
STATIC FUNCTION FB5_RDDINFO( nIndex, cargo )
   LOCAL xRet := NIL
   DO CASE
      CASE nIndex == RDDI_TABLEEXT; xRet := ".fdb" 
      CASE nIndex == RDDI_MEMOEXT; xRet := "" 
      CASE nIndex == RDDI_ORDBAGEXT; xRet := "" 
      OTHERWISE; xRet := UR_SUPER_RDDINFO( nIndex, cargo )
   ENDCASE
RETURN xRet

STATIC FUNCTION FB5_INFO( nWA, nIndex, cargo )
   LOCAL xRet := NIL
   DO CASE
      CASE nIndex == DBI_ISDBF; xRet := .F.
      CASE nIndex == DBI_CANPUTREC; xRet := .T.
      OTHERWISE; xRet := UR_SUPER_INFO( nWA, nIndex, cargo )
   ENDCASE
RETURN xRet   

STATIC FUNCTION FB5_CREATE( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db, dialect, cSql, n //, nRes oError,
   LOCAL cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] ), aStruct := aWAData[ AREA_STRUCT ] 
   LOCAL mFldNm, mFldType, mFldLen, mFldDec

   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 1 ]
      dialect := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 2 ]
   ELSEIF Len( s_aConnections ) > 0
      db := s_aConnections[ Len( s_aConnections ) ][ 1 ]
      dialect := s_aConnections[ Len( s_aConnections ) ][ 2 ]
   ENDIF

   cSql := "CREATE TABLE " + cTableName + " ("
   FOR n := 1 TO Len( aStruct )
      mFldNm   := aStruct[ n, UR_FI_NAME ]
      mFldType := aStruct[ n, UR_FI_TYPE ] 
      mFldLen  := aStruct[ n, UR_FI_LEN ]
      mFldDec  := aStruct[ n, UR_FI_DEC ]

      IF n > 1; cSql += ", "; ENDIF
      cSql += AllTrim( mFldNm ) + " "

      DO CASE
         CASE mFldType == "+" .OR. mFldNm == "SR_RECNO"
            cSql += "INTEGER GENERATED ALWAYS AS IDENTITY UNIQUE"
         CASE mFldType == HB_FT_STRING .OR. mFldType == "C"
            cSql += "VARCHAR(" + LTrim( Str( mFldLen ) ) + ")"
         CASE mFldType == HB_FT_DATE .OR. mFldType == "D"
            cSql += "TIMESTAMP"
         CASE mFldType == HB_FT_LONG .OR. mFldType == HB_FT_INTEGER .OR. mFldType == "N"
            IF mFldDec > 0
               cSql += "DECIMAL(" + LTrim( Str( mFldLen ) ) + "," + LTrim( Str( mFldDec ) ) + ")"
            ELSE
               IF mFldLen <= 4; cSql += "SMALLINT"
               ELSEIF mFldLen <= 9; cSql += "INTEGER"
               ELSE; cSql += "BIGINT"; ENDIF
            ENDIF
         CASE mFldType == HB_FT_LOGICAL .OR. mFldType == "L"
            cSql += "SMALLINT DEFAULT 0 NOT NULL"
         CASE mFldType == HB_FT_MEMO .OR. mFldType == "M"
            cSql += "BLOB SUB_TYPE TEXT"
         CASE mFldType == HB_FT_BLOB .OR. mFldType == "G"
            cSql += "BLOB SUB_TYPE 0"
         OTHERWISE
            cSql += "VARCHAR(255)"
      ENDCASE
   NEXT
   cSql += ")"
   FBExecute( db, cSql, dialect )
   RETURN SUCCESS

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
   aMyFunc[ UR_RDDINFO ]  := ( @FB5_RDDINFO() )
   aMyFunc[ UR_INFO ]     := ( @FB5_INFO() )
   aMyFunc[ UR_CREATE ]   := ( @FB5_CREATE() )

   RETURN USRRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID, cSuperRDD, aMyFunc )

INIT PROC FB5_INIT_REGISTER()
   rddRegister( "FB5RDD", RDT_FULL )
   RETURN