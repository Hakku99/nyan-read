param(
  [string]$Adb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe",
  [string]$OutputPath = '.dart_tool/reader-gesture-device.log'
)
$ErrorActionPreference = 'Stop'
$gestureAdb = $Adb
& $gestureAdb shell am start -n com.example.nyan_read/.MainActivity | Out-Null
$gestureSent = @{}
$gestureDeadline = [DateTime]::UtcNow.AddMinutes(6)
while ([DateTime]::UtcNow -lt $gestureDeadline) {
  Start-Sleep -Seconds 2
  $gesturePid = (& $gestureAdb shell pidof com.example.nyan_read).Trim()
  if (!$gesturePid) { throw 'Validation process stopped' }
  $gestureLines = & $gestureAdb logcat -d -v raw "--pid=$gesturePid" -s flutter:I
  $gestureLines | Set-Content -Encoding utf8 $OutputPath
  $gestureEvents = @($gestureLines | Where-Object { $_.StartsWith('NYAN_TURN ') } | ForEach-Object { $_.Substring(10) | ConvertFrom-Json })
  foreach ($gestureEvent in $gestureEvents) {
    $gestureKey = "$($gestureEvent.event)/$($gestureEvent.format)/$($gestureEvent.scene)"
    if ($gestureSent.ContainsKey($gestureKey)) { continue }
    $gestureSent[$gestureKey] = $true
    if ($gestureEvent.event -eq 'native-ready') {
      & $gestureAdb shell input swipe 900 1200 900 1200 650 | Out-Null
      Start-Sleep -Milliseconds 400
      & $gestureAdb shell uiautomator dump /data/local/tmp/gesture-selection.xml | Out-Null
      $gestureSelectionUi = & $gestureAdb shell cat /data/local/tmp/gesture-selection.xml
      if ($gestureSelectionUi -notmatch 'Copy') { throw 'Native long press did not show selection actions' }
      Write-Output "Native long-press selection passed: $($gestureEvent.format)"
      & $gestureAdb shell input tap 100 1200 | Out-Null
      Start-Sleep -Milliseconds 500
      & $gestureAdb shell input swipe 900 1200 180 1200 220 | Out-Null
      Write-Output "Native forward sent: $($gestureEvent.format)"
    } elseif ($gestureEvent.event -eq 'native-forward') {
      & $gestureAdb shell input swipe 180 1200 900 1200 220 | Out-Null
      Write-Output "Native back sent: $($gestureEvent.format)"
    } elseif ($gestureEvent.event -in @('inputs','native-complete','saved','restored')) {
      $gestureEvent | ConvertTo-Json -Compress -Depth 8 | Write-Output
    } elseif ($gestureEvent.event -eq 'error') {
      $gestureEvent | ConvertTo-Json -Compress -Depth 8 | Write-Output
      throw 'Gesture validation failed'
    } elseif ($gestureEvent.event -eq 'complete') { Write-Output 'Device acceptance complete'; exit 0 }
  }
}
throw 'Gesture validation timed out'
