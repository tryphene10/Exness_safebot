param([Parameter(Mandatory=$true)][string]$InputJson)
$ErrorActionPreference='Stop'
# Schema: [{"candidate":"EUR-A","runs":[{"score":12.3,"admissible":true}, ...]}]
# Scores must come from measured MT5 runs, including centre and actual neighbours.
$groups=Get-Content -LiteralPath $InputJson -Raw | ConvertFrom-Json
$ranked=foreach($group in $groups) {
    $runs=@($group.runs)
    if($runs.Count -lt 3) { throw "At least centre and two measured neighbours required: $($group.candidate)" }
    foreach($run in $runs) {
        if($null -eq $run.score -or $run.admissible -isnot [bool]) { throw 'Missing numeric score or boolean admissible' }
        $value=[double]$run.score
        if([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw 'Non-finite score' }
    }
    $values=@($runs | ForEach-Object { [double]$_.score } | Sort-Object)
    $mean=($values | Measure-Object -Average).Average
    $variance=0.0
    foreach($value in $values) { $variance+=($value-$mean)*($value-$mean) }
    $sd=[Math]::Sqrt($variance/$values.Count)
    $middle=[int][Math]::Floor($values.Count/2)
    $median=if($values.Count%2) { $values[$middle] } else { ($values[$middle-1]+$values[$middle])/2 }
    $failure=@($runs | Where-Object { -not $_.admissible }).Count/$runs.Count
    [pscustomobject]@{Candidate=$group.candidate; Runs=$runs.Count; Median=$median; StdDev=$sd; FailureFraction=$failure; RobustScore=$median-$sd-40*$failure}
}
$ranked | Sort-Object RobustScore -Descending
