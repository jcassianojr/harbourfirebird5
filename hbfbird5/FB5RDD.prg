// +--------------------------------------------------------------------
// +    Programa  : fb5rdd.prg
// +    Sistema   : RDD Nativo para Firebird 5 (Com Otimiza��es SQLRDD)
// +    Linguagem : Harbour
// +--------------------------------------------------------------------

#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"
#include "dbinfo.ch"   
#include "firebird5.ch"

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
#define AREA_TYPES        14
#define AREA_SQLTYPES     15
#define AREA_SQLSUBTYPES  16
#define AREA_DIRTY        17
#define AREA_LEN          17

ANNOUNCE FB5RDD

STATIC s_aConnections := {}
THREAD STATIC t_lLoadBlobs := .F.
THREAD STATIC t_lLoadMemos := .F.

// +--------------------------------------------------------------------
// +    Fun��es de Gerenciamento de Conex�o e Transa��o (Otimizadas)[cite: 17]
// +--------------------------------------------------------------------

FUNCTION DBFB5CONNECTION( cServer, cUser, cPassword, nDialect, cCharSet )
   LOCAL db
   
   hb_default( @nDialect, 3 )
   hb_default( @cCharSet, "UTF8" )

   db := FBConnect( cServer, cUser, cPassword, cCharSet )
   
   IF HB_ISNUMERIC( db )
      Alert( "Erro ao conectar Firebird via RDD (C�d): " + hb_ntos( db ) )
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

//FUNCTION DBFB5COMMIT( nConn )
//   LOCAL db := s_aConnections[ nConn ][ 1 ]
   // Agora aponta para a C-API rec�m criada
//   RETURN FBCommitTransaction( db )

//FUNCTION DBFB5ROLLBACK( nConn )
//   LOCAL db := s_aConnections[ nConn ][ 1 ]
   // Agora aponta para a C-API rec�m criada
//   RETURN FBRollbackTransaction( db )
 
 FUNCTION DBFB5COMMIT( nConn )
   // Como o RDD atualmente opera em modo "Auto-Commit" nativo da API C,
   // opera��es de commit expl�cito n�o t�m efeito sobre transa��es de RDD padr�o.
   // Se integrar com TFBQuery futuramente, o ponteiro da transa��o deve ser passado aqui.
   HB_SYMBOL_UNUSED( nConn )
   RETURN SUCCESS

FUNCTION DBFB5ROLLBACK( nConn )
   HB_SYMBOL_UNUSED( nConn )
   RETURN SUCCESS  
   
// +--------------------------------------------------------------------
// +    Configura��o de Chave Prim�ria
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
// +    M�todos Internos da RDD
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
   LOCAL db, dialect, qry, oError, qryMeta, qryPk
   LOCAL i, nCols, aStru, cTableName, aField, nFetch
   LOCAL cName, nType, nSize, nDec, cType, nSubType
   LOCAL aLocalPrecision := {}
   LOCAL nPosMeta
   LOCAL cFldName, xPrec, xLen, xSubType, cPkField, cSqlPkQuery

   // 1. Resgata a conex�o e o dialeto guardados no array interno
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

   // 2. Consulta direta aos Metadados para obter a precis�o exata dos campos
   qryMeta := FBQuery( db, "SELECT TRIM(A.RDB$FIELD_NAME), B.RDB$FIELD_PRECISION, B.RDB$CHARACTER_LENGTH, B.RDB$FIELD_SUB_TYPE FROM RDB$RELATION_FIELDS A JOIN RDB$FIELDS B ON A.RDB$FIELD_SOURCE = B.RDB$FIELD_NAME WHERE TRIM(A.RDB$RELATION_NAME) = '" + Upper( cTableName ) + "'", dialect )
   
   IF !HB_ISARRAY( qryMeta )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "FB5RDD: Falha ao consultar metadados - " + FBError( qryMeta )
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF
   DO WHILE .T.
      nFetch := FBFetch( qryMeta )
      IF nFetch == -1
         EXIT
      ELSEIF nFetch != 0
         FBFree( qryMeta )
         oError := ErrorNew()
         oError:GenCode := EG_OPEN
         oError:Description := "FB5RDD: Falha ao ler metadados - " + FBError( nFetch )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
         cFldName := FBGetData( qryMeta, 1 )
         xPrec    := FBGetData( qryMeta, 2 )
         xLen     := FBGetData( qryMeta, 3 )
         xSubType := FBGetData( qryMeta, 4 ) 
         
         cFldName := iif( cFldName == NIL, "", Upper( AllTrim( cFldName ) ) )
         xPrec    := iif( xPrec == NIL, 0, FB5_ToNumber( xPrec ) )
         xLen     := iif( xLen == NIL, 0, FB5_ToNumber( xLen ) )
         xSubType := iif( xSubType == NIL, 1, FB5_ToNumber( xSubType ) )
         
         AAdd( aLocalPrecision, { cFldName, xPrec, xLen, xSubType } )
   ENDDO
   FBFree( qryMeta )

   // 3. Descobre a Chave Prim�ria obrigatoriamente exigida pelo Keyset Driven
   aWAData[ AREA_PK ] := {}
   qryPk := FBQuery( db, "SELECT TRIM(B.RDB$FIELD_NAME) FROM RDB$RELATION_CONSTRAINTS A " + ;
                         "JOIN RDB$INDEX_SEGMENTS B ON A.RDB$INDEX_NAME = B.RDB$INDEX_NAME " + ;
                         "WHERE A.RDB$CONSTRAINT_TYPE = 'PRIMARY KEY' " + ;
                         "AND TRIM(A.RDB$RELATION_NAME) = '" + Upper( cTableName ) + "' " + ;
                         "ORDER BY B.RDB$FIELD_POSITION", dialect )

   IF !HB_ISARRAY( qryPk )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "FB5RDD: Falha ao consultar a chave primaria - " + FBError( qryPk )
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF
   DO WHILE .T.
      nFetch := FBFetch( qryPk )
      IF nFetch == -1
         EXIT
      ELSEIF nFetch != 0
         FBFree( qryPk )
         oError := ErrorNew()
         oError:GenCode := EG_OPEN
         oError:Description := "FB5RDD: Falha ao ler a chave primaria - " + FBError( nFetch )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
         cPkField := FBGetData( qryPk, 1 )
         IF cPkField != NIL
            AAdd( aWAData[ AREA_PK ], Upper( AllTrim( cPkField ) ) )
         ENDIF
   ENDDO
   FBFree( qryPk )

   IF Empty( aWAData[ AREA_PK ] )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "FB5RDD: A tabela '" + cTableName + "' nao possui Primary Key definida. O Keyset Driven exige PK."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   // 4. Obt�m a estrutura colhendo uma linha vazia ou metadados de colunas via uma query r�pida
   qry := FBQuery( db, "SELECT * FROM " + cTableName + " WHERE 1 = 0", dialect )
   IF HB_ISNUMERIC( qry )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "Falha ao ler estrutura da tabela."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   nCols := qry[ 4 ]
   aStru := qry[ 6 ]
   FBFree( qry ) // Libera a query de estrutura vazia

   // 5. Inicializa os dados da �rea de Trabalho
   aWAData[ AREA_CONN ]        := { db, dialect }
   aWAData[ AREA_TABLE ]       := cTableName
   aWAData[ AREA_RECNO ]       := 0
   aWAData[ AREA_APPEND ]      := .F.
   aWAData[ AREA_FIELDS ]      := {}
   aWAData[ AREA_TYPES ]       := {}
   aWAData[ AREA_SQLTYPES ]    := {}
   aWAData[ AREA_SQLSUBTYPES ] := {}
   aWAData[ AREA_DIRTY ]       := NIL
   aWAData[ AREA_CACHE ]       := {}     // Guarda apenas as PKs carregadas inicialmente
   aWAData[ AREA_QUERY ]       := NIL

   UR_SUPER_SETFIELDEXTENT( nWA, nCols )

   // 6. Mapeia os tipos de dados nativos
   FOR i := 1 TO nCols
      cName := Upper( AllTrim( aStru[ i ][ 1 ] ) )
      nType := aStru[ i ][ 2 ]
      nSize := aStru[ i ][ 3 ]
      nDec  := aStru[ i ][ 4 ] * -1
      nSubType := 0

      nPosMeta := AScan( aLocalPrecision, {|x| x[1] == cName } )
      IF nPosMeta > 0
         nSubType := aLocalPrecision[ nPosMeta, 4 ]
         IF aLocalPrecision[ nPosMeta, 2 ] > 0
            nSize := aLocalPrecision[ nPosMeta, 2 ]
         ELSEIF aLocalPrecision[ nPosMeta, 3 ] > 0
            nSize := aLocalPrecision[ nPosMeta, 3 ]
         ENDIF
      ENDIF

      SWITCH nType
         CASE IB_SQL_BOOLEAN
            cType := HB_FT_LOGICAL; nSize := 1; nDec := 0; EXIT
         CASE IB_SQL_TEXT
         CASE IB_SQL_VARYING
            cType := HB_FT_STRING; EXIT
         CASE IB_SQL_SHORT
            cType := iif( nDec > 0, HB_FT_DOUBLE, HB_FT_INTEGER ); EXIT
         CASE IB_SQL_LONG
         CASE IB_SQL_INT64
            cType := iif( nDec > 0, HB_FT_DOUBLE, HB_FT_LONG ); EXIT
         CASE IB_SQL_FLOAT
         CASE IB_SQL_DOUBLE
         CASE IB_SQL_D_FLOAT
            cType := HB_FT_DOUBLE; EXIT
         CASE IB_SQL_TIMESTAMP
            cType := HB_FT_TIMESTAMP; nSize := 8; nDec := 0; EXIT
         CASE IB_SQL_TYPE_DATE
            cType := HB_FT_DATE; nSize := 8; nDec := 0; EXIT
         CASE IB_SQL_TYPE_TIME
            cType := HB_FT_TIMESTAMP; nSize := 8; nDec := 0; EXIT
         CASE IB_SQL_BLOB
         CASE IB_SQL_QUAD
            cType := HB_FT_MEMO
            IF nSubType == 0
               cType := HB_FT_OLE
            ENDIF
            nSize := 10; nDec := 0; EXIT
         OTHERWISE
            cType := HB_FT_STRING; nDec := 0
      ENDSWITCH

      aField := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ] := cName
      aField[ UR_FI_TYPE ] := cType
      aField[ UR_FI_LEN ]  := nSize
      aField[ UR_FI_DEC ]  := nDec
      
      AAdd( aWAData[ AREA_FIELDS ], cName )
      AAdd( aWAData[ AREA_TYPES ],  cType )
      AAdd( aWAData[ AREA_SQLTYPES ], nType )
      AAdd( aWAData[ AREA_SQLSUBTYPES ], nSubType )
      UR_SUPER_ADDFIELD( nWA, aField )
   NEXT

   // 7. Carrega APENAS as Chaves Prim�rias para o Cache leve de navega��o
   cSqlPkQuery := "SELECT "
   FOR i := 1 TO Len( aWAData[ AREA_PK ] )
      IF i > 1; cSqlPkQuery += ", "; ENDIF
      cSqlPkQuery += aWAData[ AREA_PK ][ i ]
   NEXT
   cSqlPkQuery += " FROM " + cTableName
   qry := FBQuery( db, cSqlPkQuery, dialect )
   
   IF !HB_ISARRAY( qry )
      oError := ErrorNew()
      oError:GenCode := EG_OPEN
      oError:Description := "FB5RDD: Falha ao carregar as chaves da tabela - " + FBError( qry )
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF
   DO WHILE .T.
      nFetch := FBFetch( qry )
      IF nFetch == -1
         EXIT
      ELSEIF nFetch != 0
         FBFree( qry )
         oError := ErrorNew()
         oError:GenCode := EG_OPEN
         oError:Description := "FB5RDD: Falha ao ler as chaves da tabela - " + FBError( nFetch )
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
      aField := Array( Len( aWAData[ AREA_PK ] ) )
      FOR i := 1 TO Len( aField )
         aField[ i ] := FBGetData( qry, i )
      NEXT
      AAdd( aWAData[ AREA_CACHE ], { "FB5_PK", aField } )
   ENDDO
   FBFree( qry )

   // 8. Posiciona o cursor no primeiro registo se houver dados
   IF Len( aWAData[ AREA_CACHE ] ) > 0
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ]   := .F.
      aWAData[ AREA_EOF ]   := .F.
      // Hidrata a primeira linha imediatamente para visualiza��o
      IF !FB5_HydrateRow( nWA, 1 )
         RETURN FAILURE
      ENDIF
   ELSE
      aWAData[ AREA_RECNO ] := 0
      aWAData[ AREA_BOF ]   := .T.
      aWAData[ AREA_EOF ]   := .T.
   ENDIF
   
   RETURN UR_SUPER_OPEN( nWA, aOpenInfo )

STATIC FUNCTION FB5_CLOSE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] ) .AND. FB5_FLUSH( nWA ) != SUCCESS
      RETURN FAILURE
   ENDIF
   IF !Empty( aWAData[ AREA_QUERY ] )
      FBFree( aWAData[ AREA_QUERY ] )
      aWAData[ AREA_QUERY ] := NIL
   ENDIF
   aWAData[ AREA_CACHE ]  := {}
   aWAData[ AREA_ROWBUF ] := NIL
   aWAData[ AREA_DIRTY ]  := NIL
   RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION FB5_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cType   := aWAData[ AREA_TYPES ][ nField ]
   LOCAL xRaw, xCached

   IF !Empty( aWAData[ AREA_ROWBUF ] )
      xRaw := aWAData[ AREA_ROWBUF ][ nField ]
   ELSEIF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      xCached := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ]
      IF !HB_ISARRAY( xCached )
         IF !FB5_HydrateRow( nWA, aWAData[ AREA_RECNO ] ); RETURN FAILURE; ENDIF
      ELSEIF Len( xCached ) == 2 .AND. xCached[ 1 ] == "FB5_PK"
         IF !FB5_HydrateRow( nWA, aWAData[ AREA_RECNO ] ); RETURN FAILURE; ENDIF
      ENDIF
      xRaw := aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nField ]
   ENDIF

   IF cType == HB_FT_MEMO .OR. cType == HB_FT_OLE
      IF HB_ISARRAY( xRaw ) .AND. Len( xRaw ) == 2 .AND. xRaw[ 1 ] == "FB_BLOB"
         IF cType == HB_FT_OLE
            xValue := iif( t_lLoadBlobs, FB5_RealFetchBlob( nWA, xRaw[ 2 ] ), "<IMAGEM/BLOB>" )
         ELSE
            xValue := iif( t_lLoadMemos, FB5_RealFetchBlob( nWA, xRaw[ 2 ] ), "<MEMO>" )
         ENDIF
      ELSE
         xValue := xRaw 
      ENDIF
   ELSE
      xValue := xRaw
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL cType   := aWAData[ AREA_TYPES ][ nField ]
   
   IF cType == HB_FT_OLE
      IF ( ValType( xValue ) == "C" .AND. xValue == "<IMAGEM/BLOB>" ) .OR. .NOT. t_lLoadBlobs
         RETURN SUCCESS
      ENDIF
   ELSEIF cType == HB_FT_MEMO
      IF ( ValType( xValue ) == "C" .AND. xValue == "<MEMO>" ) .OR. .NOT. t_lLoadMemos
         RETURN SUCCESS
      ENDIF
   ENDIF

   IF Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
         IF !FB5_HydrateRow( nWA, aWAData[ AREA_RECNO ] ); RETURN FAILURE; ENDIF
         aWAData[ AREA_ROWBUF ] := AClone( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] )
      ELSE
         aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
      ENDIF
      aWAData[ AREA_DIRTY ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   ENDIF
   aWAData[ AREA_ROWBUF ][ nField ] := xValue
   aWAData[ AREA_DIRTY ][ nField ] := .T.
   RETURN SUCCESS

STATIC FUNCTION FB5_SKIP( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA ), nNewRec
   IF !Empty( aWAData[ AREA_ROWBUF ] ) .AND. FB5_FLUSH( nWA ) != SUCCESS
      RETURN FAILURE
   ENDIF

   nNewRec := aWAData[ AREA_RECNO ] + nRecords

   IF Len( aWAData[ AREA_CACHE ] ) == 0
      aWAData[ AREA_BOF ] := .T.
      aWAData[ AREA_EOF ] := .T.
      RETURN SUCCESS
   ENDIF

   IF nNewRec > Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := Len( aWAData[ AREA_CACHE ] ) + 1
      aWAData[ AREA_EOF ] := .T.
      aWAData[ AREA_BOF ] := .F.
   ELSEIF nNewRec < 1
      aWAData[ AREA_RECNO ] := 1
      aWAData[ AREA_BOF ] := .T.
      aWAData[ AREA_EOF ] := .F.
   ELSE
      aWAData[ AREA_RECNO ] := nNewRec
      aWAData[ AREA_BOF ] := .F.
      aWAData[ AREA_EOF ] := .F.
      // Hidrata a linha para que os dados fiem dispon�veis imediatamente
      IF !FB5_HydrateRow( nWA, aWAData[ AREA_RECNO ] ); RETURN FAILURE; ENDIF
   ENDIF
   
   RETURN SUCCESS

STATIC FUNCTION FB5_GOTOP( nWA ); RETURN FB5_GOTO( nWA, 1 )


STATIC FUNCTION FB5_GOBOTTOM( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] ) .AND. FB5_FLUSH( nWA ) != SUCCESS
      RETURN FAILURE
   ENDIF
   RETURN FB5_GOTO( nWA, Len( aWAData[ AREA_CACHE ] ) )

STATIC FUNCTION FB5_GOTOID( nWA, nRecord ); RETURN FB5_GOTO( nWA, nRecord )


STATIC FUNCTION FB5_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !Empty( aWAData[ AREA_ROWBUF ] ) .AND. FB5_FLUSH( nWA ) != SUCCESS
      RETURN FAILURE
   ENDIF
   
   IF nRecord >= 1 .AND. nRecord <= Len( aWAData[ AREA_CACHE ] )
      aWAData[ AREA_RECNO ] := nRecord
      aWAData[ AREA_EOF ] := .F.
      aWAData[ AREA_BOF ] := .F.
      // Hidrata a linha alvo sob demanda
      IF !FB5_HydrateRow( nWA, nRecord ); RETURN FAILURE; ENDIF
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
   IF !Empty( aWAData[ AREA_ROWBUF ] ) .AND. FB5_FLUSH( nWA ) != SUCCESS
      RETURN FAILURE
   ENDIF
   aWAData[ AREA_ROWBUF ] := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_DIRTY ]  := Array( Len( aWAData[ AREA_FIELDS ] ) )
   aWAData[ AREA_APPEND ] := .T.; aWAData[ AREA_EOF ] := .T.
   RETURN SUCCESS

STATIC FUNCTION FB5_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL cSql, cFields, cValues, cWhere, i, nPosPK, oError, qryIns, nErr, nFetch
   LOCAL lHasChanges, nSqlType, nSqlSubType

   IF !Empty( aWAData[ AREA_ROWBUF ] )
      IF aWAData[ AREA_APPEND ]
         cFields := ""
         cValues := ""
         
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_DIRTY ][ i ] == .T.
               // L�gica segura: s� coloca v�rgula se j� existir algo na string
               IF !( cFields == "" )
                  cFields += ", "
                  cValues += ", "
               ENDIF
               cFields += aWAData[ AREA_FIELDS ][ i ]
               cValues += FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ], ;
                                        aWAData[ AREA_SQLTYPES ][ i ], ;
                                        aWAData[ AREA_SQLSUBTYPES ][ i ] )
            ENDIF
         NEXT
         
         // Use server defaults when APPEND BLANK did not assign any field.
         IF Empty( cFields )
            cSql := "INSERT INTO " + aWAData[ AREA_TABLE ] + " DEFAULT VALUES"
         ELSE
            cSql := "INSERT INTO " + aWAData[ AREA_TABLE ] + " (" + cFields + ") VALUES (" + cValues + ")"
         ENDIF
         
         IF !Empty( aWAData[ AREA_PK ] )
            cSql += " RETURNING "
            FOR i := 1 TO Len( aWAData[ AREA_PK ] )
               IF i > 1; cSql += ", "; ENDIF
               cSql += aWAData[ AREA_PK ][ i ]
            NEXT
         ENDIF
         
         IF "RETURNING" $ cSql
             qryIns := FBQuery( db, cSql, dialect )
             IF HB_ISARRAY( qryIns )
                nFetch := FBFetch( qryIns )
                IF nFetch == 0
                   FOR i := 1 TO Len( aWAData[ AREA_PK ] )
                      nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
                      IF nPosPK > 0
                         aWAData[ AREA_ROWBUF ][ nPosPK ] := FBGetData( qryIns, i )
                      ENDIF
                   NEXT
                ELSE
                   FBFree( qryIns )
                   oError := ErrorNew()
                   oError:GenCode := EG_WRITE
                   oError:Description := "FB5RDD: Falha ao obter a chave gerada - " + FBError( nFetch )
                   oError:Operation := cSql
                   UR_SUPER_ERROR( nWA, oError )
                   RETURN FAILURE
                ENDIF
                FBFree( qryIns )
             ELSE
                // Tratamento rigoroso se a Query de inser��o falhar
                oError := ErrorNew()
                oError:GenCode := EG_WRITE
                oError:Description := "FB5RDD: Falha no INSERT (RETURNING) - " + FBError( qryIns )
                oError:Operation := cSql
                UR_SUPER_ERROR( nWA, oError )
                RETURN FAILURE
             ENDIF
         ELSE
             nErr := FBExecute( db, cSql, dialect )
             IF nErr < 0
                // Tratamento rigoroso se a Execu��o de inser��o falhar
                oError := ErrorNew()
                oError:GenCode := EG_WRITE
                oError:Description := "FB5RDD: Falha no INSERT - " + FBError( nErr )
                oError:Operation := cSql
                UR_SUPER_ERROR( nWA, oError )
                RETURN FAILURE
             ENDIF
         ENDIF

      ELSE // In�cio da L�gica de UPDATE

         IF Empty( aWAData[ AREA_PK ] )
            oError := ErrorNew()
            oError:GenCode := EG_WRITE
            oError:Description := "FB5RDD: UPDATE abortado sem Primary Key definida na tabela."
            UR_SUPER_ERROR( nWA, oError )
            RETURN FAILURE
         ENDIF
         
         cSql := "UPDATE " + aWAData[ AREA_TABLE ] + " SET "
         lHasChanges := .F.
         
         FOR i := 1 TO Len( aWAData[ AREA_FIELDS ] )
            IF aWAData[ AREA_DIRTY ][ i ] == .T.
               IF lHasChanges
                  cSql += ", "
               ENDIF
               nSqlType := aWAData[ AREA_SQLTYPES ][ i ]
               nSqlSubType := aWAData[ AREA_SQLSUBTYPES ][ i ]
               cSql += aWAData[ AREA_FIELDS ][ i ] + " = " + ;
                       FB5_ValToSql( aWAData[ AREA_ROWBUF ][ i ], nSqlType, nSqlSubType )
               lHasChanges := .T.
            ENDIF
         NEXT
         
         // Prote��o: Se nenhum campo mudou, n�o h� o que atualizar no banco
         IF !lHasChanges
            aWAData[ AREA_ROWBUF ] := NIL
            aWAData[ AREA_DIRTY ] := NIL
            RETURN SUCCESS
         ENDIF
         
         cWhere := ""
         FOR i := 1 TO Len( aWAData[ AREA_PK ] )
            nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
            IF nPosPK > 0
               IF i > 1
                  cWhere += " AND "
               ENDIF
               // Procura a Chave no Cache (o valor original, caso a PK tenha sido o campo alterado acidentalmente)
               cWhere += aWAData[ AREA_PK ][ i ] + " = " + ;
                         FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ], ;
                                       aWAData[ AREA_SQLTYPES ][ nPosPK ], ;
                                       aWAData[ AREA_SQLSUBTYPES ][ nPosPK ] )
            ENDIF
         NEXT
         
         cSql += " WHERE " + cWhere
         
         nErr := FBExecute( db, cSql, dialect )
         IF nErr < 0
            // Aborta a opera��o em caso de falha (ex: viola��o de Unique Key no Update)
            oError := ErrorNew()
            oError:GenCode := EG_WRITE
            oError:Description := "FB5RDD: Falha no UPDATE - " + FBError( nErr )
            oError:Operation := cSql
            UR_SUPER_ERROR( nWA, oError )
            RETURN FAILURE
         ENDIF
      ENDIF

      // Esta sec��o s� � alcan�ada se a base de dados confirmar a grava��o com sucesso.
      // Atualizamos agora a mem�ria/cache do Harbour.
      IF aWAData[ AREA_APPEND ]
         AAdd( aWAData[ AREA_CACHE ], AClone( aWAData[ AREA_ROWBUF ] ) )
         aWAData[ AREA_APPEND ] := .F.
         aWAData[ AREA_RECNO ]  := Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_EOF ] := .F.
         aWAData[ AREA_BOF ] := .F.
      ELSE
         aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ] ] := AClone( aWAData[ AREA_ROWBUF ] )
      ENDIF
      
      aWAData[ AREA_ROWBUF ] := NIL
      aWAData[ AREA_DIRTY ]  := NIL
   ENDIF
   
   RETURN SUCCESS
   
   STATIC FUNCTION FB5_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL cSql, cWhere := "", i, nPosPK, oError, nErr

   IF Empty( aWAData[ AREA_PK ] )
      oError := ErrorNew()
      oError:GenCode := EG_WRITE 
      oError:Description := "FB5RDD: DELETE abortado sem Primary Key definida na tabela."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   IF aWAData[ AREA_RECNO ] > 0 .AND. aWAData[ AREA_RECNO ] <= Len( aWAData[ AREA_CACHE ] )
      IF !FB5_HydrateRow( nWA, aWAData[ AREA_RECNO ] ); RETURN FAILURE; ENDIF
      FOR i := 1 TO Len( aWAData[ AREA_PK ] )
         nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
         IF nPosPK > 0
            IF i > 1
               cWhere += " AND "
            ENDIF
            cWhere += aWAData[ AREA_PK ][ i ] + " = " + ;
                      FB5_ValToSql( aWAData[ AREA_CACHE ][ aWAData[ AREA_RECNO ], nPosPK ], ;
                                    aWAData[ AREA_SQLTYPES ][ nPosPK ], ;
                                    aWAData[ AREA_SQLSUBTYPES ][ nPosPK ] )
         ENDIF
      NEXT
      
      cSql := "DELETE FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
      
      nErr := FBExecute( db, cSql, dialect )
      IF nErr < 0
         // Impede que o RDD elimine do ecr� um registo que falhou na base de dados (ex: restri��o relacional)
         oError := ErrorNew()
         oError:GenCode := EG_WRITE
         oError:Description := "FB5RDD: Falha no DELETE - " + FBError( nErr )
         oError:Operation := cSql
         UR_SUPER_ERROR( nWA, oError )
         RETURN FAILURE
      ENDIF
      
      // Elimina��o confirmada no Firebird, podemos remover do Cache do Harbour
      ADel( aWAData[ AREA_CACHE ], aWAData[ AREA_RECNO ] )
      ASize( aWAData[ AREA_CACHE ], Len( aWAData[ AREA_CACHE ] ) - 1 )
      aWAData[ AREA_ROWBUF ] := NIL
      aWAData[ AREA_DIRTY ] := NIL
      aWAData[ AREA_APPEND ] := .F.
      
      IF aWAData[ AREA_RECNO ] > Len( aWAData[ AREA_CACHE ] )
         aWAData[ AREA_EOF ] := .T.
      ENDIF
   ENDIF
   
   RETURN SUCCESS
   
   

STATIC FUNCTION FB5_ValToSql( xField, nSqlType, nSqlSubType )
   LOCAL nSeconds, nMillis, cTime

   hb_default( @nSqlType, 0 )
   hb_default( @nSqlSubType, 0 )

   SWITCH ValType( xField )
   CASE "C"
   CASE "M"
      IF nSqlType == IB_SQL_BLOB
         RETURN "CAST(X'" + hb_StrToHex( xField ) + "' AS BLOB SUB_TYPE " + ;
                AllTrim( Str( nSqlSubType ) ) + ")"
      ENDIF
      RETURN "'" + StrTran( xField, "'", "''" ) + "'"
   CASE "D"
      IF Empty( xField ); RETURN "NULL"; ENDIF
      RETURN "DATE '" + StrZero( Year( xField ), 4 ) + "-" + ;
             StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + "'"
   CASE "N"; RETURN hb_ntos( xField )
   CASE "L"; RETURN iif( xField, "TRUE", "FALSE" )
   CASE "T"
      IF Empty( xField ) .AND. nSqlType != IB_SQL_TYPE_TIME
         RETURN "NULL"
      ENDIF
      nSeconds := Int( hb_Sec( xField ) )
      nMillis  := Min( 999, Int( ( hb_Sec( xField ) - nSeconds ) * 1000 + 0.5 ) )
      cTime := StrZero( hb_Hour( xField ), 2 ) + ":" + ;
               StrZero( hb_Minute( xField ), 2 ) + ":" + ;
               StrZero( nSeconds, 2 ) + "." + StrZero( nMillis, 3 )
      IF nSqlType == IB_SQL_TYPE_TIME
         RETURN "TIME '" + cTime + "'"
      ELSEIF nSqlType == IB_SQL_TIMESTAMP
         RETURN "TIMESTAMP '" + StrZero( Year( xField ), 4 ) + "-" + ;
                StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + ;
                " " + cTime + "'"
      ENDIF
      RETURN "'" + StrZero( Year( xField ), 4 ) + "-" + ;
             StrZero( Month( xField ), 2 ) + "-" + StrZero( Day( xField ), 2 ) + ;
             " " + cTime + "'"
   ENDSWITCH
   RETURN "NULL"

STATIC FUNCTION FB5_ToNumber( xValue )
   IF HB_ISNUMERIC( xValue )
      RETURN xValue
   ELSEIF ValType( xValue ) == "C"
      RETURN Val( xValue )
   ENDIF
   RETURN 0
   
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
   LOCAL db, dialect, cSql, n, nErr, oError
   LOCAL cTableName := AllTrim( aOpenInfo[ UR_OI_NAME ] ), aStruct := aWAData[ AREA_STRUCT ] 
   LOCAL mFldNm, mFldType, mFldLen, mFldDec

   IF !Empty( aOpenInfo[ UR_OI_CONNECT ] ) .AND. aOpenInfo[ UR_OI_CONNECT ] <= Len( s_aConnections )
      db := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 1 ]
      dialect := s_aConnections[ aOpenInfo[ UR_OI_CONNECT ] ][ 2 ]
   ELSEIF Len( s_aConnections ) > 0
      db := s_aConnections[ Len( s_aConnections ) ][ 1 ]
      dialect := s_aConnections[ Len( s_aConnections ) ][ 2 ]
   ENDIF

   IF Empty( db )
      oError := ErrorNew()
      oError:GenCode := EG_CREATE
      oError:Description := "FB5RDD: Nenhuma conexao Firebird ativa para criar a tabela."
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
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
            cSql += "DATE"
         CASE mFldType == HB_FT_TIMESTAMP .OR. mFldType == "T"
            cSql += "TIMESTAMP"
         CASE mFldType == HB_FT_LONG .OR. mFldType == HB_FT_INTEGER .OR. mFldType == "N"
            IF mFldDec > 0
               cSql += "DECIMAL(" + LTrim( Str( mFldLen ) ) + "," + LTrim( Str( mFldDec ) ) + ")"
            ELSE
               IF mFldLen <= 4; cSql += "SMALLINT"
               ELSEIF mFldLen <= 9; cSql += "INTEGER"
               ELSE; cSql += "BIGINT"; ENDIF
            ENDIF
         CASE mFldType == HB_FT_DOUBLE .OR. mFldType == "F"
            IF mFldDec > 0
               cSql += "DECIMAL(" + LTrim( Str( mFldLen ) ) + "," + LTrim( Str( mFldDec ) ) + ")"
            ELSE
               cSql += "DOUBLE PRECISION"
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
   nErr := FBExecute( db, cSql, dialect )
   IF nErr < 0
      oError := ErrorNew()
      oError:GenCode := EG_CREATE
      oError:Description := "FB5RDD: Falha ao criar a tabela - " + FBError( nErr )
      oError:Operation := cSql
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF
   RETURN SUCCESS

STATIC FUNCTION FB5_HydrateRow( nWA, nRecNo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL dialect := aWAData[ AREA_CONN ][ 2 ]
   LOCAL xCache  := aWAData[ AREA_CACHE ][ nRecNo ]
   LOCAL aPk, cWhere := "", cSql, qryRow, nCols, aRow, i, xVal, cType, nPosPK, nFetch, oError

   IF !HB_ISARRAY( xCache )
      RETURN .T.
   ENDIF
   IF Len( xCache ) != 2 .OR. xCache[ 1 ] != "FB5_PK"
      RETURN .T.
   ENDIF

   aPk := xCache[ 2 ]
   FOR i := 1 TO Len( aWAData[ AREA_PK ] )
      nPosPK := AScan( aWAData[ AREA_FIELDS ], aWAData[ AREA_PK ][ i ] )
      IF nPosPK > 0
         IF !Empty( cWhere ); cWhere += " AND "; ENDIF
         cWhere += aWAData[ AREA_PK ][ i ] + " = " + ;
                   FB5_ValToSql( aPk[ i ], aWAData[ AREA_SQLTYPES ][ nPosPK ], ;
                                 aWAData[ AREA_SQLSUBTYPES ][ nPosPK ] )
      ENDIF
   NEXT

   cSql := "SELECT * FROM " + aWAData[ AREA_TABLE ] + " WHERE " + cWhere
   qryRow := FBQuery( db, cSql, dialect )

   IF HB_ISARRAY( qryRow )
      nFetch := FBFetch( qryRow )
      IF nFetch == 0
         nCols := qryRow[ 4 ]
         aRow  := Array( nCols )
         
         FOR i := 1 TO nCols
            xVal  := FBGetData( qryRow, i )
            cType := aWAData[ AREA_TYPES ][ i ]

            IF xVal == NIL
               DO CASE
                  CASE cType == HB_FT_STRING .OR. cType == HB_FT_MEMO; xVal := ""
                  CASE cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER; xVal := 0
                  CASE cType == HB_FT_LOGICAL; xVal := .F.
                  CASE cType == HB_FT_DATE; xVal := CToD("")
                  CASE cType == HB_FT_TIMESTAMP; xVal := hb_DateTime( 0, 0, 0 )
               ENDCASE
            ELSE
               IF cType == HB_FT_LOGICAL
                  xVal := strlogicrdd( xVal, .F. )
              ELSEIF cType == HB_FT_DATE
                  xVal := StrDateRdd( xVal )
               ELSEIF cType == HB_FT_TIMESTAMP
                  xVal := UniversalDateTime( xVal ) // <-- INJE��O: Conversor Universal de Data e Hora
                  
               ELSEIF cType == HB_FT_DOUBLE .OR. cType == HB_FT_LONG .OR. cType == HB_FT_INTEGER
                  xVal := FB5_ToNumber( xVal )
               ELSEIF cType == HB_FT_MEMO .OR. cType == HB_FT_OLE
                  IF ValType( xVal ) == "C" .AND. Len( xVal ) == 8
                     xVal := { "FB_BLOB", xVal }
                  ENDIF   
               ENDIF
            ENDIF
            aRow[ i ] := xVal
         NEXT
         
         // Substitui a PK pura no cache pelo array completo da linha hidratada
         aWAData[ AREA_CACHE ][ nRecNo ] := aRow
         FBFree( qryRow )
         RETURN .T.
      ENDIF
      FBFree( qryRow )
      oError := ErrorNew()
      oError:GenCode := EG_READ
      oError:Description := "FB5RDD: Falha ao buscar registro pela chave primaria."
      oError:Operation := cSql
      IF nFetch != -1
         oError:Description += " " + FBError( nFetch )
      ENDIF
   ELSE
      oError := ErrorNew()
      oError:GenCode := EG_READ
      oError:Description := "FB5RDD: Falha ao consultar registro pela chave primaria - " + FBError( qryRow )
      oError:Operation := cSql
   ENDIF
   UR_SUPER_ERROR( nWA, oError )
   RETURN .F.

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
   
STATIC FUNCTION FB5_RealFetchBlob( nWA, cBlobId )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL db      := aWAData[ AREA_CONN ][ 1 ]
   LOCAL aChunks, cData := "", i
   
   aChunks := FBGetBlob( db, cBlobId )
   IF HB_ISARRAY( aChunks )
      FOR i := 1 TO Len( aChunks )
         cData += aChunks[ i ]
      NEXT
   ENDIF
   RETURN cData

PROCEDURE FB5_SetLoadBlobs( lLoad ); t_lLoadBlobs := lLoad; RETURN
PROCEDURE FB5_SetLoadMemos( lLoad ); t_lLoadMemos := lLoad; RETURN

FUNCTION FB5_PegarMemo( cCampo )
   LOCAL cTxt, lAnt := t_lLoadMemos
   FB5_SetLoadMemos( .T. )
   cTxt := FieldGet( FieldPos( cCampo ) )
   FB5_SetLoadMemos( lAnt )
   RETURN iif( Empty( cTxt ) .OR. cTxt == "<MEMO>", "", cTxt )
   
FUNCTION FB5_GravarMemo( cCampo, cTxt )
   LOCAL lAnt := t_lLoadMemos
   IF ValType( cTxt ) != "C"; RETURN .F.; ENDIF
   FB5_SetLoadMemos( .T. )
   FieldPut( FieldPos( cCampo ), cTxt )
   FB5_SetLoadMemos( lAnt )
   RETURN .T. 

FUNCTION FB5_PegarBlobJpg( cCampo, cDir )
   LOCAL cBin, lAnt := t_lLoadBlobs
   FB5_SetLoadBlobs( .T. )
   cBin := FieldGet( FieldPos( cCampo ) )
   FB5_SetLoadBlobs( lAnt )
   IF Empty( cBin ) .OR. cBin == "<IMAGEM/BLOB>"; RETURN .F.; ENDIF
   RETURN hb_memowrit( cDir, cBin )
   
FUNCTION FB5_GravarBlobJpg( cCampo, cDir )
   LOCAL cBin, lAnt := t_lLoadBlobs
   IF !hb_FileExists( cDir ); RETURN .F.; ENDIF
   cBin := hb_memoread( cDir )
   FB5_SetLoadBlobs( .T. )
   FieldPut( FieldPos( cCampo ), cBin )
   FB5_SetLoadBlobs( lAnt )
   RETURN .T.   
   
 // +--------------------------------------------------------------------
// +    Static Function strlogicrdd( cVAL, lDEFAULT )
// +    Conversor universal de retornos textuais/num�ricos para Booleano
// +--------------------------------------------------------------------
STATIC FUNCTION strlogicrdd( cVAL, lDEFAULT )

   IF ValType( lDEFAULT ) <> "L"
      lDEFAULT := .F.
   ENDIF
   
   IF ValType( cVAL ) != "C"
      cVAL := hb_ValToStr( cVAL )
   ENDIF

   SWITCH Upper( AllTrim( cVal ) )
   CASE ".T."
   CASE "TRUE"
   CASE "YES"
   CASE "SIM"
   CASE "ON"
   CASE "Y"
   CASE "1"
   CASE "T"
   CASE "S"
      RETURN .T.
   CASE ".F."
   CASE "FALSE"
   CASE "NO"
   CASE "NAO"
   CASE "OFF"
   CASE "N"
   CASE "0"
   CASE "F"
   CASE "<NULL>"
   CASE "NULL"
   CASE "NUL"
   CASE "NIL"
      RETURN .F.
   ENDSWITCH

   RETURN lDEFAULT

// +--------------------------------------------------------------------
// +    Static Function StrDateRdd( xData )
// +    Conversor inteligente de datas universal para o RDD ADO
// +--------------------------------------------------------------------
STATIC FUNCTION StrDateRdd( xData )
LOCAL dRet := CToD( "" )
   LOCAL cTemp, aParts 
   LOCAL i, nMes, cMes, cAno, cDia, nDia, nAno, cMesStr
   LOCAL cCleanData
   
   // Matrizes independentes pela clareza e velocidade nativa do AScan
   LOCAL aMonthsEN := { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
   LOCAL aMonthsPT := { "JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ" }

   IF ValType( xData ) == "D"
      RETURN xData
   ENDIF

   IF ValType( xData ) <> "C" .OR. Empty( xData )
      RETURN dRet
   ENDIF
   
   // Limpa uma �nica vez para otimizar os testes
   cCleanData := Upper( AllTrim( xData ) )

   // Barreira imediata contra literais nulos/vazios
   IF cCleanData == "NULL" .OR. cCleanData == "NIL" .OR. cCleanData == "<NULL>" .OR. cCleanData == "NUL" .OR. cCleanData == "/  /" .OR. cCleanData == "-  -"
      RETURN dRet
   ENDIF

   cTemp := AllTrim( xData )

   // -------------------------------------------------------------------------
   // Suporte a Formatos HTTP-date e Logs (Ingl�s e Portugu�s)
   // -------------------------------------------------------------------------
   cTemp := StrTran( cTemp, ",", " " )
   cTemp := StrTran( cTemp, "-", " " )

   DO WHILE "  " $ cTemp
      cTemp := StrTran( cTemp, "  ", " " )
   ENDDO

   aParts := hb_ATokens( AllTrim( cTemp ), " " )

   IF Len( aParts ) >= 4
      FOR i := 1 TO Len( aParts )
         cMesStr := Upper( Left( aParts[ i ], 3 ) )
         
         // 1. Busca primeiro em Ingl�s
         nMes := AScan( aMonthsEN, cMesStr )
         
         // 2. Se n�o encontrar, tenta em Portugu�s
         IF nMes == 0
            nMes := AScan( aMonthsPT, cMesStr )
         ENDIF
         
         // Se encontrou o m�s, processa
         IF nMes > 0
            cMes := StrZero( nMes, 2 )
            
            // Extrai o Dia e o Ano baseado na posi��o do M�s (ANSI C vs RFC)
            IF i == 2 .AND. Len( aParts ) >= 5 // ANSI C asctime
               cDia := StrZero( Val( aParts[ 3 ] ), 2 )
               cAno := aParts[ 5 ]
            ELSEIF i == 3 // RFC 1123 / RFC 850
               cDia := StrZero( Val( aParts[ 2 ] ), 2 )
               cAno := aParts[ 4 ]
               
               IF Len( cAno ) == 2
                  nAno := Val( cAno )
                  cAno := iif( nAno < 50, "20" + cAno, "19" + cAno )
               ENDIF
            ELSE
               LOOP 
            ENDIF
            
            nDia := Val( cDia )
            nAno := Val( cAno )
            
            IF nDia >= 1 .AND. nDia <= 31 .AND. nAno >= 1000 .AND. Len( cAno ) == 4
               dRet := SToD( cAno + cMes + cDia )
               IF !Empty( dRet )
                  RETURN dRet
               ENDIF
            ENDIF
         ENDIF
      NEXT
   ENDIF

   // -------------------------------------------------------------------------
   // Fallback Original para Bancos de Dados (YYYY-MM-DD, DD/MM/YYYY, etc.)
   // -------------------------------------------------------------------------
   cTemp := AllTrim( xData ) // Restaura a string original limpa para o fallback
   cTemp := StrTran( cTemp, "-", "/" ) 
   cTemp := StrTran( cTemp, ".", "/" ) 
   aParts := hb_ATokens( cTemp, "/" ) 

   IF Len( aParts ) == 3
      IF Len( aParts[ 1 ] ) == 4
         cAno := aParts[ 1 ]
         cMes := StrZero( Val( aParts[ 2 ] ), 2 ) 
         cDia := StrZero( Val( aParts[ 3 ] ), 2 )
      ELSE
         cDia := StrZero( Val( aParts[ 1 ] ), 2 ) 
         cMes := StrZero( Val( aParts[ 2 ] ), 2 )
         cAno := aParts[ 3 ]
         IF Len( cAno ) == 2
            nAno := Val( cAno )
            cAno := iif( nAno < 50, "20" + cAno, "19" + cAno ) 
         ENDIF
      ENDIF
      IF cAno + cMes + cDia == "00000000"
         RETURN CToD( "" )
      ENDIF 
      dRet := SToD( cAno + cMes + cDia ) 
      RETURN iif( Empty( dRet ), CToD( "" ), dRet )
   ELSE
      IF Len( cTemp ) == 8
         IF Val( Left( cTemp, 4 ) ) > 1900
            dRet := SToD( cTemp ) 
         ELSE
            dRet := SToD( Right( cTemp, 4 ) + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) ) 
         ENDIF
      ELSEIF Len( cTemp ) == 6
         nAno := Val( Right( cTemp, 2 ) )
         cAno := iif( nAno < 50, "20" + Right( cTemp, 2 ), "19" + Right( cTemp, 2 ) ) 
         dRet := SToD( cAno + SubStr( cTemp, 3, 2 ) + Left( cTemp, 2 ) ) 
      ELSE
         dRet := CToD( xData ) 
      ENDIF
   ENDIF
RETURN dRet


 // +--------------------------------------------------------------------
// +  Fun��o: UniversalDateTime
// +  Objetivo: Tratar datas complexas mantendo e corrigindo o hor�rio
// +  Retorna: Timestamp nativo (T) de alta precis�o
// +--------------------------------------------------------------------
STATIC FUNCTION UniversalDateTime( xData )

   LOCAL cStr, cDataLimpa, aParts, i, dData
   LOCAL cTime := "00:00:00"
   LOCAL nHour := 0, nMin := 0, nSec := 0

   // 1. J� � Data ou Timestamp? Trata a convers�o direta
   IF ValType( xData ) == "T"
      RETURN xData
   ELSEIF ValType( xData ) == "D"
      RETURN hb_DateTime( Year(xData), Month(xData), Day(xData) )
   ENDIF

   // 2. Barreira para nulos ou vari�veis n�o suportadas
   IF ValType( xData ) <> "C" .OR. Empty( xData )
      RETURN hb_DateTime( 0, 0, 0 )
   ENDIF

   // 3. Limpa espa�os e conserta erros como ";" ou tags ISO "T"
   cStr := AllTrim( xData )
   cStr := StrTran( cStr, ";", ":" )
   cStr := StrTran( cStr, "T", " " )

   aParts := hb_ATokens( cStr, " " )
   cDataLimpa := ""

   // 4. Ca�ador de Hor�rios
   FOR i := 1 TO Len( aParts )
      IF ":" $ aParts[i] .AND. Val( StrTran( aParts[i], ":", "" ) ) >= 0
         cTime := aParts[i] // Isola apenas a hora encontrada
      ELSE
         cDataLimpa += aParts[i] + " " // Reconstr�i string base s� da data
      ENDIF
   NEXT

   cDataLimpa := AllTrim( cDataLimpa )
   
   // 5. Utiliza o motor otimizado para extrair o calend�rio v�lido
   dData := StrDaterdd( cDataLimpa )

   // Fallback se a rotina retornar vazio, checa direto via Harbour CToD
   IF Empty( dData ) .AND. !Empty( CToD( cDataLimpa ) )
      dData := CToD( cDataLimpa )
   ENDIF

   IF Empty( dData )
      RETURN hb_DateTime( 0, 0, 0 )
   ENDIF

   // 6. Separa e converte as partes do Hor�rio
   aParts := hb_ATokens( cTime, ":" )
   IF Len( aParts ) >= 1; nHour := Val( aParts[1] ); ENDIF
   IF Len( aParts ) >= 2; nMin  := Val( aParts[2] ); ENDIF
   IF Len( aParts ) >= 3; nSec  := Val( aParts[3] ); ENDIF

   // 7. Retorna o Objeto Timestamp Oficial
   RETURN hb_DateTime( Year( dData ), Month( dData ), Day( dData ), nHour, nMin, nSec ) 
   