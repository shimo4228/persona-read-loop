# persona-read-loop

An [Agent Skill](https://agentskills.io/specification) for Claude Code that has three LLM reader personas read your draft (an article or a README), tells you where they stopped and whether your decision got across, and checks each revision for claims you did not make. It is a cheap check before a human reads the draft, not user research: the readers' answers show what to fix, and their scores never accept a draft. The loop ends when the readers stop giving new reasons, never when a score goes up. The author's other work is listed under [More from the author](#more-from-the-author).

## What a round looks like

1. Pick three readers whose verdicts would split for different reasons, and keep them for every round.
2. Freeze the draft. Readers get a copy with collapsed sections emptied and images replaced by their alt text, since real readers judge without opening them.
3. Run the three readers in parallel as separate `claude -p` processes. Each answers in JSON: where they stopped, what they think you decided, what pushed them away.
4. Sort the reasons. Order, entry and missing explanations are fixed in the text. Missing facts ("not measured", "no comparison") go back to you, because rewording would only hide them.
5. Revise, then count what the revision changed: new numbers, superlatives and names, and hedges added or removed. If anything is listed, you confirm it before the next round.
6. Stop when no new reason appears, when only missing facts are left, or after three revisions. Then you read the draft.

Two presets ship with it. `article` checks whether readers can restate what the author decided, left open, and why. `readme` checks whether a first-time visitor would try the project and what stopped them.

## Install

You need the Claude Code CLI (`claude`) and Python 3.11 or later. The Python script uses only the standard library.

```bash
git clone https://github.com/shimo4228/persona-read-loop
mkdir -p ~/.claude/skills
cp -r persona-read-loop/skills/persona-read-loop ~/.claude/skills/
```

Check that the readers cannot see your setup before the first run:

```bash
~/.claude/skills/persona-read-loop/scripts/read.sh --probe
```

```text
tools        0
mcp_servers  0
user skills  0   (built-in 22)
context      NONE
ok isolated - claude 2.1.302
```

Exit 0 means the reader process starts with no tools, no MCP servers, none of your skills, and no memory or CLAUDE.md. Exit 1 means something reached it; exit 2 means the check could not run (the CLI is missing or failed). The skill stops on either. Then ask Claude Code to have personas read your draft; the skill picks the preset from the target.

Each round starts three `claude -p` processes with the reader model (Sonnet by default), so it counts against your Claude usage.

## Why the readers run as separate processes

A reader who has read your notes already knows what you meant, so it cannot show that the draft failed to say it. Each reader is started with `--setting-sources "" --strict-mcp-config --tools ""`, a replaced system prompt, auto memory off, and an empty working directory. These flags were checked on Claude Code 2.1.302 (2026-10-18). `--safe-mode` still let the reader see environment sections such as the user's email, and the empty `--setting-sources` alone still loaded the project's auto memory. The empty `--setting-sources` is observed behavior rather than documented, which is why the probe runs before every target.

`PERSONA_READ_CMD` swaps in another CLI and `PERSONA_READ_MODEL` changes the reader model. The isolation is tested only with Claude Code.

## Why every revision is counted

Revising in answer to criticism tends to add hedges and claims. In one study of an LLM writing loop where a manager sent drafts back, revised drafts used 53% more hedging words per 1,000 words ([Loop-Back Authority in LLM Agent Teams](https://arxiv.org/abs/2609.14767), §4.2). After each revision, `drift_count.py` compares the full draft with the previous round:

```bash
python3 ~/.claude/skills/persona-read-loop/scripts/drift_count.py r0.md r1.md \
  --dossier sources.md
```

```json
{
  "new_numbers": ["40%"],
  "new_superlatives": [],
  "new_hedges": ["arguably", "may"],
  "removed_hedges": [],
  "new_names": ["LangChain"],
  "new_katakana": []
}
```

It exits 1 when anything other than `new_katakana` is listed. Numbers and names that appear in the previous round or in the evidence file (`--dossier`) count as already said. The vocabulary covers English and Japanese.

## Limits

- The three readers are one model, so they are not independent samples and can agree for the same wrong reason.
- No study the author found (as of 2026-10-18) measures whether simulated readers stall where real readers stall.
- A reader model does not know features released after its cutoff. Its "I don't know this term" about them is not a reason to revise, and the skill says so.

## Related work

[persona-review](https://github.com/pvliesdonk/claude-plugins/tree/main/plugins/persona-review) in pvliesdonk/claude-plugins also has persona readers restate a document and checks the restatement against what the author intended, with verifiers on top. persona-read-loop differs in two ways: readers run as separate processes with the author's setup removed (persona-review runs them as subagents and withholds the intent instead), and each revision is counted for added numbers, superlatives and names, and hedges added or removed.

## More from the author

- **[claude-harness](https://github.com/shimo4228/claude-harness)**: the author's Claude Code harness, where this skill is maintained and from which this repository is synced.
- **[readme-writer](https://github.com/shimo4228/readme-writer)**: the README skill that uses the `readme` preset as its visitor read.
- **[shimo4228](https://github.com/shimo4228/shimo4228)**: the author's hub, with the other skills and long-running practice lines.

## License

MIT

<details>
<summary>For tools and AI assistants</summary>

persona-read-loop is an Agent Skill for Claude Code that runs a closed revision loop on a draft (an article or a README) with three LLM reader personas, for writers who want a cheap check of whether a draft gets its decision across before a human reads it. Readers run as isolated `claude -p` processes and answer in JSON; the writer revises only how the draft shows the author's decision, and every revision is counted for added numbers, superlatives, hedges and Latin-script names.

It exists because a reader that shares the writer's context cannot reveal what the draft fails to say, and because revising in answer to criticism drifts toward added hedges and claims. It is a pre-screen, not user research: the readers' evaluation is never an acceptance condition, and the loop stops on reasons (no new reason, only missing facts left, or three revisions), never on a score.

Canonical facts: MIT license; maintained by one author (@shimo4228); synced one way from the author's Claude Code harness by `scripts/sync-from-local.sh` (it never commits). Requirements: the Claude Code CLI and Python 3.11+ (stdlib only; pytest for the tests). Each round starts three `claude -p` processes with the reader model (default `sonnet`, `PERSONA_READ_MODEL`). Payload: `skills/persona-read-loop/SKILL.md` (the loop: pick, freeze, read, sort, revise and count, stop), `presets/article.md` (readers primary / inflow / practitioner; restatement matched as match / shift / missing against the author's judgment), `presets/readme.md` (readers user / inflow / skeptic; `would_try` and reasons), `scripts/read.sh` (one isolated reader, and `--probe`, which checks tools 0, MCP servers 0, user skills 0 and a NONE answer about skills, memory and CLAUDE.md), `scripts/drift_count.py` with its tests.

Example: `read.sh --probe` on Claude Code 2.1.302 (2026-10-18) printed tools 0, mcp_servers 0, user skills 0 (built-in 22), context NONE, and exited 0. With `--setting-sources ""` removed by a wrapper, it listed 89 user skills and quoted CLAUDE.md headings, and exited 1.

Links: [skills/persona-read-loop/SKILL.md](skills/persona-read-loop/SKILL.md) is the skill itself. Closest prior art: [pvliesdonk/claude-plugins persona-review](https://github.com/pvliesdonk/claude-plugins/tree/main/plugins/persona-review) (teach-back restatement and verifiers, subagent readers). Hedging evidence: [arXiv 2609.14767](https://arxiv.org/abs/2609.14767) §4.2.

</details>
