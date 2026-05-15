# VariableRetrieverProbe

Projeto separado para investigar o que o executor consegue enxergar antes/durante o load do jogo usando apenas APIs expostas ao Luau. Ele nao faz memory byte editing e nao promete ler dados server-only que nao foram replicados.

## Rodar no executor

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/VariableRetrieverProbe/variable_retriever_probe.luau?v=1", true), "variable_retriever_probe")()
```

Ou local:

```lua
loadstring(readfile("VariableRetrieverProbe/variable_retriever_probe.luau"), "variable_retriever_probe")()
```

## Saidas

O script tenta escrever estes arquivos:

- `VariableRetrieverProbe_Report.json`: relatorio completo.
- `VariableRetrieverProbe_SSS_Placeholders.luau`: script para recriar uma arvore vazia de `ServerScriptService` no Studio, quando os nomes forem acessiveis.

Se `ServerScriptService` nao estiver replicado ao cliente, o arquivo de placeholders cria pelo menos um marcador explicando isso.

## Inferencia sem memory byte editing

O probe tambem tenta inferir nomes relacionados a scripts usando:

- `getgc(true)`, se existir.
- ambientes de funcoes (`getfenv(func).script`), se expostos.
- constantes de funcoes (`debug.getconstants`, `debug.getconstant` ou `getconstants`), se expostas.
- fontes replicadas legiveis, quando `Source` pode ser lido.

Se encontrar nomes provaveis, `VariableRetrieverProbe_SSS_Placeholders.luau` cria uma pasta `ServerScriptService/Inferred_Server_Scripts` com scripts vazios usando esses nomes. Isso e apenas inferencia; nomes server-only que nunca aparecem no cliente continuam invisiveis.

## Ler o relatorio com Lua normal

```bash
lua VariableRetrieverProbe/read_report.lua VariableRetrieverProbe_Report.json
```
