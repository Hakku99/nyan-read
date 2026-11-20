param(
    [string]$Adb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe",
    [string]$Device = 'emulator-5554',
    [int]$Rounds = 3,
    [string]$OutputDirectory = '.dart_tool/reader_baseline/after-fix'
)

$ErrorActionPreference = 'Stop'
$package = 'com.example.nyan_read'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
for ($round = 1; $round -le $Rounds; $round++) {
    & $Adb -s $Device shell am force-stop $package | Out-Null
    & $Adb -s $Device shell am start -n "$package/.MainActivity" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not start the profile application.' }
    Write-Output "Round $round started."
    $deadline = [DateTime]::UtcNow.AddMinutes(8)
    $completed = $false
    $reported = 0
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 5
        $readerProcessId = (& $Adb -s $Device shell pidof $package).Trim()
        if (!$readerProcessId) { throw "Profile process exited in round $round." }
        $lines = & $Adb -s $Device logcat -d -v raw "--pid=$readerProcessId" -s flutter:I
        $events = @($lines | Where-Object { $_.StartsWith('NYAN_PROFILE ') } |
            ForEach-Object { $_.Substring(13) | ConvertFrom-Json })
        $scenarios = @($events | Where-Object { $_.event -in @('scenario', 'scenario-error') })
        if ($scenarios.Count -gt $reported) {
            foreach ($scenario in $scenarios[$reported..($scenarios.Count - 1)]) {
                Write-Output "Round $round $($scenario.source)/$($scenario.format)/$($scenario.mode): $($scenario.event), $($scenario.overBudgetFrames)/$($scenario.frames) over budget."
            }
            $reported = $scenarios.Count
        }
        $completion = $events | Where-Object event -eq 'complete'
        if ($completion -or ($events | Where-Object event -eq 'error')) {
            $lines | Set-Content -Encoding utf8 (Join-Path $OutputDirectory "profile-$round.log")
            ConvertTo-Json -InputObject $events -Depth 12 |
                Set-Content -Encoding utf8 (Join-Path $OutputDirectory "profile-$round.json")
            if (!$completion -or $completion.failedScenarios -ne 0) {
                throw "Profile round $round failed; inspect its recorded events."
            }
            $completed = $true
            Write-Output "Round $round complete: $($scenarios.Count) scenarios."
            break
        }
    }
    if (!$completed) { throw "Profile round $round timed out." }
}
