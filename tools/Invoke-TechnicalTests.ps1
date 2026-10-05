param([string]$Installation='C:/Program Files/MetaTrader 5',[string]$ValidationRoot='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$validationRoot=if($ValidationRoot) { $ValidationRoot } else { Join-Path $projectRoot '.validation/terminal-v431' }
$expertRoot=Join-Path $validationRoot 'MQL5/Experts/SafeBotAudit'
New-Item -ItemType Directory -Path $expertRoot,(Join-Path $expertRoot 'Include'),(Join-Path $expertRoot 'tests'),(Join-Path $validationRoot 'MQL5/Scripts') -Force | Out-Null
foreach($name in @('terminal64.exe','metaeditor64.exe','metatester64.exe')) {
    $target=Join-Path $validationRoot $name
    if(-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $Installation $name) -Destination $target }
}
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object Path -EQ (Join-Path $validationRoot 'terminal64.exe')) { throw 'The isolated validation terminal is already running.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'ExnessSafeBot.mq5') -Destination $expertRoot
Copy-Item -LiteralPath (Join-Path $projectRoot 'Include/SafeBotCore.mqh') -Destination (Join-Path $expertRoot 'Include')
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Filter '*.mq5' | Copy-Item -Destination (Join-Path $expertRoot 'tests')
$sources=@((Join-Path $expertRoot 'ExnessSafeBot.mq5'))+@(Get-ChildItem -LiteralPath (Join-Path $expertRoot 'tests') -Filter '*.mq5' | ForEach-Object FullName)
foreach($source in $sources) {
    $log=Join-Path $projectRoot ('.validation/compile-'+[IO.Path]::GetFileName($source)+'.log')
    $run=Start-Process -FilePath (Join-Path $validationRoot 'metaeditor64.exe') -ArgumentList @('/portable',('/compile:"'+$source+'"'),('/log:"'+$log+'"')) -WindowStyle Hidden -PassThru
    if(-not $run.WaitForExit(30000)) { throw 'Compilation timed out.' }
    $results=@(Select-String -LiteralPath $log -Pattern '^Result:')
    if($results.Count -eq 0 -or @($results | Where-Object Line -NotMatch 'Result: 0 errors, 0 warnings').Count -gt 0) { Get-Content -LiteralPath $log; throw 'Compilation failed or warnings present.' }
    Write-Output ('Compilation OK: '+$source)
}
$suite=@(
    @('SafeBotCoreTests','SB3-test-results.txt'),
    @('SafeBotSignalTests','SB3-signal-test-results.txt'),
    @('SafeBotBufferTests','SB3-buffer-tests.txt'),
    @('SafeBotExecutionTests','SB4-execution-tests.txt'),
    @('SafeBotRestartWrite','SB4-restart-write.txt'),
    @('SafeBotRestartRead','SB4-restart-read.txt'),
    @('SafeBotDataFixture','SB3-data-integration.txt')
)
$summary=@(('Technical tests V4.31 - '+(Get-Date -Format o)),'Compilation: 0 errors, 0 warnings')
foreach($case in $suite) {
    Copy-Item -LiteralPath (Join-Path $expertRoot ('tests/'+$case[0]+'.ex5')) -Destination (Join-Path $validationRoot 'MQL5/Scripts')
    $config=Join-Path $validationRoot 'technical-run.ini'
    @('[Common]','Login=0','KeepPrivate=0','NewsEnable=0','[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','[StartUp]',('Script='+$case[0]),'Symbol=EURUSD','Period=H1','ShutdownTerminal=1') | Set-Content -LiteralPath $config -Encoding ASCII
    $started=Get-Date
    $run=Start-Process -FilePath (Join-Path $validationRoot 'terminal64.exe') -ArgumentList @('/portable',('/config:"'+$config+'"')) -WindowStyle Hidden -PassThru
    if(-not $run.WaitForExit(90000)) {
        Stop-Process -Id $run.Id -Force -ErrorAction SilentlyContinue
        throw ('Test timed out, isolated PID '+$run.Id+': '+$case[0])
    }
    $resultFile=Join-Path $validationRoot ('MQL5/Files/'+$case[1])
    if(-not (Test-Path -LiteralPath $resultFile) -or (Get-Item -LiteralPath $resultFile).LastWriteTime -lt $started) { throw ('Missing fresh test result: '+$case[0]) }
    $result=(Get-Content -LiteralPath $resultFile -Raw).Trim()
    Write-Output ($case[0]+': '+$result)
    if($result -notmatch 'PASS=[1-9][0-9]*' -or ($case[0] -ne 'SafeBotDataFixture' -and $result -notmatch 'FAIL=0\b')) { throw ('Test failed: '+$case[0]) }
    $summary+=($case[0]+': '+$result)
}
$summary+='Execution tests use a simulated broker; data integration uses synthetic history. No live orders.'
$summary | Set-Content -LiteralPath (Join-Path $projectRoot 'tests/results/v431-technical-summary.txt') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $expertRoot 'ExnessSafeBot.ex5') -Destination $projectRoot
