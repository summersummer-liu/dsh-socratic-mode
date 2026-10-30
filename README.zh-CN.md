# 苏格拉底学习模式（Socratic Learning Mode）

**English** | 中文 · [GitHub 仓库](https://github.com/summersummer-liu/dsh-socratic-mode) · MIT

给 [DeepSeek Harness](https://github.com/deepseek-ai) 加一个**可选的 Agent 预设**：每轮先给你一块真知识，再问**一个**邀请式问题——不讲课、不审问、不逼着你答。压力小、有情绪价值；他能讲清楚、能举例、能迁移之后，才换下一个知识点。

---

## 安装

1. 克隆仓库到本地：

   ```bash
   git clone https://github.com/summersummer-liu/dsh-socratic-mode.git
   ```

2. 让 DSH 的 Agent 装这个 bundle（它会调用 `plugin_manager`）：

   > 用 plugin_manager 安装 `dsh-socratic-mode` 这个目录的 bundle。

   等价于 `plugin_manager` → `action: install_bundle` → `target` 填克隆目录的绝对路径。

3. （可选）安装配套技能，让完整教学手册在任何会话都能用：

   ```bash
   mkdir -p ~/.dsh/skills && cp -r skills/socratic-tutor ~/.dsh/skills/
   ```

4. 打开 **设置 → Agent 预设**，在「自定义」里应该能看到「苏格拉底学习模式」（卡片正常、有图标）。点一下卡片即可设为新会话默认。

---

## 怎么用

1. 点左侧「新建会话」。
2. 在会话起始页的 **Agent 预设**控件里选「苏格拉底学习模式」（排在 Standard / PTC / Minimal / Cordis 之后）。
   *如果下拉里还没有它，按 F5 刷新页面即可，不需要重启应用。*
3. 直接抛主题，例如：

   | 想干什么 | 直接说 |
   |---|---|
   | 从零学一个概念 | 「教我通货膨胀，我基础很差」 |
   | 读材料 | 「用苏格拉底法帮我读懂这篇论文/这份讲义」，并把文件拖进会话 |
   | 检验自己 | 「考我文艺复兴，我已经看过两遍书了」 |
   | 带着困惑来 | 「我总觉得货币乘数讲不通，你来问问我」 |

4. 过程中的约定：
   - 正常回答就行，答得含糊他说得出来；
   - 卡住说「卡住了 / 给点提示」，他会按 类比 → 区分 → 半成品 → 完整解释 逐级给；
   - 想直接要答案说「直接告诉我」，他讲完会跟一个检验问题；
   - 想收工说「总结一下」，他会在工作区写一份 `学习笔记-<主题>-<日期>.md` 并交付。

> 现有会话不会变；这个模式只对**新建会话**生效，且会话中途不能切换预设。

---

## 组成

| 部件 | 位置 | 作用 |
|---|---|---|
| 预设 bundle | `dsh-socratic-mode/`（本仓库） | 往 Loader 里插入 `preset-socratic` 行，声明预设 |
| 预设身份 | `config.id = socratic` | 会话里保存的预设 id |
| 显示名 / 描述 | `苏格拉底学习模式` / 见 `cordis.patch.yml` | Hero 控件里看到的内容 |
| 教学法（每轮生效） | `cordis.patch.yml` → `persona.prefix`，1374 字 | 20 条硬规则，模型每一轮都看得见 |
| 教学法（按需加载） | `~/.dsh/skills/socratic-tutor/SKILL.md`，6151 字 | 知识块库、语气手册、问题阶梯、提示阶梯、掌握判定、笔记模板；源文件在 `skills/socratic-tutor/SKILL.md` |
| 显示资源 | `locale/en.json`、`locale/zh.json`、`icon.svg` | 插件页的标题、描述、图标 |

### 工具集（13 行）

保留：`persona`、`time-context`、`tool-fs`、`tool-fs-search`、`tool-pwsh`/`tool-bash`（按平台二选一）、`tool-web`、`skill-filesystem`、`tool-skill`、`tool-ask-user`、`tool-todo`、`present`、`compaction`（压缩组，含 `/compact`）。

**故意不含**：`agent-instructions`（本工作区 AGENTS.md 是 3D 建模工具链，与学习无关，会污染上下文）、计划模式、目标、定时任务、后台任务、子代理、工作流、插件管理——学习会话不修改系统、不并行开工，少一个入口就少一次分心。

---

## 设计要点

**两层结构**解决「又要强约束、又不能每轮都烧上下文」：persona 放每次都生效的硬规则（先给后问、每轮一块知识、语气与压力控制、隐性三关），技能放长操作手册（知识块库、六类问题模板、L1–L4 提示阶梯、语气手册、笔记模板、反模式清单），按需加载。

**20 条硬规则的核心（v2：先给后问 + 情绪价值 + 降压力）**：

- **先给后问**：每条回复 = 接住他一句 + 一小块真知识（关键区分 / 反直觉事实 / 例子数字 / 一句话结论 / 常见误区）+ 唯一一个邀请式问题；**连续两轮只问不给算失败**；
- 每轮中文 150–300 字，最多 400 字——比 v1 长，因为每轮要真的给出东西；
- 从直觉和经验问起，不从定义起步；发现矛盾不说「你错了」，把两句话并列让他自己修；
- **语气**：具体地看见他（引用原话 + 说清价值）、给安全感、用邀请句不用命令句、允许玩笑和自嘲；
- **压力控制**：每轮只问一个邀请式问题；每 4–6 轮一个无问轮；他说「讲讲吧」就给 200–400 字讲解并明说可以跳过；连续两轮答错只降难度不评判；不播报进度；
- 掌握三关是**隐性标准**：不宣布考试、不打分，他说懂了先信他；
- 请求分三档：「直接告诉我」→ ≤200 字解释 + 轻检验；「卡住了」→ 从提示阶梯 L1 起；「差不多吧」→ 先给半成品再给解释。

**问题阶梯**（技能里给了话术模板）：澄清 → 前提 → 理由 → 反例 → 推论 → 视角；同类连用不超过两次。

**为什么用 `tool-todo` 当知识地图**：一次只让一个知识点处于进行中，进度是可见的，也强制了「不跳步」。

---

## 调参记录

### v2（2026-10-30，按反馈：压力太大、缺情绪价值、每轮知识量太少）

| 维度 | v1 | v2 |
|---|---|---|
| 每轮结构 | 一句反馈 + 一个问句（只问，不给） | **先给后问**：接住一句 + 一块真知识 + 一个邀请式问题 |
| 回复长度 | 40–120 字，最多 200 | 150–300 字，最多 400 |
| 知识量 | 只有提问和提示 | 每轮至少一块：关键区分 / 反直觉事实 / 例子数字 / 一句话结论 / 常见误区 |
| 语气 | 不奉承、指出问题所在 | 具体地看见（引用原话 + 说清价值）、给安全感、邀请句、允许玩笑 |
| 压力 | 一次一问 + 三关判定 | 一次一问 + 每 4–6 轮无问轮 + 「讲讲吧」给讲解 + 隐性三关、不播报进度 |
| 失败判定 | 一轮多问 | 追加：连续两轮只问不给、追问不放、命令式语气、他累了还抛问题 |

想再调的话：

- 嫌还不够热闹 → persona 规则 9 的「每 4–6 轮无问轮」改成「每 3–4 轮」，或规则 20 的字数上限提到 500；
- 嫌讲得太多、压过他自己想 → 规则 2 的知识块改成「每两轮一块」，回复长度回到 120–200；
- 想要更夸张、更有故事感的文风 → 在 persona 规则 6 后加一句「允许适度夸张的比喻和故事感，但事实表述要准确」。

### v2.1（2026-10-30，独立探针复核后修两处「名义降压力、实际还在压」）

让另一个 agent 用 v2 的 persona + 技能跑三组对话（首轮 / 半推半就 / 说累了）。结论：已经落在「同伴」位置——每条都有一块可带走的知识、只问一个邀请式问题、接住具体状态。但抓到两处**结构性残留压力**：

1. 学习者说「差不多吧，你直接讲吧」，v2 仍按 L3 留空让他填，等于「说了没被听见」。
   → 改成：先接住态度（「行，不绕你了」），给 150–300 字**完整解释**，问题明确可跳过，**不留空**。
2. persona「先别考我 → 200–400 字讲解」与 SKILL「他累了就收」互相打架。
   → 拆开：「讲讲吧」给 200–400 字讲解；「累了 / 先别考我 / 今天不想学」直接收（一句带走 + 一个不用现在答的问题，或干脆不问）。
3. 附带：把「看见」扩展到他说累、说不想被问时（先看见状态再决定给什么）；反模式加「把半推半就当继续留空的理由」。

persona 1374 字、技能 6151 字，已重装。

## 修改

| 想改什么 | 改哪里 | 生效方式 |
|---|---|---|
| 教学法/语气/硬规则 | `cordis.patch.yml` 的 `persona.prefix` | 重新安装 bundle（见下），新会话生效 |
| 问题阶梯、提示阶梯、笔记模板 | `skills/socratic-tutor/SKILL.md` + `~/.dsh/skills/socratic-tutor/SKILL.md` | 技能每次加载都重读文件，改完下次加载即生效 |
| 工具集 | `cordis.patch.yml` 的 `plugins` 列表 | 重新安装 bundle |
| 在预设列表里的位置 | `config.order`（内置是 1–4） | 重新安装 bundle |

重新安装（bundle 以 link 方式装进 profile，装的就是本目录的文件；**改完 patch 必须重新安装**，Loader 不会自动重读补丁）：

```
plugin_manager  action: remove_bundle    target: dsh-socratic-mode
plugin_manager  action: install_bundle   target: <克隆目录的绝对路径>
```

已安装时 `install_bundle` 会报 `already-installed`，所以必须先 `remove_bundle`。

保存前先跑一遍结构校验：

```bash
npm install
npm run check
```

---

## 校验记录

已实测（2026-10-30）：

| 检查 | 结果 |
|---|---|
| `tools/check-bundle.cjs` | `ok: true`；1 个 insert 行、13 个子行、persona 1374 字、技能 6151 字（< 8192 截断阈值）；含 tool-todo 必填配置的防回归断言 |
| `plugin_manager install_bundle` | `application: applied`、`enabled: true`、`warnings: []`、pnpm exit 0 |
| profile 登记（本地开发安装） | `dependencies."dsh-socratic-mode": "link:D:/..."`；`dsh.profile.bundles` 末尾出现该 bundle；`node_modules/dsh-socratic-mode` 为 Junction |
| Loader 行 | `cordis_inspect_query`（Config）里 `include:preset-socratic` 存在，预设行从 4 个变 5 个 |
| 改完 persona 后重装 | `remove_bundle` → `install_bundle` 均 `applied`；`list_plugins` 里 `include:preset-socratic` 为 `enabled: true, fiberPhase: active`，与 4 个内置预设同状态 |
| 技能发现 | 写入 `~/.dsh/skills/socratic-tutor/SKILL.md` 后，会话技能目录实时出现 `socratic-tutor`（监听生效，无需重启） |
| 首次真实挂载 | **失败过**：`agent-preset/invalid: tool-todo … missing required value` → 补 `allowParallelInProgress: false` 后重装；详见下面「排错记录」 |

**未实测**（需要页面/真实会话）：

- 修复后设置页卡片是否恢复正常、`新建会话` 是否不再报错（需要你在页面上确认一次）；
- 用该预设**新建会话**后的实际教学行为。

---

## 行为复核（独立 agent 探针）

安装后另起独立 agent 做行为复核（只给 persona + 技能文本，让它扮演导师），第一轮抓到三处规则互相打架，都已修：

1. **开场 × 一次一问**：「开场先确认三件事」+「每条回复只问一个」= 2–3 轮问卷；学习者已自报主题/基础时无法同时满足。
   → 改成「开场只为补信息：已说过的不要重问，只问缺的那一项，最多两轮进入教学」。
2. **「立刻照做」× 提示阶梯**：「直接告诉我」该立刻讲还是先走阶梯没定义；「差不多吧/你讲吧」既是请求也是卡住信号，两条规则给相反动作。
   → 改成三档：明确要答案 → ≤200 字最少充分解释 + 检验问题；说卡住 → 从 L1 起；半推半就 → 先给 L3 半成品。
3. **元认知提问 × 一个问句**：每 3–5 轮的元认知问句会让那一轮出现两个问句。
   → 明确「元认知提问占当轮那一个问句，不额外再加」。

第一轮探针的输出质量也确认了方向：首轮只有 1 个问题、约 100 字、抓着学习者原话里的「东西」做澄清、用「只有你不买的那几样涨价」当反例；对「直接告诉我」给出 ≤200 字解释 + 复述检验问题，与规则一致。

## 排错记录：预设「加载失败」的真实原因（2026-10-30）

装完并把新任务默认值指向它之后，新建会话直接报错：

```
agent-preset/invalid: tool-todo (@deepseek-ai/dsh-tool-todo):
invalid config: - $allowParallelInProgress missing required value
```

原因：`@deepseek-ai/dsh-tool-todo` 的 `allowParallelInProgress` 是**必填、没有默认值**，我漏写了 `config`。预设的 13 个子行在挂载时逐个校验 Config，**任一子行失败 → 整个预设「加载失败」**（设置页卡片上就是这个红色标签），而默认值又指向它，于是新建会话必失败。

修法：显式给出 `allowParallelInProgress: false`（学习是串行的，一次只推进一个知识点），重装后恢复正常。

教训（下次写 bundle 必须记住）：

1. 子行配置不能靠猜——对照内置 `standard` 预设的**完整** `config` 抄，包括"看起来可有可无"的字段。
2. `install_bundle` 返回 `application: applied` 只说明**声明行**装上了；`config.plugins` 的子行能否挂载，要等真正有会话挂载时才校验。
3. 所以**预设不要在自己没被真实会话验证过之前就设成默认值**——先新建一次会话确认能开，再设默认。
4. `tools/check-bundle.cjs` 现在把必填配置也纳入断言（tool-todo 那条），改 patch 后先跑它。

## 卸载

1. `plugin_manager` → `action: remove_bundle` → `target: dsh-socratic-mode`
2. 删技能：`Remove-Item "$env:USERPROFILE\.dsh\skills\socratic-tutor" -Recurse`
3. 可选：删本目录

---

## 边界

- 预设只在**新建会话**时选择，中途不能切换；已有会话不受影响。
- 学习笔记写到会话的工作目录。
- 它不是搜索器也不是题库：目标是他能讲、能举、能迁移；要标准答案可以直接要。
- 技能装在**用户级**技能根（`~/.dsh/skills`），所以任何工作目录、任何预设的会话都能加载它；换机器或删目录时要单独复制一次。

---

## License

MIT — 见 [LICENSE](LICENSE)。
