[CmdletBinding()]
param(
    [string]$Installation = 'C:\Program Files\MetaTrader 5',
    [string]$DataPath = 'C:\Users\Rufus\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [ValidateSet('BREAKOUT_ONLY','SPRING_ONLY','COMBINED')]
    [string[]]$Scenario = @('BREAKOUT_ONLY','SPRING_ONLY','COMBINED'),
    [datetime]$From = '2021-01-01',
    [datetime]$To = '2026-01-01',
    [double]$CommissionPerLot = 0,
    [switch]$ZeroCommissionAccount,
    [int]$TimeoutMinutes = 60
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $projectRoot "backtests\$runId"
$expertRoot = Join-Path $DataPath 'MQL5\Experts\SafeBotAudit'
$testerProfiles = Join-Path $DataPath 'MQL5\Profiles\Tester'
$terminal = Join-Path $Installation 'terminal64.exe'
$editor = Join-Path $Installation 'MetaEditor64.exe'

if($CommissionPerLot -eq 0 -and -not $ZeroCommissionAccount) {
    throw 'CommissionPerLot=0 is only permitted with -ZeroCommissionAccount. For Exness RAW, pass the real round-trip commission per lot.'
}
if($To -le $From) { throw 'To must be later than From.' }
foreach($path in @($terminal,$editor,(Join-Path $projectRoot 'ExnessSafeBot.mq5'),(Join-Path $projectRoot 'Include\SafeBotCore.mqh'))) {
    if(-not (Test-Path -LiteralPath $path)) { throw "Required path not found: $path" }
}
$active = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object Path -EQ $terminal
if($active) { throw "Refusing to reuse a running trading terminal (PID $($active.Id)). Close it before this tester-only batch." }

New-Item -ItemType Directory -Path $runRoot,$expertRoot,(Join-Path $expertRoot 'Include'),$testerProfiles -Force | Out-Null
$compileLog = Join-Path $runRoot 'compile-ExnessSafeBot.log'
$source = Join-Path $projectRoot 'ExnessSafeBot.mq5'
$compile = Start-Process -FilePath $editor -ArgumentList @('/compile:"'+$source+'"','/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
if(-not $compile.WaitForExit(120000)) { throw "Compilation timed out (PID $($compile.Id))." }
$compileResult = Select-String -LiteralPath $compileLog -Pattern '^Result:' | Select-Object -Last 1
if(-not $compileResult -or $compileResult.Line -notmatch 'Result: 0 errors, 0 warnings') {
    throw "Compilation failed or emitted warnings. See $compileLog"
}
$binary = Join-Path $projectRoot 'ExnessSafeBot.ex5'
if(-not (Test-Path -LiteralPath $binary)) { throw 'Compilation did not produce ExnessSafeBot.ex5.' }
Copy-Item -LiteralPath $source,$binary -Destination $expertRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'Include\SafeBotCore.mqh') -Destination (Join-Path $expertRoot 'Include\SafeBotCore.mqh') -Force

$buildEvidence = foreach($path in @($source,(Join-Path $projectRoot 'Include\SafeBotCore.mqh'),$binary,
    (Join-Path $expertRoot 'ExnessSafeBot.mq5'),(Join-Path $expertRoot 'Include\SafeBotCore.mqh'),(Join-Path $expertRoot 'ExnessSafeBot.ex5'))) {
    $item = Get-Item -LiteralPath $path
    [pscustomobject]@{ Path=$item.FullName; Length=$item.Length; LastWriteTime=$item.LastWriteTime.ToString('o'); SHA256=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
}
$buildEvidence | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'build-evidence.json') -Encoding UTF8
if($buildEvidence[0].SHA256 -ne $buildEvidence[3].SHA256 -or
   $buildEvidence[1].SHA256 -ne $buildEvidence[4].SHA256 -or
   $buildEvidence[2].SHA256 -ne $buildEvidence[5].SHA256) { throw 'Deployed source/include/binary hashes do not match the current build.' }

$profiles = @{
    BREAKOUT_ONLY = 'EURUSD_breakout_only.set'
    SPRING_ONLY   = 'EURUSD_spring_only.set'
    COMBINED      = 'EURUSD_conservative.set'
}
$summaries = @()
foreach($name in $Scenario) {
    $started = Get-Date
    $slug = $name.ToLowerInvariant()
    $caseRoot = Join-Path $runRoot $slug
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $profilePath = Join-Path $projectRoot ('profiles\'+$profiles[$name])
    $setName = "SafeBot-$runId-$slug.set"
    $setTarget = Join-Path $testerProfiles $setName
    $setLines = @(Get-Content -LiteralPath $profilePath)
    $setLines = @($setLines | ForEach-Object {
        if($_ -match '^InpExpectedScenario=') { "InpExpectedScenario=$name" }
        elseif($_ -match '^InpCommissionPerLot=') { 'InpCommissionPerLot='+$CommissionPerLot.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture) }
        else { $_ }
    })
    if(-not ($setLines -match '^InpExpectedScenario=')) { $setLines += "InpExpectedScenario=$name" }
    $setLines | Set-Content -LiteralPath $setTarget -Encoding ASCII
    Copy-Item -LiteralPath $setTarget -Destination (Join-Path $caseRoot $setName)

    $reportBase = Join-Path $caseRoot "report-$runId-$slug"
    $config = Join-Path $caseRoot "tester-$slug.ini"
    @(
        '[Common]','KeepPrivate=0','NewsEnable=0',
        '[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0',
        '[Tester]','Expert=SafeBotAudit\ExnessSafeBot.ex5',"ExpertParameters=$setName",'Symbol=EURUSD','Period=H1',
        'Optimization=0','Model=4',"FromDate=$($From.ToString('yyyy.MM.dd'))","ToDate=$($To.ToString('yyyy.MM.dd'))",'ForwardMode=0',
        'Deposit=1000','Currency=USD','ProfitInPips=0','Leverage=100','ExecutionMode=0',
        'UseLocal=1','UseRemote=0','UseCloud=0','Visual=0',"Report=$reportBase",'ReplaceReport=0','ShutdownTerminal=1'
    ) | Set-Content -LiteralPath $config -Encoding ASCII

    $knownLogs = @{}
    Get-ChildItem -LiteralPath (Join-Path $DataPath 'Tester') -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
        ForEach-Object { $knownLogs[$_.FullName] = @(Get-Content -LiteralPath $_.FullName).Count }
    $run = Start-Process -FilePath $terminal -ArgumentList @('/config:"'+$config+'"') -WindowStyle Hidden -PassThru
    if(-not $run.WaitForExit($TimeoutMinutes*60000)) { Stop-Process -Id $run.Id -Force; throw "Backtest $name timed out after $TimeoutMinutes minutes." }

    $fresh = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath (Join-Path $DataPath 'Tester') -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -GE $started | ForEach-Object {
            $skip = if($knownLogs.ContainsKey($_.FullName)) { $knownLogs[$_.FullName] } else { 0 }
            @(Get-Content -LiteralPath $_.FullName | Select-Object -Skip $skip) | ForEach-Object { [void]$fresh.Add($_) }
        }
    $logPath = Join-Path $caseRoot "tester-$slug.log"
    $fresh | Set-Content -LiteralPath $logPath -Encoding UTF8
    $text = $fresh -join "`n"
    if($text -match 'history check timeout|no history data, stop testing') { throw "$name stopped because broker history was unavailable. No synthetic fallback was accepted. See $logPath" }
    if($text -match 'no real ticks|every tick generation used|ticks generated') { throw "$name fell back to generated ticks. Result rejected. See $logPath" }
    $fingerprint = [regex]::Match($text,'fingerprint=([0-9A-F]{16})').Groups[1].Value
    if(-not $fingerprint) { throw "$name has no configuration fingerprint in its fresh tester log." }
    if($text -notmatch "scenario=$name expected=$name") { throw "$name engine assertion is absent or mismatched." }
    $testerLine = [regex]::Matches($text,'SB4 \| TESTER \|[^\r\n]+') | Select-Object -Last 1
    if(-not $testerLine -or $testerLine.Value -notmatch 'snapshots=([1-9][0-9]*)') { throw "$name has no positive snapshot count in OnTester." }
    if($text -notmatch 'real ticks') { throw "$name log does not positively attest real-tick use; result rejected." }
    $reports = @(Get-ChildItem -LiteralPath $caseRoot -File | Where-Object Extension -In '.htm','.html','.xml')
    if($reports.Count -eq 0) { throw "$name produced no distinct tester report under $caseRoot." }
    $auditFiles = @(Get-ChildItem -LiteralPath (Join-Path $DataPath 'Tester') -Recurse -File -Filter "*-$fingerprint-*.csv" -ErrorAction SilentlyContinue | Where-Object LastWriteTime -GE $started)
    foreach($audit in $auditFiles) { Copy-Item -LiteralPath $audit.FullName -Destination (Join-Path $caseRoot $audit.Name) }
    $summaries += [pscustomobject]@{Scenario=$name; Fingerprint=$fingerprint; Started=$started.ToString('o'); Report=$reports[0].FullName; AuditFiles=$auditFiles.Count; Tester=$testerLine.Value}
}
$summaries | Export-Csv -LiteralPath (Join-Path $runRoot 'baseline-summary.csv') -NoTypeInformation -Encoding UTF8
$summaries | Format-Table -AutoSize
Write-Output "Verified tester-only artifacts: $runRoot"
