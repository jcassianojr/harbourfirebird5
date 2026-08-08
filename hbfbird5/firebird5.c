/*
 * Firebird RDBMS low-level (client API) interface code for Firebird 5.
 * Adapted for Harbour Project (32-bit & 64-bit support)
 */

#include <time.h>

#if ( defined( __BORLANDC__ ) && __BORLANDC__ >= 0x582 )
   #define __STDINT_H
#endif

#include "hbapi.h"
#include "hbapierr.h"
#include "hbapiitm.h"

#include "ibase.h"

#ifndef ISC_INT64_FORMAT
   #define ISC_INT64_FORMAT  PFLL
#endif

/* GC object handlers */

static HB_GARBAGE_FUNC( FB_db_handle_release )
{
   isc_db_handle * ph = ( isc_db_handle * ) Cargo;

   if( ph && *ph )
   {
      ISC_STATUS_ARRAY status;
      isc_detach_database( status, ph );
      *ph = 0;
   }
}

static const HB_GC_FUNCS s_gcFB_db_handleFuncs =
{
   FB_db_handle_release,
   hb_gcDummyMark
};

static void hb_FB_db_handle_ret( isc_db_handle p )
{
   if( p )
   {
      isc_db_handle * ph = ( isc_db_handle * )
                           hb_gcAllocate( sizeof( isc_db_handle ), &s_gcFB_db_handleFuncs );
      *ph = p;
      hb_retptrGC( ph );
   }
   else
      hb_retptr( NULL );
}

static isc_db_handle hb_FB_db_handle_par( int iParam )
{
   isc_db_handle * ph = ( isc_db_handle * ) hb_parptrGC( &s_gcFB_db_handleFuncs, iParam );
   return ph ? *ph : 0;
}

/* API wrappers */

HB_FUNC( FBCREATEDB )
{
   if( hb_pcount() >= 6 )
   {
      isc_db_handle newdb = ( isc_db_handle ) 0;
      isc_tr_handle trans = ( isc_tr_handle ) 0;
      ISC_STATUS    status[ 20 ];
      char          create_db[ 1024 ];

      const char *   db_name = hb_parcx( 1 );
      const char *   user    = hb_parcx( 2 );
      const char *   pass    = hb_parcx( 3 );
      int            page    = hb_parni( 4 );
      const char *   charset = hb_parcx( 5 );
      unsigned short dialect = ( unsigned short ) hb_parni( 6 );
      const char *   collate = hb_parcx( 7 );

      hb_snprintf( create_db, sizeof( create_db ),
                   "CREATE DATABASE '%s' USER '%s' PASSWORD '%s' PAGE_SIZE = %i DEFAULT CHARACTER SET %s%s%s",
                   db_name, user, pass, page, charset, ( hb_parclen( 7 ) > 0 ? " COLLATION " : "" ), ( collate ? collate : "" ) );

      if( isc_dsql_execute_immediate( status, &newdb, &trans, 0, create_db, dialect, NULL ) )
         hb_retnl( isc_sqlcode( status ) );
      else
      {
         isc_detach_database( status, &newdb );
         hb_retnl( 1 );
      }
   }
   else
      hb_retnl( 0 );
}

HB_FUNC( FBCONNECT )
{
   ISC_STATUS_ARRAY status;
   isc_db_handle    db         = ( isc_db_handle ) 0;
   const char *     db_connect = hb_parcx( 1 );
   const char *     user       = hb_parcx( 2 );
   const char *     passwd     = hb_parcx( 3 );
   const char *     charset    = hb_parc( 4 );
   char  dpb[ 256 ];
   short i = 0;
   int   len;

   dpb[ i++ ] = isc_dpb_version1;
   dpb[ i++ ] = isc_dpb_user_name;
   len        = ( int ) strlen( user );
   if( len > ( int ) ( sizeof( dpb ) - i - 4 ) )
      len = ( int ) ( sizeof( dpb ) - i - 4 );
   dpb[ i++ ] = ( char ) len;
   hb_strncpy( &( dpb[ i ] ), user, len );
   i += ( short ) len;

   dpb[ i++ ] = isc_dpb_password;
   len        = ( int ) strlen( passwd );
   if( len > ( int ) ( sizeof( dpb ) - i - 2 ) )
      len = ( int ) ( sizeof( dpb ) - i - 2 );
   dpb[ i++ ] = ( char ) len;
   hb_strncpy( &( dpb[ i ] ), passwd, len );
   i += ( short ) len;

   if( charset && charset[ 0 ] != '\0' )
   {
      dpb[ i++ ] = isc_dpb_lc_ctype;
      len        = ( int ) strlen( charset );
      dpb[ i++ ] = ( char ) len;
      hb_strncpy( &( dpb[ i ] ), charset, len );
      i += ( short ) len;
   }

   if( isc_attach_database( status, 0, db_connect, &db, i, dpb ) )
      hb_retnl( isc_sqlcode( status ) );
   else
      hb_FB_db_handle_ret( db );
}

HB_FUNC( FBCLOSE )
{
   isc_db_handle db = hb_FB_db_handle_par( 1 );

   if( db )
   {
      ISC_STATUS_ARRAY status;

      if( isc_detach_database( status, &db ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBERROR )
{
   char msg[ 1024 ];

   isc_sql_interprete( ( short ) hb_parni( 1 ), msg, sizeof( msg ) );
   hb_retc( msg );
}

HB_FUNC( FBSTARTTRANSACTION )
{
   isc_db_handle db = hb_FB_db_handle_par( 1 );

   if( db )
   {
      isc_tr_handle    trans = ( isc_tr_handle ) 0;
      ISC_STATUS_ARRAY status;
      static char      tpb[] = { isc_tpb_version3, isc_tpb_write, isc_tpb_read_committed, isc_tpb_rec_version, isc_tpb_nowait };

      if( isc_start_transaction( status, &trans, 1, &db, sizeof( tpb ), tpb ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retptr( ( void * ) ( HB_PTRUINT ) trans );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBCOMMIT )
{
   isc_tr_handle trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 1 );

   if( trans )
   {
      ISC_STATUS_ARRAY status;

      if( isc_commit_transaction( status, &trans ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBROLLBACK )
{
   isc_tr_handle trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 1 );

   if( trans )
   {
      ISC_STATUS_ARRAY status;

      if( isc_rollback_transaction( status, &trans ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBEXECUTE )
{
   isc_db_handle db = hb_FB_db_handle_par( 1 );

   if( db )
   {
      isc_tr_handle  trans    = ( isc_tr_handle ) 0;
      const char *   exec_str = hb_parcx( 2 );
      ISC_STATUS     status[ 20 ];
      ISC_STATUS     status_rollback[ 20 ];
      unsigned short dialect = ( unsigned short ) hb_parni( 3 );

      if( HB_ISPOINTER( 4 ) )
         trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 4 );
      else
      {
         if( isc_start_transaction( status, &trans, 1, &db, 0, NULL ) )
         {
            hb_retnl( isc_sqlcode( status ) );
            return;
         }
      }

      if( isc_dsql_execute_immediate( status, &db, &trans, 0, exec_str, dialect, NULL ) )
      {
         if( ! HB_ISPOINTER( 4 ) )
            isc_rollback_transaction( status_rollback, &trans );

         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( ! HB_ISPOINTER( 4 ) )
      {
         if( isc_commit_transaction( status, &trans ) )
         {
            hb_retnl( isc_sqlcode( status ) );
            return;
         }
      }

      hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBQUERY )
{
   isc_db_handle db = hb_FB_db_handle_par( 1 );

   if( db )
   {
      isc_tr_handle    trans = ( isc_tr_handle ) 0;
      ISC_STATUS_ARRAY status;
      XSQLDA *         sqlda;
      isc_stmt_handle  stmt = ( isc_stmt_handle ) 0;
      XSQLVAR *        var;

      unsigned short dialect = ( unsigned short ) hb_parnidef( 3, SQL_DIALECT_V5 );
      int i;
      int num_cols;

      PHB_ITEM qry_handle;
      PHB_ITEM aNew;
      PHB_ITEM aTemp;

      if( HB_ISPOINTER( 4 ) )
         trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 4 );
      else if( isc_start_transaction( status, &trans, 1, &db, 0, NULL ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( isc_dsql_allocate_statement( status, &db, &stmt ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      sqlda          = ( XSQLDA * ) hb_xgrab( XSQLDA_LENGTH( 1 ) );
      sqlda->sqln    = 1;
      sqlda->version = 1;

      if( isc_dsql_prepare( status, &trans, &stmt, 0, hb_parcx( 2 ), dialect, sqlda ) )
      {
         hb_xfree( sqlda );
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( isc_dsql_describe( status, &stmt, dialect, sqlda ) )
      {
         hb_xfree( sqlda );
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( sqlda->sqld > sqlda->sqln )
      {
         ISC_SHORT n = sqlda->sqld;
         sqlda          = ( XSQLDA * ) hb_xrealloc( sqlda, XSQLDA_LENGTH( n ) );
         sqlda->sqln    = n;
         sqlda->version = 1;

         if( isc_dsql_describe( status, &stmt, dialect, sqlda ) )
         {
            hb_xfree( sqlda );
            hb_retnl( isc_sqlcode( status ) );
            return;
         }
      }

      num_cols = sqlda->sqld;
      aNew     = hb_itemArrayNew( num_cols );
      aTemp    = hb_itemNew( NULL );

      for( i = 0, var = sqlda->sqlvar; i < sqlda->sqld; i++, var++ )
      {
         int dtype = ( var->sqltype & ~1 );

         switch( dtype )
         {
            case SQL_VARYING:
               var->sqldata = ( char * ) hb_xgrab( sizeof( char ) * var->sqllen + 2 );
               break;
            case SQL_TEXT:
               var->sqldata = ( char * ) hb_xgrab( sizeof( char ) * var->sqllen + 2 );
               break;
            case SQL_BOOLEAN:
               var->sqldata = ( char * ) hb_xgrab( sizeof( ISC_UCHAR ) );
               break;
            case SQL_LONG:
               var->sqldata = ( char * ) hb_xgrab( sizeof( long ) );
               break;
            case SQL_SHORT:
               var->sqldata = ( char * ) hb_xgrab( sizeof( short ) );
               break;
            case SQL_INT64:
               var->sqldata = ( char * ) hb_xgrab( sizeof( ISC_INT64 ) );
               break;
            default:
               var->sqldata = ( char * ) hb_xgrab( sizeof( char ) * var->sqllen );
               break;
         }

         if( var->sqltype & 1 )
            var->sqlind = ( short * ) hb_xgrab( sizeof( short ) );

         hb_arrayNew( aTemp, 7 );

         hb_arraySetC(  aTemp, 1, sqlda->sqlvar[ i ].sqlname );
         hb_arraySetNL( aTemp, 2, ( long ) dtype );
         hb_arraySetNL( aTemp, 3, sqlda->sqlvar[ i ].sqllen );
         hb_arraySetNL( aTemp, 4, sqlda->sqlvar[ i ].sqlscale );
         hb_arraySetC(  aTemp, 5, sqlda->sqlvar[ i ].relname );
         hb_arraySetNL( aTemp, 6, sqlda->sqlvar[ i ].aliasname_length );
         hb_arraySetC(  aTemp, 7, sqlda->sqlvar[ i ].aliasname );

         hb_arraySetForward( aNew, i + 1, aTemp );
      }

      hb_itemRelease( aTemp );

      if( isc_dsql_execute( status, &trans, &stmt, dialect, ( sqlda->sqld ? sqlda : NULL ) ) )
      {
         hb_itemRelease( aNew );
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      qry_handle = hb_itemArrayNew( 6 );

      hb_arraySetPtr( qry_handle, 1, ( void * ) ( HB_PTRUINT ) stmt );
      hb_arraySetPtr( qry_handle, 2, ( void * ) ( HB_PTRUINT ) sqlda );

      if( ! HB_ISPOINTER( 4 ) )
         hb_arraySetPtr( qry_handle, 3, ( void * ) ( HB_PTRUINT ) trans );

      hb_arraySetNL( qry_handle, 4, ( long ) num_cols );
      hb_arraySetNI( qry_handle, 5, ( int ) dialect );
      hb_arraySetForward( qry_handle, 6, aNew );

      hb_itemReturnRelease( qry_handle );
      hb_itemRelease( aNew );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBFETCH )
{
   PHB_ITEM aParam = hb_param( 1, HB_IT_ARRAY );

   if( aParam )
   {
      isc_stmt_handle  stmt  = ( isc_stmt_handle ) ( HB_PTRUINT ) hb_itemGetPtr( hb_itemArrayGet( aParam, 1 ) );
      XSQLDA *         sqlda = ( XSQLDA * ) hb_itemGetPtr( hb_itemArrayGet( aParam, 2 ) );
      ISC_STATUS_ARRAY status;
      unsigned short   dialect = ( unsigned short ) hb_itemGetNI( hb_itemArrayGet( aParam, 5 ) );

      hb_retnl( isc_dsql_fetch( status, &stmt, dialect, sqlda ) == 100 ? -1 : isc_sqlcode( status ) );
   }
   else
      hb_retnl( 0 );
}

HB_FUNC( FBFREE )
{
   PHB_ITEM aParam = hb_param( 1, HB_IT_ARRAY );

   if( aParam )
   {
      isc_stmt_handle  stmt  = ( isc_stmt_handle ) ( HB_PTRUINT ) hb_itemGetPtr( hb_itemArrayGet( aParam, 1 ) );
      XSQLDA *         sqlda = ( XSQLDA * ) hb_itemGetPtr( hb_itemArrayGet( aParam, 2 ) );
      isc_tr_handle    trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_itemGetPtr( hb_itemArrayGet( aParam, 3 ) );
      ISC_STATUS_ARRAY status;

      if( isc_dsql_free_statement( status, &stmt, DSQL_drop ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( trans && isc_commit_transaction( status, &trans ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( sqlda )
      {
         int i;
         for( i = 0; i < sqlda->sqld; i++ )
         {
            if( sqlda->sqlvar[ i ].sqldata )
               hb_xfree( sqlda->sqlvar[ i ].sqldata );
            if( sqlda->sqlvar[ i ].sqlind )
               hb_xfree( sqlda->sqlvar[ i ].sqlind );
         }
         hb_xfree( sqlda );
      }

      hb_retnl( 1 );
   }
   else
      hb_retnl( 0 );
}

HB_FUNC( FBGETDATA )
{
   PHB_ITEM aParam = hb_param( 1, HB_IT_ARRAY );

   if( aParam )
   {
      XSQLVAR *        var;
      XSQLDA *         sqlda = ( XSQLDA * ) hb_itemGetPtr( hb_itemArrayGet( aParam, 2 ) );
      ISC_STATUS_ARRAY status;

      int pos = hb_parni( 2 ) - 1;

      if( ! sqlda || pos < 0 || pos >= sqlda->sqln )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      var = sqlda->sqlvar + pos;

      if( ( var->sqltype & 1 ) && ( *var->sqlind < 0 ) )
      {
         hb_ret();
      }
      else
      {
         struct tm times;
         char      date_s[ 25 ];
         char      data[ 1024 ];

         short dtype = var->sqltype & ~1;

         switch( dtype )
         {
            case SQL_TEXT:
            case SQL_VARYING:
               hb_retclen( var->sqldata, var->sqllen );
               break;

            case SQL_BOOLEAN:
               hb_retl( *( ISC_UCHAR * ) var->sqldata ? HB_TRUE : HB_FALSE );
               break;

            case SQL_TIMESTAMP:
               isc_decode_timestamp( ( ISC_TIMESTAMP * ) var->sqldata, &times );
               hb_snprintf( date_s, sizeof( date_s ), "%04d-%02d-%02d %02d:%02d:%02d.%04d",
                            times.tm_year + 1900,
                            times.tm_mon + 1,
                            times.tm_mday,
                            times.tm_hour,
                            times.tm_min,
                            times.tm_sec,
                            ( int ) ( ( ( ISC_TIMESTAMP * ) var->sqldata )->timestamp_time % 10000 ) );
               hb_retc( date_s );
               break;

            case SQL_TYPE_DATE:
               isc_decode_sql_date( ( ISC_DATE * ) var->sqldata, &times );
               hb_snprintf( date_s, sizeof( date_s ), "%04d-%02d-%02d", times.tm_year + 1900, times.tm_mon + 1, times.tm_mday );
               hb_retc( date_s );
               break;

            case SQL_TYPE_TIME:
               isc_decode_sql_time( ( ISC_TIME * ) var->sqldata, &times );
               hb_snprintf( date_s, sizeof( date_s ), "%02d:%02d:%02d.%04d",
                            times.tm_hour,
                            times.tm_min,
                            times.tm_sec,
                            ( int ) ( ( *( ( ISC_TIME * ) var->sqldata ) ) % 10000 ) );
               hb_retc( date_s );
               break;

            case SQL_BLOB:
            case SQL_QUAD:
            {
               ISC_QUAD * blob_id = ( ISC_QUAD * ) var->sqldata;
               hb_retptr( ( void * ) blob_id );
               break;
            }
            case SQL_SHORT:
            case SQL_LONG:
            case SQL_INT64:
            {
               ISC_INT64 value;
               short     field_width;
               short     dscale;

               switch( dtype )
               {
                  case SQL_SHORT:
                     value       = ( ISC_INT64 ) *( short * ) var->sqldata;
                     field_width = 6;
                     break;

                  case SQL_LONG:
                     value       = ( ISC_INT64 ) *( long * ) var->sqldata;
                     field_width = 11;
                     break;

                  case SQL_INT64:
                     value       = ( ISC_INT64 ) *( ISC_INT64 * ) var->sqldata;
                     field_width = 21;
                     break;

                  default:
                     value       = 0;
                     field_width = 10;
                     break;
               }

               dscale = var->sqlscale;

               if( dscale < 0 )
               {
                  ISC_INT64 tens = 1;
                  short     i;

                  for( i = 0; i > dscale; i-- )
                     tens *= 10;

                  if( value >= 0 )
                     hb_snprintf( data, sizeof( data ), "%*" ISC_INT64_FORMAT "d.%0*" ISC_INT64_FORMAT "d",
                                  field_width - 1 + dscale,
                                  ( ISC_INT64 ) value / tens,
                                  -dscale,
                                  ( ISC_INT64 ) value % tens );
                  else if( ( value / tens ) != 0 )
                     hb_snprintf( data, sizeof( data ), "%*" ISC_INT64_FORMAT "d.%0*" ISC_INT64_FORMAT "d",
                                  field_width - 1 + dscale,
                                  ( ISC_INT64 ) ( value / tens ),
                                  -dscale,
                                  ( ISC_INT64 ) -( value % tens ) );
                  else
                     hb_snprintf( data, sizeof( data ), "%*s.%0*" ISC_INT64_FORMAT "d",
                                  field_width - 1 + dscale,
                                  "-0",
                                  -dscale,
                                  ( ISC_INT64 ) -( value % tens ) );
               }
               else if( dscale )
                  hb_snprintf( data, sizeof( data ), "%*" ISC_INT64_FORMAT "d%0*d", field_width, ( ISC_INT64 ) value, dscale, 0 );
               else
                  hb_snprintf( data, sizeof( data ), "%*" ISC_INT64_FORMAT "d", field_width, ( ISC_INT64 ) value );

               hb_retc( data );
               break;
            }
            case SQL_FLOAT:
               hb_snprintf( data, sizeof( data ), "%15g", *( float * ) ( var->sqldata ) );
               hb_retc( data );
               break;

            case SQL_DOUBLE:
               hb_snprintf( data, sizeof( data ), "%24f", *( double * ) ( var->sqldata ) );
               hb_retc( data );
               break;

            default:
               hb_ret();
               break;
         }
      }
   }
}

HB_FUNC( FBGETBLOB )
{
   isc_db_handle db = hb_FB_db_handle_par( 1 );

   if( db )
   {
      ISC_STATUS_ARRAY status;
      isc_tr_handle    trans       = ( isc_tr_handle ) 0;
      isc_blob_handle  blob_handle = ( isc_blob_handle ) 0;
      short      blob_seg_len;
      char       blob_segment[ 512 ];
      ISC_QUAD * blob_id = ( ISC_QUAD * ) hb_parptr( 2 );
      ISC_STATUS blob_stat;

      if( HB_ISPOINTER( 3 ) )
         trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 3 );
      else
      {
         if( isc_start_transaction( status, &trans, 1, &db, 0, NULL ) )
         {
            hb_retnl( isc_sqlcode( status ) );
            return;
         }
      }

      if( isc_open_blob2( status, &db, &trans, &blob_handle, blob_id, 0, NULL ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      blob_stat = isc_get_segment( status, &blob_handle,
                                   ( unsigned short * ) &blob_seg_len,
                                   sizeof( blob_segment ), blob_segment );

      if( blob_stat == 0 || status[ 1 ] == isc_segment )
      {
         PHB_ITEM aNew = hb_itemArrayNew( 0 );

         while( blob_stat == 0 || status[ 1 ] == isc_segment )
         {
            char     p[ 1024 ];
            PHB_ITEM temp;

            hb_snprintf( p, sizeof( p ), "%*.*s", blob_seg_len, blob_seg_len, blob_segment );

            temp = hb_itemPutC( NULL, p );
            hb_arrayAdd( aNew, temp );
            hb_itemRelease( temp );

            blob_stat = isc_get_segment( status, &blob_handle,
                                         ( unsigned short * ) &blob_seg_len,
                                         sizeof( blob_segment ), blob_segment );
         }

         hb_itemReturnRelease( aNew );
      }

      if( isc_close_blob( status, &blob_handle ) )
      {
         hb_retnl( isc_sqlcode( status ) );
         return;
      }

      if( ! HB_ISPOINTER( 3 ) )
      {
         if( isc_commit_transaction( status, &trans ) )
         {
            hb_retnl( isc_sqlcode( status ) );
            return;
         }
      }
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBCOMMITTRANSACTION )
{
   isc_tr_handle trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 1 );

   if( trans )
   {
      ISC_STATUS_ARRAY status;

      if( isc_commit_transaction( status, &trans ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

HB_FUNC( FBROLLBACKTRANSACTION )
{
   isc_tr_handle trans = ( isc_tr_handle ) ( HB_PTRUINT ) hb_parptr( 1 );

   if( trans )
   {
      ISC_STATUS_ARRAY status;

      if( isc_rollback_transaction( status, &trans ) )
         hb_retnl( isc_sqlcode( status ) );
      else
         hb_retnl( 1 );
   }
   else
      hb_errRT_BASE( EG_ARG, 2020, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}