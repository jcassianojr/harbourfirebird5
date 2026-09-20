# Firebird 5 RDD for Harbour

Uma implementação nativa de RDD (Replaceable Database Driver) e de uma camada orientada a objetos para o Harbour, permitindo integrar aplicações xBase/Harbour com o Firebird 5 usando duas abordagens:

- SQL direto por meio da classe `Fb5class`
- Navegação e manipulação em estilo xBase via `FB5RDD`

O objetivo do projeto é oferecer acesso ao Firebird de forma simples, compatível com o ecossistema Harbour e com a conveniência de uso de bancos relacionais modernos.

---

## Visão geral

Este projeto expõe uma ponte entre o Harbour e a API nativa do Firebird 5. Ele combina:

- camada de conexão e execução SQL
- suporte a consultas e leitura de registros
- driver RDD para uso com arquivos/áreas de trabalho em sintaxe tradicional
- integração com ferramentas de compilação Harbour (`hbmk2`)

A implementação atual está organizada em módulos principais dentro da pasta `hbfbird5`, com suporte adicional a ferramentas e exemplos de uso.

---

## Principais recursos

- Conexão direta com Firebird 5 via API nativa
- Suporte a operações SQL com classes de acesso
- Compatibilidade com uso de comandos xBase tradicionais (`dbAppend`, `dbSkip`, `dbGoTop`, etc.)
- Estrutura compatível com desenvolvimento em Harbour
- Suporte para build em arquiteturas 32-bit e 64-bit via MinGW
- Integração com a biblioteca Firebird (`fbclient`, cabeçalhos `ibase.h`)

---

## Estrutura do repositório

```text
.
├── README.md                     # documentação principal
├── hbfbird5/                    # código principal do driver e classes
│   ├── Fb5class.prg             # classes para acesso SQL e conexão
│   ├── FB5RDD.prg               # driver RDD em estilo xBase
│   ├── firebird5.c              # wrapper em C para a API do Firebird
│   ├── firebird5.ch             # cabeçalhos/chamadas de constantes
│   ├── hbfbird5.hbp             # projeto de build para Harbour
│   ├── compmingw32.bat          # build para 32 bits
│   ├── compmingw64.bat          # build para 64 bits
│   ├── teste/                   # scripts de teste
│   └── doc/                     # documentação complementar
├── sddfb5/                      # outra implementação/estrutura relacionada
├── dbtest/                      # banco de teste / arquivos de exemplo
├── .gitignore
├── .gitattributes
└── ...
```

---

## Requisitos

Antes de compilar e executar o projeto, certifique-se de ter instalado:

- Harbour 3.2+ ou superior
- Compilador MinGW (32-bit ou 64-bit)
- Firebird 5 com SDK/cabeçalhos instalados
- Biblioteca cliente `fbclient` disponível no PATH ou em diretório configurado
- `hbmk2` no ambiente de build

Além disso, os cabeçalhos da API do Firebird devem estar acessíveis, e o arquivo `ibase.h` deve ser encontrado durante a compilação.

---

## Compilação

O projeto inclui scripts de build para Windows com MinGW. A configuração principal pode ser ajustada no arquivo `hbfbird5/compmingw64.bat`.

Exemplo de uso:

```bat
cd hbfbird5
set HB_WITH_FIREBIRD=C:\harbour\hb3rd\firebird-x64\include\
call d:\devprg\hb64\hb64msys.bat
call c:\devprg\hb64\hb64msys_c.bat
hbmk2.exe hbfbird5.hbp
```

Também é possível compilar usando um arquivo `.hbp` próprio, por exemplo:

```text
-hblib
-olib/${hb_plat}/${hb_comp}/${hb_name}
-w3 -es2

-Ic:/harbour/hb3rd/firebird/include/

firebird5.c
FB5RDD.prg
Fb5class.prg

$hb_pkg_install.hbm
```

> Ajuste os caminhos conforme a instalação do Harbour e do Firebird no seu ambiente.

---

## Exemplos de uso

### 1) Acesso via classe `Fb5class`

```harbour
PROCEDURE Main()
   LOCAL oDB, oQry

   oDB := Fb5class():New( "localhost:c:/dados/banco.fdb", "SYSDBA", "masterkey" )

   IF oDB:NetErr()
      ? "Erro:", oDB:Error()
      RETURN
   ENDIF

   oDB:StartTransaction()

   oDB:Execute( "CREATE TABLE clientes (id INTEGER NOT NULL PRIMARY KEY, nome VARCHAR(100), limite NUMERIC(15,2))" )
   oDB:Execute( "INSERT INTO clientes VALUES (1, 'Maria Silva', 3500.00)" )

   oDB:Commit()

   oQry := oDB:Query( "SELECT * FROM clientes" )
   DO WHILE oQry:Fetch()
      ? oQry:FieldGet( 1 ), oQry:FieldGet( 2 ), oQry:FieldGet( 3 )
   ENDDO
   oQry:Destroy()

   oDB:Close()
RETURN
```

### 2) Acesso via RDD tradicional (`FB5RDD`)

```harbour
REQUEST FB5RDD

PROCEDURE Main()
   LOCAL nConn, aStru

   nConn := DBFB5CONNECTION( "localhost:c:/dados/banco.fdb", "SYSDBA", "masterkey" )

   aStru := { ;
      { "ID",     "N",  9, 0 }, ;
      { "NOME",   "C", 50, 0 }, ;
      { "LIMITE", "N", 15, 2 }  ;
   }

   dbCreate( "clientes", aStru, "FB5RDD", .T., "CLI" )
   FB5_SETPK( "CLI", "ID" )

   CLI->( dbAppend() )
   CLI->ID     := 1
   CLI->NOME   := "João Pereira"
   CLI->LIMITE := 4200.00
   CLI->( dbCommit() )

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

## Dicas de uso

- Para projetos novos, prefira a abordagem SQL com `Fb5class` quando a lógica for mais orientada a consultas e manipulação de dados.
- Para aplicações legadas ou em estilo xBase, o driver `FB5RDD` facilita a migração e a manutenção do código.
- Ajuste sempre os caminhos do Firebird e do Harbour de acordo com a instalação local.
- Verifique se a biblioteca `fbclient.dll` está disponível no ambiente de execução do programa.

---

## Documentação complementar

Há documentação adicional sobre uso do Firebird embutido e referências úteis dentro da pasta `hbfbird5/doc/`.

Consulte também:

- `hbfbird5/doc/firebird5_embedded.md`
- arquivos de teste em `hbfbird5/teste/`

---

## Licença

Este projeto é mantido em ambiente de desenvolvimento Harbour/Firebird. Verifique o repositório para detalhes específicos de licenciamento caso seja necessário distribuir a biblioteca ou binários em produção.

---

## Contribuição

Sinta-se à vontade para abrir issues, propor melhorias e enviar ajustes para o projeto. O repositório está voltado para a evolução de acesso nativo ao Firebird no ecossistema Harbour.
