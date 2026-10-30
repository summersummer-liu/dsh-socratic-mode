# 发布 dsh-socratic-mode 到 GitHub（本机 github.com 的 git 直连不通，用 REST API；PowerShell 版）
# 用法：$env:GH_TOKEN=<token>; powershell -File _publish-github.ps1
# token 只从环境变量读取，绝不打印。
$ErrorActionPreference = 'Stop'
$Owner = 'summersummer-liu'
$Name  = 'dsh-socratic-mode'
$RepoDir = (Split-Path -Parent $PSScriptRoot)
$Branch = 'main'
$Description = 'Socratic learning mode for DeepSeek Harness - a tutoring agent preset that gives one piece of real knowledge then asks one invitational question per turn. 先给再问，不讲课不审问。'
$Homepage = "https://github.com/$Owner/$Name"
$Topics = @('dsh-plugin','deepseek-harness','agent-preset','socratic','tutor','learning','education')
$token = $env:GH_TOKEN
if (-not $token) { Write-Output 'GH_TOKEN is required'; exit 1 }

function Invoke-Gh {
  param([string]$Method, [string]$Path, $Body)
  $headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'dsh-socratic-release'
    'X-GitHub-Api-Version' = '2022-11-28'
  }
  $uri = "https://api.github.com$Path"
  try {
    if ($null -eq $Body) {
      return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
    $json = $Body | ConvertTo-Json -Depth 20 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $bytes -ContentType 'application/json; charset=utf-8'
  } catch {
    $status = 0
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    $detail = $_.ErrorDetails.Message
    if (-not $detail) { $detail = $_.Exception.Message }
    $e = New-Object System.Exception "$Method $Path -> HTTP ${status}: $detail"
    $e.Data['status'] = $status
    throw $e
  }
}

# 收集待上传文件（文本；排除 .git / node_modules / 日志 / 系统文件）
$skipDirs = @('.git','node_modules','.folder-janitor')
$skipFiles = @('.DS_Store','Thumbs.db')
$files = Get-ChildItem -LiteralPath $RepoDir -Recurse -File | Where-Object {
  $rel = $_.FullName.Substring($RepoDir.Length + 1).Replace('\','/')
  if ($rel -like '.github/*') { $bad = $true }
  $parts = $rel.Split('/')
  $bad = $false
  if ($rel -like '.github/*') { $bad = $true }
  foreach ($part in $parts) { if ($skipDirs -contains $part) { $bad = $true } }
  if ($skipFiles -contains $_.Name -or $_.Name.EndsWith('.log')) { $bad = $true }
  (-not $bad)
} | ForEach-Object {
  [pscustomobject]@{
    Rel  = $_.FullName.Substring($RepoDir.Length + 1).Replace('\','/')
    Full = $_.FullName
  }
} | Sort-Object Rel
Write-Output "publishing $($files.Count) files"

# 1. 仓库：存在则复用，不存在则创建
$repoExists = $true
try { $repo = Invoke-Gh -Method Get -Path "/repos/$Owner/$Name" } catch { if ($_.Data['status'] -eq 404) { $repoExists = $false } else { throw } }
if (-not $repoExists) {
  $repo = Invoke-Gh -Method Post -Path '/user/repos' -Body @{
    name = $Name; description = $Description; homepage = $Homepage
    private = $false; has_issues = $true; has_projects = $false; has_wiki = $false
  }
  Write-Output "created repo $($repo.full_name)"
} else {
  Write-Output "repo exists $($repo.full_name)"
}

# 2. 空仓库先用 Contents API 初始化 main（否则 blobs API 返回 409）
$head = $null
try { $head = Invoke-Gh -Method Get -Path "/repos/$Owner/$Name/git/ref/heads/$Branch" } catch { if ($_.Data['status'] -ne 404 -and $_.Data['status'] -ne 409) { throw } }
if ($null -eq $head) {
  $readme = $files | Where-Object { $_.Rel -eq 'README.md' } | Select-Object -First 1
  if (-not $readme) { Write-Output 'README.md required'; exit 1 }
  $content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($readme.Full))
  $null = Invoke-Gh -Method Put -Path "/repos/$Owner/$Name/contents/README.md" -Body @{
    message = 'chore: initialize repository'; content = $content; branch = $Branch
  }
  $head = Invoke-Gh -Method Get -Path "/repos/$Owner/$Name/git/ref/heads/$Branch"
  Write-Output "initialized $Branch at $($head.object.sha)"
}
$parentSha = $head.object.sha

# 3. 全量 blobs -> tree -> commit -> 更新 ref
$treeItems = @()
foreach ($f in $files) {
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Full))
  $blob = Invoke-Gh -Method Post -Path "/repos/$Owner/$Name/git/blobs" -Body @{ content = $b64; encoding = 'base64' }
  $treeItems += @{ path = $f.Rel; mode = '100644'; type = 'blob'; sha = $blob.sha }
  Write-Output "blob $($f.Rel)"
}
$tree = Invoke-Gh -Method Post -Path "/repos/$Owner/$Name/git/trees" -Body @{ tree = $treeItems }
$commit = Invoke-Gh -Method Post -Path "/repos/$Owner/$Name/git/commits" -Body @{
  message = "feat: dsh-socratic-mode 1.0.0 - Socratic learning mode for DeepSeek Harness`n`nGive-then-ask tutor preset: one knowledge block + one invitational question per turn.`nPersona (20 rules), companion skill, knowledge-block library, pressure controls,`nstudy notes, bundle check script, docs and CI."
  tree = $tree.sha
  parents = @($parentSha)
}
$ref = Invoke-Gh -Method Patch -Path "/repos/$Owner/$Name/git/refs/heads/$Branch" -Body @{ sha = $commit.sha; force = $true }
Write-Output "pushed $($commit.sha) -> $($ref.ref)"

# 4. topics（失败不致命）
try {
  $null = Invoke-Gh -Method Put -Path "/repos/$Owner/$Name/topics" -Body @{ names = $Topics }
  Write-Output 'topics set'
} catch {
  Write-Output "topics skipped: $($_.Exception.Message)"
}

# 5. 验证
$readmeInfo = Invoke-Gh -Method Get -Path "/repos/$Owner/$Name/contents/README.md"
$treeCheck = Invoke-Gh -Method Get -Path "/repos/$Owner/$Name/git/trees/$Branch`?recursive=1"
$uploaded = @($treeCheck.tree | Where-Object { $_.type -eq 'blob' })
Write-Output ('RESULT ' + (@{
  repo = "https://github.com/$Owner/$Name"
  commit = $commit.sha
  filesInRepo = $uploaded.Count
  readmeBytes = $readmeInfo.size
} | ConvertTo-Json -Compress))
