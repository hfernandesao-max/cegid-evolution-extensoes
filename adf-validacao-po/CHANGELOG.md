# Histórico de versões – Validação da PO nos ADF

## 1.1.0 – 04/11/2026

- Mensagens reescritas num só parágrafo (a janela de aviso do Primavera ignora quebras de linha); erros de várias PO separados por " | ".
- Passa a usar o método de aviso actual `PSO.Dialogos.MostraMensagem`; o script de compilação recorre a `MostraAviso` se a versão do SDK não o tiver.
- Versão e identificação Naval nas propriedades do `.dll` (1.1.0.0).
- Testes de aceitação 1 a 7 aprovados na PRIFORMACAO.

Ficheiro: `releases/v1.1/Naval.Extensibility.ContasCorrentes.dll`
SHA-256: `9d0deb1c6a06921b60d0127fe08c28d3ad0b867b4676cad488047613ba70b8d6`

## 1.0.0 – 04/11/2026

- Versão inicial: validação, ao gravar um ADF a fornecedor, de uma ou mais PO no início do campo Número do Documento (existência, estado e fornecedor).
