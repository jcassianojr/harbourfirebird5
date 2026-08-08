// +--------------------------------------------------------------------
// +    Programa : testfb5.prg
// +    Objetivo : Teste RDD Firebird 5 com verificação e criação de tabela
// +--------------------------------------------------------------------

REQUEST FB5RDD

FUNCTION Main()
   LOCAL nConn, hConn
   //LOCAL cServer := "localhost:C:\temp\teste.fdb"
   LOCAL cPath   := "C:\temp\teste.fdb"
   LOCAL cServer := "localhost:" + cPath
   LOCAL cUser   := "SYSDBA"
   LOCAL cPass   := "masterkey"

// 1. VERIFICA E CRIA O BANCO DE DADOS FÍSICO SE NÃO EXISTIR
   IF !File( cPath )
      ? "Arquivo FDB não encontrado. Criando banco de dados físico..."
      // Parâmetros: Server, User, Pass, PageSize, Charset, Dialect
      FBCREATEDB( cServer, cUser, cPass, 4096, "NONE", 3 )
      ? "Banco de dados criado com sucesso!"
   ENDIF

   ? "Conectando ao Firebird 5 via RDD nativo..."
   nConn := DBFB5CONNECTION( cServer, cUser, cPass, 3 )

   IF nConn == 0
      ? "Falha ao conectar!"
      QUIT
   ENDIF

   ? "Conexão C-API estabelecida. Handle RDD:", nConn
   ? "---------------------------------------------------"

   // Recuperamos o handle interno do banco para rodar a verificação e o DDL
   hConn := DBFB5GETHANDLE( nConn )

  // Recuperamos os dados da conexão do RDD
   hConn := DBFB5GETHANDLE( nConn )

   IF hConn != NIL
      // hConn é um array: { db_handle, dialect }
      // Passamos hConn[1] (o handle real) e hConn[2] (o dialeto)
      IF !MyTableExists( hConn[ 1 ], "CLIENTES", hConn[ 2 ] )
         ? "Tabela CLIENTES não encontrada. Criando tabela..."
         
         // Cria a tabela utilizando FBExecute nativo passando o handle e o dialeto
         FBExecute( hConn[ 1 ], "CREATE TABLE CLIENTES (ID INTEGER NOT NULL PRIMARY KEY, NOME VARCHAR(50), ATIVO BOOLEAN)", hConn[ 2 ] )
         ? "Tabela CLIENTES criada com sucesso!"
      ELSE
         ? "Tabela CLIENTES já existe no banco de dados."
      ENDIF
   ENDIF

   ? "---------------------------------------------------"

   // 2. Abertura da Tabela via RDD
   ? "-> USE clientes VIA 'FB5RDD'"
   USE clientes VIA "FB5RDD" ALIAS cli NEW

   // Setando a Chave Primária (Exigido pelo RDD para UPDATE/DELETE seguros)
   FB5_SETPK( "cli", "ID" )

   // 3. Inserção (APPEND BLANK)
   ? "-> APPEND BLANK e REPLACE (Inserindo dados...)"
   APPEND BLANK
   REPLACE cli->ID    WITH 100
   REPLACE cli->NOME  WITH "Maria da Silva"
   REPLACE cli->ATIVO WITH .T.
   DBCOMMIT() // Executa o FLUSH e o INSERT físico no C

   // 4. Leitura / Navegação
   ? "-> DBGOTOP() (Lendo os dados gravados...)"
   DBGOTOP()
   ? "   ID gravado   :", cli->ID
   ? "   Nome gravado :", cli->NOME
   ? "   Ativo gravado:", cli->ATIVO
   ? "---------------------------------------------------"

   // 5. Atualização (REPLACE)
   ? "-> REPLACE (Atualizando registro...)"
   REPLACE cli->NOME WITH "Maria Atualizada"
   DBCOMMIT() // Dispara o UPDATE

   DBGOTOP()
   ? "   Nome após REPLACE:", cli->NOME
   ? "---------------------------------------------------"

   // 6. Exclusão (DELETE)
   ? "-> DBDELETE() (Excluindo o registro...)"
   DBDELETE()

   // 7. Fechamento da Tabela
   ? "-> CLOSE cli"
   CLOSE cli

   // 8. Desconecta usando a função do próprio RDD
   DBFB5CLEARCONNECTION( nConn )
   
   ? "Teste RDD 100% puro concluído com sucesso."
   
   RETURN NIL


// Função auxiliar baseada na sua lógica para verificar a tabela usando a API C
STATIC FUNCTION MyTableExists( db, cTable, nDialect )
   LOCAL cQuery
   LOCAL result := .F.
   LOCAL qry

   cQuery := "select rdb$relation_name from rdb$relations where rdb$relation_name = '" + Upper( AllTrim( cTable ) ) + "'"

   qry := FBQuery( db, cQuery, nDialect )

   IF HB_ISARRAY( qry )
      result := ( FBFetch( qry ) == 0 )
      FBFree( qry )
   ENDIF

   RETURN result