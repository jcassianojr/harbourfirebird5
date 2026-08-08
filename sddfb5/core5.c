/*
 * Firebird SQL Database Driver (for Firebird 5)
 * Adapted for Harbour Project (sddfb / 32-bit & 64-bit support)
 */

#if ( defined( __BORLANDC__ ) && __BORLANDC__ >= 0x582 )
   #define __STDINT_H
#endif

#include "hbrddsql.h"

#include "hbapiitm.h"
#include "hbvm.h"
#include "hbdate.h"

#include "ibase.h"
#include "time.h"

typedef struct
{
   isc_db_handle hDb;
} SDDCONN;

typedef struct
{
   isc_tr_handle    hTrans;
   isc_stmt_handle  hStmt;
   XSQLDA ISC_FAR * pSqlda;
} SDDDATA;

static HB_ERRCODE fbConnect( SQLDDCONNECTION * pConnection, PHB_ITEM pItem );
static HB_ERRCODE fbDisconnect( SQLDDCONNECTION * pConnection );
static HB_ERRCODE fbExecute( SQLDDCONNECTION * pConnection, PHB_ITEM pItem );
static HB_ERRCODE fbOpen( SQLBASEAREAP pArea );
static HB_ERRCODE fbClose( SQLBASEAREAP pArea );
static HB_ERRCODE fbGoTo( SQLBASEAREAP pArea, HB_ULONG ulRecNo );


static SDDNODE s_firebirddd = {
   NULL,
   "FIREBIRD",
   ( SDDFUNC_CONNECT ) fbConnect,
   ( SDDFUNC_DISCONNECT ) fbDisconnect,
   ( SDDFUNC_EXECUTE ) fbExecute,
   ( SDDFUNC_OPEN ) fbOpen,
   ( SDDFUNC_CLOSE ) fbClose,
   ( SDDFUNC_GOTO ) fbGoTo,
   ( SDDFUNC_GETVALUE ) NULL,
   ( SDDFUNC_GETVARLEN ) NULL
};


static void hb_firebirddd_init( void * cargo )
{
   HB_SYMBOL_UNUSED( cargo );

   if( ! hb_sddRegister( &s_firebirddd ) )
      hb_errInternal( HB_EI_RDDINVALID, NULL, NULL, NULL );
}

HB_FUNC( HB_SDDFB_REGISTER )
{
   hb_firebirddd_init( NULL );
}

/* force SQLBASE linking */
HB_FUNC_TRANSLATE( SDDFB, SQLBASE )

HB_INIT_SYMBOLS_BEGIN( firebirddd__InitSymbols )
{
   "SDDFB", { HB_FS_PUBLIC | HB_FS_LOCAL }, { HB_FUNCNAME( SDDFB ) }, NULL
},
HB_INIT_SYMBOLS_END( firebirddd__InitSymbols )

HB_CALL_ON_STARTUP_BEGIN( _hb_firebirddd_init_ )
hb_vmAtInit( hb_firebirddd_init, NULL );
HB_CALL_ON_STARTUP_END( _hb_firebirddd_init_ )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup firebirddd__InitSymbols
   #pragma startup _hb_firebirddd_init_
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY  HB_DATASEG_FUNC( firebirddd__InitSymbols ) \
   HB_DATASEG_FUNC( _hb_firebirddd_init_ )
   #include "hbiniseg.h"
#endif


/* --- */
static HB_USHORT hb_errRT_FirebirdDD( HB_ERRCODE errGenCode, HB_ERRCODE errSubCode, const char * szDescription, const char * szOperation, HB_ERRCODE errOsCode )
{
   HB_USHORT uiAction;
   PHB_ITEM  pError;

   pError   = hb_errRT_New( ES_ERROR, "SDDFB", errGenCode, errSubCode, szDescription, szOperation, errOsCode, EF_NONE );
   uiAction = hb_errLaunch( pError );
   hb_itemRelease( pError );
   return uiAction;
}

/* --- SDD METHODS --- */
static HB_ERRCODE fbConnect( SQLDDCONNECTION * pConnection, PHB_ITEM pItem )
{
   ISC_STATUS_ARRAY status;
   isc_db_handle    hDb = ( isc_db_handle ) 0;
   char parambuf[ 520 ];
   int  i;
   unsigned int ul;

   i = 0;
   parambuf[ i++ ] = isc_dpb_version1;

   parambuf[ i++ ] = isc_dpb_user_name;
   ul = ( unsigned int ) hb_arrayGetCLen( pItem, 3 );
   if( ul > 255 )
      ul = 255;
   parambuf[ i++ ] = ( char ) ul;
   memcpy( parambuf + i, hb_arrayGetCPtr( pItem, 3 ), ul );
   i += ul;

   parambuf[ i++ ] = isc_dpb_password;
   ul = ( unsigned int ) hb_arrayGetCLen( pItem, 4 );
   if( ul > 255 )
      ul = 255;
   parambuf[ i++ ] = ( char ) ul;
   memcpy( parambuf + i, hb_arrayGetCPtr( pItem, 4 ), ul );
   i += ul;

   if( hb_arrayLen( pItem ) >= 5 && hb_arrayGetCLen( pItem, 5 ) > 0 )
   {
      const char * charset = hb_arrayGetCPtr( pItem, 5 );
      unsigned int chlen = ( unsigned int ) hb_arrayGetCLen( pItem, 5 );
      if( chlen > 255 )
         chlen = 255;
      parambuf[ i++ ] = isc_dpb_lc_ctype;
      parambuf[ i++ ] = ( char ) chlen;
      memcpy( parambuf + i, charset, chlen );
      i += chlen;
   }

   if( isc_attach_database( status, 0, hb_arrayGetCPtr( pItem, 2 ), &hDb, ( short ) i, parambuf ) )
      return HB_FAILURE;

   pConnection->pSDDConn = hb_xgrab( sizeof( SDDCONN ) );
   ( ( SDDCONN * ) pConnection->pSDDConn )->hDb = hDb;

   return HB_SUCCESS;
}


static HB_ERRCODE fbDisconnect( SQLDDCONNECTION * pConnection )
{
   ISC_STATUS_ARRAY status;

   isc_detach_database( status, &( ( SDDCONN * ) pConnection->pSDDConn )->hDb );
   hb_xfree( pConnection->pSDDConn );
   return HB_SUCCESS;
}


static HB_ERRCODE fbExecute( SQLDDCONNECTION * pConnection, PHB_ITEM pItem )
{
   HB_SYMBOL_UNUSED( pConnection );
   HB_SYMBOL_UNUSED( pItem );
   return HB_SUCCESS;
}


static HB_ERRCODE fbOpen( SQLBASEAREAP pArea )
{
   isc_db_handle *  phDb = &( ( SDDCONN * ) pArea->pConnection->pSDDConn )->hDb;
   SDDDATA *        pSDDData;
   ISC_STATUS_ARRAY status;
   isc_tr_handle    hTrans = ( isc_tr_handle ) 0;
   isc_stmt_handle  hStmt  = ( isc_stmt_handle ) 0;
   XSQLDA ISC_FAR * pSqlda;
   XSQLVAR *        pVar;
   PHB_ITEM         pItemEof, pItem = NULL;
   HB_BOOL          bError;
   HB_USHORT        uiFields, uiCount;
   static char      tpb[] = { isc_tpb_version3, isc_tpb_write, isc_tpb_read_committed, isc_tpb_rec_version, isc_tpb_nowait };

   pArea->pSDDData = memset( hb_xgrab( sizeof( SDDDATA ) ), 0, sizeof( SDDDATA ) );
   pSDDData        = ( SDDDATA * ) pArea->pSDDData;

   memset( &status, 0, sizeof( status ) );

   if( isc_start_transaction( status, &hTrans, 1, phDb, sizeof( tpb ), tpb ) )
   {
      hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_START, "Start transaction failed", NULL, ( HB_ERRCODE ) isc_sqlcode( status ) );
      return HB_FAILURE;
   }

   if( isc_dsql_allocate_statement( status, phDb, &hStmt ) )
   {
      hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_STMTALLOC, "Allocate statement failed", NULL, ( HB_ERRCODE ) isc_sqlcode( status ) );
      isc_rollback_transaction( status, &hTrans );
      return HB_FAILURE;
   }

   pSqlda          = ( XSQLDA * ) hb_xgrab( XSQLDA_LENGTH( 1 ) );
   pSqlda->sqln    = 1;
   pSqlda->version = 1;

   if( isc_dsql_prepare( status, &hTrans, &hStmt, 0, pArea->szQuery, SQL_DIALECT_V5, pSqlda ) )
   {
      hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_INVALIDQUERY, "Prepare statement failed", pArea->szQuery, ( HB_ERRCODE ) isc_sqlcode( status ) );
      isc_dsql_free_statement( status, &hStmt, DSQL_drop );
      isc_rollback_transaction( status, &hTrans );
      hb_xfree( pSqlda );
      return HB_FAILURE;
   }

   if( isc_dsql_execute( status, &hTrans, &hStmt, SQL_DIALECT_V5, NULL ) )
   {
      hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_EXECUTE, "Execute statement failed", pArea->szQuery, ( HB_ERRCODE ) isc_sqlcode( status ) );
      isc_dsql_free_statement( status, &hStmt, DSQL_drop );
      isc_rollback_transaction( status, &hTrans );
      hb_xfree( pSqlda );
      return HB_FAILURE;
   }

   if( pSqlda->sqld > pSqlda->sqln )
   {
      uiFields = pSqlda->sqld;
      hb_xfree( pSqlda );
      pSqlda          = ( XSQLDA * ) hb_xgrab( XSQLDA_LENGTH( uiFields ) );
      pSqlda->sqln    = uiFields;
      pSqlda->version = 1;

      if( isc_dsql_describe( status, &hStmt, SQL_DIALECT_V5, pSqlda ) )
      {
         hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_STMTDESCR, "Describe statement failed", NULL, ( HB_ERRCODE ) isc_sqlcode( status ) );
         isc_dsql_free_statement( status, &hStmt, DSQL_drop );
         isc_rollback_transaction( status, &hTrans );
         hb_xfree( pSqlda );
         return HB_FAILURE;
      }
   }

   pSDDData->hTrans = hTrans;
   pSDDData->hStmt  = hStmt;
   pSDDData->pSqlda = pSqlda;

   uiFields = pSqlda->sqld;
   SELF_SETFIELDEXTENT( &pArea->area, uiFields );

   pItemEof = hb_itemArrayNew( uiFields );

   bError = HB_FALSE;
   for( uiCount = 0, pVar = pSqlda->sqlvar; uiCount < uiFields; uiCount++, pVar++ )
   {
      DBFIELDINFO dbFieldInfo;
      int iType;
      char * szOurName = hb_strndup( pVar->sqlname, pVar->sqlname_length );

      memset( &dbFieldInfo, 0, sizeof( dbFieldInfo ) );
      dbFieldInfo.atomName = szOurName;

      iType = pVar->sqltype & ~1;
      switch( iType )
      {
         case SQL_TEXT:
         {
            char * pStr;

            dbFieldInfo.uiType = HB_FT_STRING;
            dbFieldInfo.uiLen  = pVar->sqllen;
            pVar->sqldata = ( char * ) hb_xgrab( sizeof( char ) * pVar->sqllen + 2 );

            pStr  = ( char * ) memset( hb_xgrab( dbFieldInfo.uiLen ), ' ', dbFieldInfo.uiLen );
            pItem = hb_itemPutCL( NULL, pStr, dbFieldInfo.uiLen );
            hb_xfree( pStr );
            break;
         }

         case SQL_VARYING:
         {
            char * pStr;

            dbFieldInfo.uiType = HB_FT_VARLENGTH;
            dbFieldInfo.uiLen  = pVar->sqllen;
            pVar->sqldata = ( char * ) hb_xgrab( sizeof( char ) * pVar->sqllen + 2 );

            pStr  = ( char * ) memset( hb_xgrab( dbFieldInfo.uiLen ), ' ', dbFieldInfo.uiLen );
            pItem = hb_itemPutCL( NULL, pStr, dbFieldInfo.uiLen );
            hb_xfree( pStr );
            break;
         }

         case SQL_BOOLEAN:
            dbFieldInfo.uiType = HB_FT_LOGICAL;
            dbFieldInfo.uiLen  = 1;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( ISC_UCHAR ) );
            pItem              = hb_itemPutL( NULL, HB_FALSE );
            break;

         case SQL_SHORT:
            if( pVar->sqlscale < 0 )
            {
               dbFieldInfo.uiType = HB_FT_LONG;
               dbFieldInfo.uiLen  = 7;
               dbFieldInfo.uiDec  = -pVar->sqlscale;

               pItem = hb_itemPutNDLen( NULL, 0.0, 6 - dbFieldInfo.uiDec, ( int ) dbFieldInfo.uiDec );
            }
            else
            {
               dbFieldInfo.uiType = HB_FT_INTEGER;
               dbFieldInfo.uiLen  = 2;

               pItem = hb_itemPutNILen( NULL, 0, 6 );
            }
            pVar->sqldata = ( char * ) hb_xgrab( sizeof( short ) );
            break;

         case SQL_LONG:
            if( pVar->sqlscale < 0 )
            {
               dbFieldInfo.uiType = HB_FT_LONG;
               dbFieldInfo.uiLen  = 12;
               dbFieldInfo.uiDec  = -pVar->sqlscale;

               pItem = hb_itemPutNDLen( NULL, 0.0, 11 - dbFieldInfo.uiDec, ( int ) dbFieldInfo.uiDec );
            }
            else
            {
               dbFieldInfo.uiType = HB_FT_INTEGER;
               dbFieldInfo.uiLen  = 4;

               pItem = hb_itemPutNLLen( NULL, 0, 11 );
            }
            pVar->sqldata = ( char * ) hb_xgrab( sizeof( long ) );
            break;

         case SQL_INT64:
            if( pVar->sqlscale < 0 )
            {
               dbFieldInfo.uiType = HB_FT_LONG;
               dbFieldInfo.uiLen  = 20;
               dbFieldInfo.uiDec  = -pVar->sqlscale;

               pItem = hb_itemPutNDLen( NULL, 0.0, 19 - dbFieldInfo.uiDec, ( int ) dbFieldInfo.uiDec );
            }
            else
            {
               dbFieldInfo.uiType = HB_FT_LONG;
               dbFieldInfo.uiLen  = 20;

               pItem = hb_itemPutNInt( NULL, 0 );
            }
            pVar->sqldata = ( char * ) hb_xgrab( sizeof( ISC_INT64 ) );
            break;

         case SQL_FLOAT:
            dbFieldInfo.uiType = HB_FT_DOUBLE;
            dbFieldInfo.uiLen  = 8;
            dbFieldInfo.uiDec  = -pVar->sqlscale;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( float ) );

            pItem = hb_itemPutNDLen( NULL, 0.0, 20 - dbFieldInfo.uiDec, dbFieldInfo.uiDec );
            break;

         case SQL_DOUBLE:
            dbFieldInfo.uiType = HB_FT_DOUBLE;
            dbFieldInfo.uiLen  = 8;
            dbFieldInfo.uiDec  = -pVar->sqlscale;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( double ) );

            pItem = hb_itemPutNDLen( NULL, 0.0, 20 - dbFieldInfo.uiDec, dbFieldInfo.uiDec );
            break;

         case SQL_TIMESTAMP:
            dbFieldInfo.uiType = HB_FT_TIMESTAMP;
            dbFieldInfo.uiLen  = 8;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( ISC_TIMESTAMP ) );
            pItem              = hb_itemPutTDT( NULL, 0, 0 );
            break;

         case SQL_TYPE_DATE:
            dbFieldInfo.uiType = HB_FT_DATE;
            dbFieldInfo.uiLen  = 8;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( ISC_DATE ) );
            pItem              = hb_itemPutDS( NULL, NULL );
            break;

         case SQL_TYPE_TIME:
            dbFieldInfo.uiType = HB_FT_TIME;
            dbFieldInfo.uiLen  = 8;
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( ISC_TIME ) );
            pItem              = hb_itemPutTDT( NULL, 0, 0 );
            break;

         default:  /* other fields as binary string */
            pVar->sqldata      = ( char * ) hb_xgrab( sizeof( char * ) * pVar->sqllen );
            pItem              = hb_itemNew( NULL );
            bError             = HB_TRUE;
            break;
      }

      if( pVar->sqltype & 1 )
         pVar->sqlind = ( short * ) hb_xgrab( sizeof( short ) );

      hb_arraySetForward( pItemEof, uiCount + 1, pItem );
      hb_itemRelease( pItem );

      if( ! bError )
         bError = ( SELF_ADDFIELD( &pArea->area, &dbFieldInfo ) == HB_FAILURE );

      hb_xfree( szOurName );

      if( bError )
         break;
   }

   if( bError )
   {
      hb_itemClear( pItemEof );
      hb_itemRelease( pItemEof );
      hb_errRT_FirebirdDD( EG_CORRUPTION, ESQLDD_INVALIDFIELD, "Invalid field type", pArea->szQuery, 0 );
      return HB_FAILURE;
   }

   pArea->ulRecCount = 0;

   pArea->pRow      = ( void ** ) hb_xgrab( SQLDD_ROWSET_INIT * sizeof( void * ) );
   pArea->pRowFlags = ( HB_BYTE * ) hb_xgrab( SQLDD_ROWSET_INIT * sizeof( HB_BYTE ) );
   pArea->ulRecMax  = SQLDD_ROWSET_INIT;

   pArea->pRow[ 0 ]      = pItemEof;
   pArea->pRowFlags[ 0 ] = SQLDD_FLAG_CACHED;

   return HB_SUCCESS;
}


static HB_ERRCODE fbClose( SQLBASEAREAP pArea )
{
   SDDDATA *        pSDDData = ( SDDDATA * ) pArea->pSDDData;
   ISC_STATUS_ARRAY status;

   if( pSDDData )
   {
      if( pSDDData->pSqlda )
      {
         int i;
         for( i = 0; i < pSDDData->pSqlda->sqld; i++ )
         {
            if( pSDDData->pSqlda->sqlvar[ i ].sqldata )
               hb_xfree( pSDDData->pSqlda->sqlvar[ i ].sqldata );
            if( pSDDData->pSqlda->sqlvar[ i ].sqlind )
               hb_xfree( pSDDData->pSqlda->sqlvar[ i ].sqlind );
         }
         hb_xfree( pSDDData->pSqlda );
      }
      if( pSDDData->hStmt )
         isc_dsql_free_statement( status, &pSDDData->hStmt, DSQL_drop );
      if( pSDDData->hTrans )
         isc_rollback_transaction( status, &pSDDData->hTrans );
      hb_xfree( pSDDData );
      pArea->pSDDData = NULL;
   }
   return HB_SUCCESS;
}


static HB_ERRCODE fbGoTo( SQLBASEAREAP pArea, HB_ULONG ulRecNo )
{
   SDDDATA *        pSDDData = ( SDDDATA * ) pArea->pSDDData;
   ISC_STATUS_ARRAY status;
   XSQLVAR *        pVar;
   HB_USHORT        ui;
   ISC_STATUS       lErr;
   short iType;

   while( ulRecNo > pArea->ulRecCount && ! pArea->fFetched )
   {
      isc_stmt_handle * phStmt = &pSDDData->hStmt;
      isc_tr_handle *   phTr   = &pSDDData->hTrans;

      lErr = isc_dsql_fetch( status, phStmt, SQL_DIALECT_V5, pSDDData->pSqlda );

      if( lErr == 0 )
      {
         PHB_ITEM pItem = NULL, pArray;

         pArray = hb_itemArrayNew( pArea->area.uiFieldCount );
         for( ui = 0; ui < pArea->area.uiFieldCount; ui++ )
         {
            LPFIELD pField;
            pVar = pSDDData->pSqlda->sqlvar + ui;

            if( ( pVar->sqltype & 1 ) && ( *pVar->sqlind < 0 ) )
               continue;  /* NIL value */

            pField = pArea->area.lpFields + ui;
            iType  = pVar->sqltype & ~1;
            switch( iType )
            {
               case SQL_TEXT:
                  pItem = hb_itemPutCL( pItem, pVar->sqldata, pVar->sqllen );
                  break;

               case SQL_VARYING:
                  pItem = hb_itemPutCL( pItem, pVar->sqldata + 2, *( short * ) pVar->sqldata );
                  break;

               case SQL_BOOLEAN:
                  pItem = hb_itemPutL( pItem, *( ISC_UCHAR * ) pVar->sqldata ? HB_TRUE : HB_FALSE );
                  break;

               case SQL_SHORT:
                  if( pField->uiDec == 0 )
                     pItem = hb_itemPutNILen( pItem, *( short * ) pVar->sqldata, 6 );
                  else
                     pItem = hb_itemPutNDLen( pItem, hb_numDecConv( *( short * ) pVar->sqldata, ( int ) pField->uiDec ),
                                              6 - pField->uiDec, ( int ) pField->uiDec );
                  break;

               case SQL_LONG:
                  if( pField->uiDec == 0 )
                     pItem = hb_itemPutNLLen( pItem, *( long * ) pVar->sqldata, 11 );
                  else
                     pItem = hb_itemPutNDLen( pItem, hb_numDecConv( *( long * ) pVar->sqldata, ( int ) pField->uiDec ),
                                              11 - pField->uiDec, ( int ) pField->uiDec );
                  break;

               case SQL_INT64:
                  if( pField->uiDec == 0 )
                     pItem = hb_itemPutNInt( pItem, *( ISC_INT64 * ) pVar->sqldata );
                  else
                     pItem = hb_itemPutNDLen( pItem, hb_numDecConv( *( ISC_INT64 * ) pVar->sqldata, ( int ) pField->uiDec ),
                                              20 - pField->uiDec, ( int ) pField->uiDec );
                  break;

               case SQL_FLOAT:
                  pItem = hb_itemPutNDLen( pItem, *( float * ) pVar->sqldata, 20 - pField->uiDec, pField->uiDec );
                  break;

               case SQL_DOUBLE:
                  pItem = hb_itemPutNDLen( pItem, *( double * ) pVar->sqldata, 20 - pField->uiDec, pField->uiDec );
                  break;

               case SQL_TIMESTAMP:
               {
                  struct tm times;
                  isc_decode_timestamp( ( ISC_TIMESTAMP * ) pVar->sqldata, &times );
                  {
                     long lJulian, lMilliSec;
                     time_t rawtime;
                     struct tm tinfo;
                     
                     memset( &tinfo, 0, sizeof( tinfo ) );
                     tinfo.tm_year = times.tm_year;
                     tinfo.tm_mon  = times.tm_mon;
                     tinfo.tm_mday = times.tm_mday;
                     tinfo.tm_hour = times.tm_hour;
                     tinfo.tm_min  = times.tm_min;
                     tinfo.tm_sec  = times.tm_sec;
                     rawtime = mktime( &tinfo );
                     
                     lMilliSec = hb_timeEncode( times.tm_hour, times.tm_min, times.tm_sec, 
                                                ( int ) ( ( ( ISC_TIMESTAMP * ) pVar->sqldata )->timestamp_time % 10000 ) / 10 );
                     lJulian = ( long ) ( rawtime / 86400L ) + 2440588L;
                     
                     pItem = hb_itemPutTDT( pItem, lJulian, lMilliSec );
                  }
                  break;
               }

               case SQL_TYPE_DATE:
               {
                  struct tm times;
                  isc_decode_sql_date( ( ISC_DATE * ) pVar->sqldata, &times );
                  {
                     char date_s[ 15 ];
                     hb_snprintf( date_s, sizeof( date_s ), "%04d%02d%02d",
                                  times.tm_year + 1900, times.tm_mon + 1, times.tm_mday );
                     pItem = hb_itemPutDS( pItem, date_s );
                  }
                  break;
               }

               case SQL_TYPE_TIME:
               {
                  struct tm times;
                  isc_decode_sql_time( ( ISC_TIME * ) pVar->sqldata, &times );
                  {
                     long lMilliSec = hb_timeEncode( times.tm_hour, times.tm_min, times.tm_sec, 0 );
                     pItem = hb_itemPutTDT( pItem, 0, lMilliSec );
                  }
                  break;
               }

               default:
                  /* default value is NIL */
                  break;
            }
            if( pItem )
               hb_arraySetForward( pArray, ui + 1, pItem );
         }

         if( pArea->ulRecCount + 1 >= pArea->ulRecMax )
         {
            pArea->pRow      = ( void ** ) hb_xrealloc( pArea->pRow, ( pArea->ulRecMax + SQLDD_ROWSET_RESIZE ) * sizeof( void * ) );
            pArea->pRowFlags = ( HB_BYTE * ) hb_xrealloc( pArea->pRowFlags, ( pArea->ulRecMax + SQLDD_ROWSET_RESIZE ) * sizeof( HB_BYTE ) );
            pArea->ulRecMax += SQLDD_ROWSET_RESIZE;
         }

         pArea->ulRecCount++;
         pArea->pRow[ pArea->ulRecCount ]      = pArray;
         pArea->pRowFlags[ pArea->ulRecCount ] = SQLDD_FLAG_CACHED;
         if( pItem )
            hb_itemRelease( pItem );
      }
      else if( lErr == 100 )
      {
         pArea->fFetched = HB_TRUE;
         if( isc_dsql_free_statement( status, phStmt, DSQL_drop ) )
         {
            hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_STMTFREE, "Statement free error", NULL, ( HB_ERRCODE ) isc_sqlcode( status ) );
            return HB_FAILURE;
         }
         pSDDData->hStmt = ( isc_stmt_handle ) 0;

         if( isc_commit_transaction( status, phTr ) )
         {
            hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_COMMIT, "Transaction commit error", NULL, ( HB_ERRCODE ) isc_sqlcode( status ) );
            return HB_FAILURE;
         }
         pSDDData->hTrans = ( isc_tr_handle ) 0;

         if( pSDDData->pSqlda )
         {
            int i;
            for( i = 0; i < pSDDData->pSqlda->sqld; i++ )
            {
               if( pSDDData->pSqlda->sqlvar[ i ].sqldata )
                  hb_xfree( pSDDData->pSqlda->sqlvar[ i ].sqldata );
               if( pSDDData->pSqlda->sqlvar[ i ].sqlind )
                  hb_xfree( pSDDData->pSqlda->sqlvar[ i ].sqlind );
            }
            hb_xfree( pSDDData->pSqlda );
            pSDDData->pSqlda = NULL;
         }
      }
      else
      {
         hb_errRT_FirebirdDD( EG_OPEN, ESQLDD_FETCH, "Fetch error", NULL, ( HB_ERRCODE ) lErr );
         return HB_FAILURE;
      }
   }

   if( ulRecNo == 0 || ulRecNo > pArea->ulRecCount )
   {
      pArea->pRecord      = pArea->pRow[ 0 ];
      pArea->bRecordFlags = pArea->pRowFlags[ 0 ];
      pArea->fPositioned  = HB_FALSE;
   }
   else
   {
      pArea->pRecord      = pArea->pRow[ ulRecNo ];
      pArea->bRecordFlags = pArea->pRowFlags[ ulRecNo ];
      pArea->fPositioned  = HB_TRUE;
   }
   return HB_SUCCESS;
}