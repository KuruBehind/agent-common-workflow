# prune-dev-processes.ps1 — 오래 남은 개발 프로세스를 자동 정리 (Windows)
#
# 배경:
#   에이전트 세션이 QA 브라우저·vite/flutter 웹 서버를 띄우고 닫지 않은 채 끝나면 프로세스가 계속 남는다.
#   gcloud 토큰 발급이 인증 만료로 멈춘 채 하루 넘게 남기도 한다. 2026-11-27 한 머신에서
#   이런 잔여물이 커밋 메모리 약 27GB 를 차지해 99% 에 도달했다.
#
# 대상과 기준 (실행 시간만 본다):
#   qa-browser   임시 프로필(%TEMP% 아래 user-data-dir)로 뜬 chrome / chrome-headless-shell  > 12시간
#                — 사용자 본인 Chrome(기본 프로필)은 절대 대상 아님
#   dev-server   vite·next dev·webpack serve·`flutter run -d web-server`                    > 24시간
#   gcloud-hang  gcloud 명령(python gcloud.py) — 인증 만료로 멈춘 것                         > 15분
#   감싸는 래퍼(qa 스크립트 node·npx·cmd·flutter 의 dart)까지 하위 프로세스째 끈다.
#
# "부모 세션이 끝났는가"는 쓰지 않는다: Git Bash 는 명령을 넘기며 부모 프로세스가 먼저 사라지는 일이 있어,
# 살아 있는 세션의 flutter 서버도 고아처럼 보인다(2026-11-27 실측). 시간 기준만 안전하다.
#
# 사용법:
#   powershell -NoProfile -ExecutionPolicy Bypass -File prune-dev-processes.ps1 -DryRun
#   powershell -NoProfile -ExecutionPolicy Bypass -File prune-dev-processes.ps1 [-QaBrowserHours 12] [-DevServerHours 24] [-GcloudMinutes 15]
#   정기 실행 등록은 README 「개발 프로세스 자동 정리」 절.

param([switch]$DryRun, [double]$QaBrowserHours = 12, [double]$DevServerHours = 24, [double]$GcloudMinutes = 15)

$now = Get-Date
$all = @(Get-CimInstance Win32_Process)
$byId = @{}; foreach ($p in $all) { $byId[[int]$p.ProcessId] = $p }
$kids = @{}; foreach ($p in $all) { $k = [int]$p.ParentProcessId; if (!$kids[$k]) { $kids[$k] = @() }; $kids[$k] += $p }
$limitMin = @{ 'qa-browser' = $QaBrowserHours * 60; 'dev-server' = $DevServerHours * 60; 'gcloud-hang' = $GcloudMinutes }

function Get-Parent($p) {
  $par = $byId[[int]$p.ParentProcessId]
  # PID 재사용: 부모가 자식보다 늦게 생겼으면 진짜 부모가 아니다
  if ($par -and $par.CreationDate -le $p.CreationDate) { return $par }
  return $null
}

function Get-Kind($p) {
  $c = [string]$p.CommandLine
  if ($p.Name -match '^(chrome|chrome-headless-shell)\.exe$' -and $c -notmatch '--type=') {
    if ($c -match 'user-data-dir="?[^"]*[\\/](Temp|tmp)[\\/]') { return 'qa-browser' }
    return $null
  }
  if ($p.Name -eq 'node.exe' -and $c -match '[\\/]vite[\\/]bin[\\/]vite\.js|next(\.js)?"? dev|webpack(-cli)?"? serve|webpack-dev-server') { return 'dev-server' }
  if ($p.Name -eq 'dart.exe' -and $c -match 'flutter_tools\.snapshot"? run .*-d web-server') { return 'dev-server' }
  if ($p.Name -eq 'python.exe' -and $c -match 'gcloud\.py') { return 'gcloud-hang' }
  return $null
}

# 같은 작업을 감싸는 래퍼까지 올라간 단위 루트 (bash 등 셸은 다른 작업과 공유할 수 있어 올라가지 않는다)
function Get-UnitRoot($p) {
  $root = $p
  for ($i = 0; $i -lt 6; $i++) {
    $par = Get-Parent $root
    if (!$par) { break }
    $pc = [string]$par.CommandLine
    if ($par.Name -match '^(node|cmd|dart)\.exe$' -and $pc -match 'qa-browser|playwright|\.mjs|\.cjs|npx-cli\.js|vite|flutter|gcloud') { $root = $par } else { break }
  }
  return $root
}

function Get-Tree($id) {
  $out = @()
  foreach ($k in @($kids[[int]$id])) { if ($k -and $k.CreationDate -ge $byId[[int]$id].CreationDate) { $out += Get-Tree $k.ProcessId; $out += $k } }
  return $out
}

$plans = @{}
foreach ($p in $all) {
  $kind = Get-Kind $p
  if (!$kind) { continue }
  $ageMin = ($now - $p.CreationDate).TotalMinutes
  if ($ageMin -le $limitMin[$kind]) { continue }
  $root = Get-UnitRoot $p
  if (!$plans.ContainsKey([int]$root.ProcessId)) { $plans[[int]$root.ProcessId] = [pscustomobject]@{ Root = $root; Kind = $kind; Target = $p; AgeMin = $ageMin } }
}

# 다른 단위의 하위에 이미 포함된 루트는 중복 제거
$covered = @{}
foreach ($pl in $plans.Values) { foreach ($t in (Get-Tree $pl.Root.ProcessId)) { $covered[[int]$t.ProcessId] = $true } }

$pv = @{}; Get-Process | ForEach-Object { $pv[[int]$_.Id] = $_.PrivateMemorySize64 }
$freed = 0; $count = 0
"== prune-dev-processes $($now.ToString('yyyy-MM-dd HH:mm:ss')) dry_run=$([bool]$DryRun)"
foreach ($pl in ($plans.Values | Sort-Object Kind)) {
  if ($covered[[int]$pl.Root.ProcessId]) { continue }
  $tree = @(Get-Tree $pl.Root.ProcessId) + @($pl.Root)
  $mem = ($tree | ForEach-Object { $pv[[int]$_.ProcessId] } | Measure-Object -Sum).Sum
  $c = [string]$pl.Target.CommandLine
  $label = if ($c -match 'user-data-dir="?([^"]+?)"?( --|$)') { Split-Path $Matches[1] -Leaf }
           elseif ($c -match 'worktrees[\\/]([^\\/"]+)') { $Matches[1] }
           elseif ($c -match 'gcloud\.py"? (.{0,60})') { "gcloud $($Matches[1])" }
           else { $c.Substring(0, [math]::Min(80, $c.Length)) }
  $port = if ($c -match '--(web-)?port[ =](\d+)') { " port=$($Matches[2])" } else { '' }
  $line = "{0,-11} {1,6:N2}GB n={2,-3} start={3:MM-dd HH:mm} age={4:N1}h {5}{6}" -f $pl.Kind, ($mem / 1GB), $tree.Count, $pl.Target.CreationDate, ($pl.AgeMin / 60), $label, $port
  if ($DryRun) { "WOULD $line" }
  else {
    foreach ($x in $tree) { try { Stop-Process -Id $x.ProcessId -Force -EA Stop } catch {} }
    "KILL  $line"
  }
  $freed += $mem; $count++
}
"result: units=$count memory={0:N2}GB" -f ($freed / 1GB)
