# Controlador de Cache - ARQIII TP1

Trabalho Prático 1 da disciplina Arquitetura de Computadores III.

## Descrição

Este projeto implementa um controlador de cache em SystemVerilog baseado na Seção 5.12 do livro *Computer Organization and Design - RISC-V Edition*.

A implementação utiliza uma cache set-associative de 2 vias com política de substituição LRU e política de escrita Write-Back com Write-Allocate.

## Características

- Cache 2-Way Set Associative
- 1024 conjuntos
- 2048 linhas no total
- Capacidade de 32 KB
- Blocos de 16 bytes (128 bits)
- Política LRU (Least Recently Used)
- Write-Back
- Write-Allocate
- Memória principal simulada com 64 KB
- Latência de 10 ciclos para acesso à memória principal

## Organização do Endereço

| Campo | Bits |
|--------|--------|
| Tag | 31:14 |
| Índice | 13:4 |
| Offset | 3:2 |
| Byte | 1:0 |

## Compilação e Execução

Exemplo de compilação para o teste de casos limite:

```bash
iverilog -g2012 -o cache_sim \
cache/cache_def.sv \
cache/dm_cache_data.sv \
cache/tag_memory.sv \
memoria/main_memory.sv \
cache/dm_cache_fsm.sv \
tb/edge_cases_tb.sv
```

Para executar a simulação:

```bash
vvp cache_sim
```

## Testes Implementados

- Leitura com hit e miss
- Escrita com hit e miss
- Write-Allocate
- Write-Back
- Substituição utilizando LRU
- Consistência dos dados
- Conflito de índices
- Casos limite com endereços extremos

Todos os cenários previstos foram executados com sucesso durante as simulações.

## Integrantes

- André Vieira Penchel
- Matheus de Oliveira Campelo
- Henrique Saldanha Mendes Veloso
- João Victor Ferreira Pena
