# Changelog

## 1.0.0 — 2026-10-30

First public release.

- Agent preset `socratic` (display name 「苏格拉底学习模式」) with 13 child rows, insertable through a bundle patch.
- Give-then-ask protocol: one small piece of real knowledge per turn, then exactly one invitational question.
- 20 persona hard rules covering tone, pressure control, hidden mastery checks, and request triage.
- Companion skill `socratic-tutor`: knowledge-block library, six-question ladder, four hint levels, tone manual with good/bad examples, study-note template, 16 anti-patterns.
- Pressure controls: a question-free turn every 4–6 turns,「讲讲吧」lectures, and a graceful exit when the learner is tired.
- `tools/check-bundle.cjs`: structural validation, plus a regression guard for required-without-default plugin configs (the `tool-todo` trap that broke 0.9.x during development).
- Study notes delivered through `present` at session end.
