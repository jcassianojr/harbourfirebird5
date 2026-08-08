/*
 * Firebird RDBMS low-level (client API) interface definitions for Firebird 5.
 * Expanded & Optimized for Harbour Project
 */

#ifndef FIREBIRD5_CH
#define FIREBIRD5_CH

/* Tipos de dados oficiais da API C do Firebird / InterBase */
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
#define IB_SQL_BOOLEAN                        32764  /* */

/* Dialetos de Conexão */
#define IB_DIALECT_V5                         1
#define IB_DIALECT_V6_TRANSITION              2
#define IB_DIALECT_V6                         3
#define IB_DIALECT_CURRENT                    IB_DIALECT_V6

/* Parâmetros adicionais recomendados para Transações (TPB) */
#define FB_TRANSACTION_READ_COMMITTED        1
#define FB_TRANSACTION_SNAPSHOT               2
#define FB_TRANSACTION_SHARED                 3
#define FB_TRANSACTION_PROTECTED              4
#define FB_TRANSACTION_EXCLUSIVE              5

#endif