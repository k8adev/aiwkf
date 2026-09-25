# agents

[English](README.md)

Uma escada de cinco agentes pro Claude Code e pro Codex, ordenada pela complexidade da tarefa.

## A escada

| Agente | Quando usar | Pin no Claude | Pin no Codex |
|---|---|---|---|
| Operator | A mudança já está decidida até o último detalhe | ![haiku](https://img.shields.io/badge/haiku-555) | ![gpt-6-luna / low](https://img.shields.io/badge/gpt--6--luna-low-2ea44f) |
| Researcher | Investigação somente leitura de qualquer fonte | ![sonnet / medium](https://img.shields.io/badge/sonnet-medium-1f6feb) | ![gpt-6-sol / medium](https://img.shields.io/badge/gpt--6--sol-medium-1f6feb) |
| Builder | Implementação com escopo, pequenas decisões, sem padrão novo | ![sonnet / medium](https://img.shields.io/badge/sonnet-medium-1f6feb) | ![gpt-6-sol / medium](https://img.shields.io/badge/gpt--6--sol-medium-1f6feb) |
| Specialist | Mudança transversal, sem padrão existente, risco real de correção | ![opus / high](https://img.shields.io/badge/opus-high-8250df) | ![gpt-6-astra / high](https://img.shields.io/badge/gpt--6--astra-high-8250df) |
| Reviewer | Validar um plano, diff, texto ou decisão antes de seguir com ele | ![opus / high](https://img.shields.io/badge/opus-high-8250df) | ![gpt-6-astra / medium](https://img.shields.io/badge/gpt--6--astra-medium-8250df) |

### Escalonamento

```mermaid
flowchart LR
  Operator -- escala --> Builder -- escala --> Specialist -- escala --> caller
  caller -. inicia .-> Builder
  caller -. inicia .-> Specialist
```

Cada agente trabalha no seu degrau. Quando a tarefa passa do que ele pode decidir, ele não chuta.
Ele termina com um handoff que diz qual é o próximo degrau e o que encontrou, então o **Operator**
aponta pro **Builder**, o **Builder** aponta pro **Specialist** e o **Specialist** devolve pro
caller, a sessão principal que começou o trabalho.

Só o caller inicia o **Builder** ou o **Specialist**, e é isso que as linhas pontilhadas mostram.
Nenhum agente sobe a escada sozinho, então a sessão principal continua no controle de quanto
esforço e custo cada tarefa recebe.

Qualquer agente ainda pode passar um restante já totalmente especificado pro **Operator**, ou
consultar o **Researcher** ou o **Reviewer** uma vez por pergunta. Decisões que são do usuário,
como intenção de produto, prioridade, segurança, dados pessoais ou dinheiro, sempre voltam pro
caller como uma pergunta, com as opções e o custo de cada uma.

O formato do handoff e o resto das regras ficam na seção Contract de cada arquivo de agente.

## Instalação

**Claude Code**

```
/plugin marketplace add k8adev/aiwkf
/plugin install agents@aiwkf
```

**Codex**

```
codex plugin marketplace add k8adev/aiwkf
codex plugin add agents@aiwkf
mkdir -p "${CODEX_HOME:-$HOME/.codex}/agents"
cp -i "${CODEX_HOME:-$HOME/.codex}"/.tmp/marketplaces/aiwkf/plugins/agents/codex/*.toml "${CODEX_HOME:-$HOME/.codex}/agents/"
```

O plugin entrega a skill **orchestrate**. Copie os perfis de agente pra `~/.codex/agents/`
(ou pro `.codex/agents/` de um projeto) como arquivos comuns.

O `cp -i` pergunta antes de sobrescrever um arquivo existente. Confira antes e guarde uma cópia
se ele tiver alterações suas. Depois de atualizar o plugin, repita a cópia pra atualizar os
perfis, abra uma sessão nova do Codex e confira se um agente consegue executar de fato.

Pra desenvolvimento, copie os perfis da pasta `plugins/agents/codex/` do seu checkout e
repita a cópia depois de cada alteração.

Pra remover os perfis instalados, confira estes cinco arquivos e confirme cada remoção:

```bash
rm -i "${CODEX_HOME:-$HOME/.codex}"/agents/{operator,researcher,builder,specialist,reviewer}.toml
```

## Recomendado

A skill **orchestrate** é acionada pela descrição, mas não toda vez. Pra fazer a sessão principal
passar o trabalho pela escada, adicione este bloco às suas instruções globais,
`~/.claude/CLAUDE.md` no Claude Code ou `~/.codex/AGENTS.md` no Codex.

```
## Delegation

The session orchestrates: it decides, sequences and talks to me; subagents do the work.
Before any search, change, research, review, or external write (MCP/API), load the `orchestrate`
skill; it decides whether and to whom to delegate (`agents:orchestrate` on Claude Code).
```

## Limites

- **Researcher** e **Reviewer** são somente leitura por contrato, não totalmente por ferramenta.
  No Claude, a lista de ferramentas não bloqueia escritas via Bash ou MCP, e o sandbox somente
  leitura do Codex também não.
- Delegação aninhada no Codex, quando o `spawn_agent` chama outro perfil, não é documentada.
  Verifique antes de depender disso.
- O caminho `.tmp/marketplaces/` do Codex é interno e não documentado. Se ele mudar, localize
  os perfis no novo checkout do marketplace antes de copiar. As cópias instaladas continuam intactas.
- Não está documentado pra qual modelo o alias `opus` do Claude Code resolve hoje.
- O Claude Haiku 4.5 não tem o parâmetro `effort`, então o frontmatter do **Operator** no Claude
  não o inclui.
