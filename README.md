# dsh-socratic-mode

**A Socratic learning mode for [DeepSeek Harness](https://github.com/deepseek-ai) — it gives you one small piece of real knowledge, then asks one invitational question. No lectures, no interrogation.**

![check](https://github.com/summersummer-liu/dsh-socratic-mode/actions/workflows/check.yml/badge.svg)

[中文说明](README.zh-CN.md) · MIT License

---

## Why this exists

Most “AI tutor” prompts have the same failure mode: they either lecture at you, or they quiz you forever — question after question with nothing given back. Both feel like pressure, and after ten minutes you stop wanting to chat.

This mode flips the order: **give first, then ask** (先给后问). Every turn hands you one concrete piece of knowledge — a key distinction, a counter-intuitive fact, a number, a one-line takeaway, or a common misconception — and then invites you to think one step further. Questions are invitations, not interrogations. You can always say “just tell me”, “just talk”, or “I'm tired”, and the mode adapts.

## What you get

- A new agent preset — **苏格拉底学习模式** (Socratic Learning Mode) — on the New Session picker.
- A knowledge block every turn, so each reply is worth reading even when you don't answer.
- Exactly one question per turn, always optional.
- Pressure controls: a question-free turn every 4–6 turns, hidden mastery checks instead of “exams”, and a graceful exit when you are tired.
- Warm register: specific appreciation (quoting your own words), safety when you're stuck, invitations (“what do you think?”) instead of commands (“please answer”).
- A **study note** in your workspace at the end: knowledge map, key distinctions, your own best sentences, misconceptions, and three self-test questions.

## Requirements

- DeepSeek Harness desktop / web, `dsh >= 0.2.1-rc.3`
- Node.js `>= 20` (only for the repo's check script and development)

## Install

1. Clone the repository somewhere local:

   ```bash
   git clone https://github.com/summersummer-liu/dsh-socratic-mode.git
   ```

2. Ask your DSH agent to install the bundle — say:

   > 用 plugin_manager 安装 `dsh-socratic-mode` 这个目录的 bundle。

   The agent calls `plugin_manager` with `action: install_bundle` and `target` set to the absolute path of the cloned directory. The bundle resolves the shipped Harness packages from your installation; it declares no dependencies of its own.

3. *(Optional)* install the companion skill, which is useful even outside this preset:

   ```bash
   mkdir -p ~/.dsh/skills
   cp -r skills/socratic-tutor ~/.dsh/skills/
   ```

4. Open **Settings → Agent Presets**. The mode appears under **Custom** and should show a healthy card (title, description, icon). Click the card to make it the default for new sessions, or just pick it per session.

## Use

Create a new session, pick **苏格拉底学习模式**, and say what you want to learn:

| Goal | Say |
|---|---|
| learn a concept from scratch | 「教我通货膨胀，我基础很差」 |
| study a document | 「用苏格拉底法帮我读这份讲义」 (drop the file into the chat) |
| verify what you know | 「考我文艺复兴，我看过两遍书了」 |
| untangle a confusion | 「我总觉得货币乘数讲不通，你来问问我」 |

During the session:

| You want | Say |
|---|---|
| the answer now | 「直接告诉我」 |
| a hint instead | 「卡住了 / 给点提示」 |
| a lecture with no questions | 「讲讲吧」 |
| to stop | 「累了 / 先别考我」 |
| to wrap up | 「总结一下」 → writes a study note |

## What's inside

| Part | File | Purpose |
|---|---|---|
| Preset declaration | `cordis.patch.yml` | Inserts `preset-socratic` into the agent-preset roster |
| Teaching method (always on) | `cordis.patch.yml` → `persona.prefix` | 20 hard rules: give-then-ask, tone, pressure control, hidden mastery checks |
| Teaching method (on demand) | `skills/socratic-tutor/SKILL.md` | Knowledge-block library, six-question ladder, four hint levels, tone manual, note template, anti-patterns |
| Display resources | `locale/en.json`, `locale/zh.json`, `icon.svg` | Bundle card title, description and icon |

The preset mounts 13 child rows: `persona`, `time-context`, `tool-fs`, `tool-fs-search`, `tool-bash`/`tool-pwsh`, `tool-web`, `skill-filesystem`, `tool-skill`, `tool-ask-user`, `tool-todo`, `present`, and a compaction group. It deliberately **omits** plan mode, goals, schedules, background jobs, subagents, workflows and the plugin manager: a learning session should not carry system-modification tools.

## Design

Two layers keep the constraints strong without spending context on them every turn:

1. **Persona** (~1.4 KB, visible every turn) — the rules that must beat the model's default habits.
2. **Skill** (~6 KB, loaded once) — the full playbook: knowledge-block templates, question ladder, hint ladder, tone manual, study-note structure.

The core loop:

```
接住他一句 (optional)  +  一块真知识 (required)  +  一个邀请式问题 (exactly one)
```

- **Give:** one of five knowledge-block types — key distinction, counter-intuitive fact, concrete example/number, one-line takeaway, common misconception.
- **Ask:** invitation only (“你会怎么想?” “想不想试试更刁的?”), never commands (“请回答”).
- **Never:** two questions in one turn, two give-less turns in a row, judging “right/wrong”, broadcasting progress, or pushing questions when the learner is tired.

Mastery is checked silently — explain it, give your own example, transfer to a new case — and never announced as a test.

## Customize

| Want | Edit |
|---|---|
| teacher persona and rules | `cordis.patch.yml` → `persona.prefix`, then reinstall the bundle |
| question ladder, hint ladder, tone manual, note template | `skills/socratic-tutor/SKILL.md` (re-read on every load, no reinstall needed) |
| tool set | `cordis.patch.yml` → `plugins` |
| roster position | `config.order` (built-ins use 1–4) |

Validate before reinstalling:

```bash
npm install
npm run check
```

Reinstalling an installed bundle needs two steps — `plugin_manager` → `remove_bundle`, then `install_bundle` (installing over an existing bundle reports `already-installed`).

## Troubleshooting

**The preset card shows 加载失败 (failed to load) and new sessions refuse to start.**
Child rows are validated when the preset mounts; one invalid child fails the whole preset. The toast or card diagnostic names the row. Run `npm run check`. A known trap: `@deepseek-ai/dsh-tool-todo` requires `allowParallelInProgress` with no default — omitting it fails the preset. The check script asserts it.

**The mode doesn't appear in the picker.**
Refresh the page. Confirm the bundle is listed in the profile, and that the preset row is active (`plugin_manager` → `list_plugins` → `preset-socratic`).

**The tutor slides back into quizzing.**
Reload the skill and re-read rule 1 and rule 15 in `persona.prefix`: give-then-ask, and “直接讲吧” means deliver a complete explanation, not another fill-in-the-blank.

## Uninstall

1. `plugin_manager` → `action: remove_bundle` → `target: dsh-socratic-mode`
2. Remove the skill: `rm -r ~/.dsh/skills/socratic-tutor`
3. Delete the cloned directory

## License

MIT — see [LICENSE](LICENSE).
