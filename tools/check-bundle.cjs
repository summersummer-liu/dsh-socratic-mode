// 重新校验 bundle 的 YAML 结构、技能 frontmatter 与发布元数据（改完 patch / SKILL.md 后跑一次）。
// 只做语法与结构检查，不求值 `!!js`、不安装、不改任何文件。
//
//   npm run check        （或在仓库根目录：node tools/check-bundle.cjs）
//
const fs = require('node:fs')
const path = require('node:path')

const bundleDir = path.resolve(__dirname, '..')
const patchPath = path.join(bundleDir, 'cordis.patch.yml')
const skillPath = path.join(bundleDir, 'skills', 'socratic-tutor', 'SKILL.md')

// 依赖 `yaml` 包：本地 npm install 后可用；在 dsh profile 里直接跑时回退到 profile 的 node_modules。
const candidates = [
  'yaml',
  path.join(process.env.DSH_PROFILE_DIR || '', 'node_modules', 'yaml'),
  path.join(bundleDir, 'node_modules', 'yaml'),
]
const YAML = candidates.map((p) => { try { return require(p) } catch { return null } }).find(Boolean)
if (!YAML) {
  console.error('FAIL: 找不到 yaml 包，先运行 `npm install`（或在一个装有 yaml 的 dsh profile 里运行）')
  process.exit(1)
}

const problems = []
const fail = (msg) => problems.push(msg)

// 发布元数据：名字与 bundle 声明必须和仓库一致。
const pkg = JSON.parse(fs.readFileSync(path.join(bundleDir, 'package.json'), 'utf8'))
if (pkg.name !== 'dsh-socratic-mode') fail('package.json name 应为 dsh-socratic-mode')
if (pkg.dsh?.bundle?.patch !== './cordis.patch.yml') fail('package.json dsh.bundle.patch 应为 ./cordis.patch.yml')
if (!fs.existsSync(patchPath)) fail('cordis.patch.yml 缺失')

// `!!js` 是 Loader 表达式，普通 YAML 解析器不支持；替换成同位置普通标量，
// 只校验语法和缩进，不求值。
const raw = fs.readFileSync(patchPath, 'utf8')
const doc = YAML.parse(raw.replace(/!!js[ \t]+[^\n]*/g, 'JS_EXPR'))

if (!Array.isArray(doc) || doc.length !== 1) fail('patch 顶层应为长度 1 的数组')
const row = doc?.[0]?.insert?.[0]
if (!row) fail('缺少 insert[0]')
if (row?.id !== 'preset-socratic') fail('preset row id 应为 preset-socratic')
if (row?.name !== '@deepseek-ai/dsh-agent-preset') fail('preset row name 错误')

const cfg = row?.config ?? {}
if (cfg.id !== 'socratic') fail('config.id 应为 socratic')
if (!cfg.name) fail('缺少显示名')
if (!cfg.description) fail('缺少描述')
if (!Number.isInteger(cfg.order)) fail('order 缺失')
if (!Array.isArray(cfg.plugins) || cfg.plugins.length === 0) fail('plugins 为空')

const ids = (cfg.plugins ?? []).map((p) => p.id)
const dup = ids.filter((id, i) => ids.indexOf(id) !== i)
if (dup.length) fail('重复的子行 id: ' + dup.join(', '))

const persona = (cfg.plugins ?? []).find((p) => p.id === 'persona')
const prefix = persona?.config?.prefix ?? ''
if (!prefix.includes('{{model}}')) fail('persona prefix 缺少 {{model}} 占位符')
if (prefix.length < 400) fail('persona prefix 过短（硬规则应写在 persona 里）')

const skill = fs.readFileSync(skillPath, 'utf8')
const fm = skill.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/)
if (!fm) fail('SKILL.md 缺少 YAML frontmatter')
const meta = fm ? YAML.parse(fm[1]) : {}
if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(meta.name ?? '')) fail('技能 name 不是 kebab-case')
if (!meta.description) fail('技能缺少 description')
if (skill.length > 8192) fail(`技能正文 ${skill.length} 字符，超过建议的 8192（会被 tool-result-pruner 截断）`)

// 已知必填配置的防回归断言：漏掉这些字段会让整个预设加载失败
// （agent-preset/invalid: … missing required value），而不是退回默认值。
const todoRow = (cfg.plugins ?? []).find((p) => p.id === 'tool-todo')
if (todoRow && typeof todoRow.config?.allowParallelInProgress !== 'boolean') {
  fail('tool-todo 必须显式配置 allowParallelInProgress（boolean，无默认值）')
}

for (const p of problems) console.error('FAIL: ' + p)
console.log(JSON.stringify({
  ok: problems.length === 0,
  preset: {
    row: row?.id,
    id: cfg.id,
    name: cfg.name,
    order: cfg.order,
    rows: cfg.plugins?.length,
    plugins: ids,
    personaChars: prefix.length,
  },
  skill: {
    name: meta.name,
    chars: skill.length,
    bytes: Buffer.byteLength(skill, 'utf8'),
  },
}, null, 2))
process.exit(problems.length ? 1 : 0)
