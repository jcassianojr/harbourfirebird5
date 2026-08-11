# Firebird 5 RDD for Harbour

Uma implementação nativa de **RDD (Replaceable Database Driver)** e camada de classes orientada a objetos para o Harbour, permitindo interagir com o **Firebird 5** usando tanto sintaxe SQL direta quanto comandos tradicionais xBase (`dbAppend`, `dbSkip`, `dbGoTop`, etc.).

---

## 🚀 Características

* **Arquitetura Cliente/Servidor Robusta:** Conexão direta com o motor do Firebird via C-API de baixo nível otimizada.


* **Dual Interface:**
* Camada orientada a objetos (`Fb5class` / `TFBQuery`) para manipulação via comandos SQL puros.


* Camada RDD (`FB5RDD`) para navegação e manipulação estilo DBF através de áreas de trabalho (*WorkAreas*).




* **Suporte Multi-arquitetura:** Compatível com ambientes de 32-bits e 64-bits.


* **Camada de Cache Inteligente:** Minimiza idas e vindas ao SGBD durante a navegação por registros através de um buffer local gerenciado pela RDD.



---

## 📦 Estrutura dos Arquivos

O projeto é composto por três componentes principais:

1. **`Fb5class.prg`**: Classes de conexão, execução de transações, controle de metadados e consultas (*Query* e *Row*).


2. **`FB5RDD.prg`**: Implementação das funções de RDD do USRRDD para compatibilidade xBase.


3. **`firebird5.c`**: Wrapper de baixo nível em C que faz a ponte entre a C-API do Firebird e o ecossistema do Harbour.



---

## 🛠️ Compilação

Para compilar o seu projeto utilizando o utilitário `hbmk2`, certifique-se de incluir os caminhos de *include* da API do Firebird e de linkar as dependências corretas.

Exemplo de arquivo de projeto (`hbfirebird.hbp`):

```text
-hblib
-olib/${hb_plat}/${hb_comp}/${hb_name}
-w3 -es2

# Caminho para os arquivos de cabeçalho (.h) do Firebird
-Ic:/harbour/hb3rd/firebird/include/

firebird5.c
FB5RDD.prg
Fb5class.prg

$hb_pkg_install.hbm

```

---

## 📖 Exemplos de Uso

### 1. Utilizando via Classe (`Fb5class`)

```harbour
PROCEDURE Main()
   LOCAL oDB, oQry

   // Conecta ao servidor Firebird
   oDB := Fb5class():New( "localhost:c:/dados/banco.fdb", "SYSDBA", "masterkey" )
   
   IF oDB:NetErr()
      ? "Erro:", oDB:Error()
      RETURN
   ENDIF

   oDB:StartTransaction()

   // Criação de Tabela
   oDB:Execute( "CREATE TABLE clientes (id INTEGER NOT NULL PRIMARY KEY, nome VARCHAR(100), limite NUMERIC(15,2))" )

   // Inserção
   oDB:Execute( "INSERT INTO clientes VALUES (1, 'Maria Silva', 3500.00)" )

   oDB:Commit()

   // Consulta (Query)
   oQry := oDB:Query( "SELECT * FROM clientes" )
   DO WHILE oQry:Fetch()
      ? oQry:FieldGet( 1 ), oQry:FieldGet( 2 ), oQry:FieldGet( 3 )
   ENDDO
   oQry:Destroy()

   oDB:Close()
RETURN

```

### 2. Utilizando via RDD Tradicional (`FB5RDD`)

```harbour
REQUEST FB5RDD

PROCEDURE Main()
   LOCAL nConn, aStru

   // Inicia a conexão com o Firebird
   nConn := DBFB5CONNECTION( "localhost:c:/dados/banco.fdb", "SYSDBA", "masterkey" )

   // Define a estrutura da tabela virtual
   aStru := { ;
      { "ID",     "N",  9, 0 }, ;
      { "NOME",   "C", 50, 0 }, ;
      { "LIMITE", "N", 15, 2 }  ;
   }

   // Cria e abre a tabela utilizando a RDD do Firebird
   dbCreate( "clientes", aStru, "FB5RDD", .T., "CLI" )

   // Configura a chave primária para permitir updates/deletes automáticos[cite: 2]
   FB5_SETPK( "CLI", "ID" )

   // Inserção estilo xBase
   CLI->( dbAppend() )
   CLI->ID     := 1
   CLI->NOME   := "João Pereira"
   CLI->LIMITE := 4200.00
   CLI->( dbCommit() )

   // Navegação
   CLI->( dbGoTop() )
   DO WHILE !CLI->( EOF() )
      ? CLI->ID, CLI->NOME, CLI->LIMITE
      CLI->( dbSkip() )
   ENDDO

   CLOSE ALL
   DBFB5CLEARCONNECTION( nConn )
RETURN

```

---

## ⚙️ Requisitos

* **Harbour 3.2+** (ou superior)
* Compilador **MinGW** (32-bits ou 64-bits)


* **Firebird 5** (Servidor instalado e arquivos de cabeçalho `ibase.h`)