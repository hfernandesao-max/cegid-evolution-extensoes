# Validação da PO nos ADF (Adiantamentos a Fornecedor)

Extensão do **Cegid Evolution ERP Primavera V10** que obriga a indicar, no campo **Número do Documento** dos ADF, o n.º de uma ou mais encomendas (PO) válidas do fornecedor. Permite identificar de imediato a que PO se refere cada adiantamento e agiliza a conciliação entre Compras e Tesouraria.

> Documento confidencial – Grupo Naval Angola, Projectos Digitais.

## Regra

A validação actua ao **gravar** um ADF (novo ou alterado) no editor de documentos de Contas Correntes, apenas para entidades do tipo **Fornecedor**.

| Verificação | Comportamento |
|---|---|
| O campo começa por uma ou mais PO, separadas por `;` ou `,` | Obrigatório; o resto do texto é livre |
| Tipos de documento aceites | `PO`, `POL`, `POS`, `POM`, `POI`, `ECF` |
| A PO existe na empresa | Caso contrário: "não existe nesta empresa" |
| A PO não está anulada | Caso contrário: "está anulada" |
| A PO é do mesmo fornecedor do ADF | Caso contrário: "pertence ao fornecedor X e não a Y" |

Exemplos válidos:

```
PO 2026/756 - Natighe PP 2026A/89
PO 2026/10; PO 2026/11; POL 2026/12 - Kituco PP2026B/11-12
```

ADF a entidades que não são fornecedores (ex.: conta 349100) não são validados.

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `src/` | Código-fonte C# (`UiEditorPendentes.cs`) |
| `build/` | Script de compilação (`Compilar.ps1`) |
| `sql/` | Query de controlo dos ADF sem PO válida (histórico) |
| `releases/` | `.dll` compilado de cada versão |

## Compilação

Usa o compilador C# do .NET Framework incluído no Windows (`csc.exe`); não requer Visual Studio.

1. No servidor do Primavera, copiar `src/UiEditorPendentes.cs` e `build/Compilar.ps1` para `C:\Naval\Extensoes`.
2. **Fechar o ERP.**
3. Executar:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Naval\Extensoes\Compilar.ps1
   ```
4. Resultado: `C:\Naval\Extensoes\Naval.Extensibility.ContasCorrentes.dll`.

As bibliotecas de referência são lidas de `C:\Program Files\PRIMAVERA\SG100\Apl`.

## Instalação

1. Copiar o `.dll` para `C:\Naval\Extensoes\Producao`.
2. **Administrador → Extensibilidade / Registo de extensões**: registar o `.dll` e associá-lo às empresas.
3. Reiniciar o ERP nos postos.

**Importante:** em cada nova versão é obrigatório **remover e voltar a registar** a extensão no Administrador. O Primavera guarda uma cópia do `.dll` no registo; substituir o ficheiro no disco não basta.

## Testes de aceitação (PRIFORMACAO, fornecedor F000201)

| # | Número do Documento | Resultado esperado |
|---|---|---|
| 1 | `Pag.Teste PP 2026/1` | Bloqueia – falta a PO |
| 2 | `PO 2026/62 - Teste` | Bloqueia – PO de outro fornecedor |
| 3 | `PO 2026/999999 - Teste` | Bloqueia – PO inexistente |
| 4 | `POS 2026/100 - Teste` | Bloqueia – PO anulada |
| 5 | `POS 2026/101 - Teste PP 2026/1` | Grava |
| 6 | `POS 2026/75; POS 2026/55; PO 2025/93 - Teste` | Grava |
| 7 | `POS 2026/101; PO 2026/62 - Teste` | Bloqueia – indica apenas a PO 2026/62 |

Versão 1.1: todos os testes aprovados a 04/11/2026.

## Versões

Ver [CHANGELOG.md](CHANGELOG.md).
