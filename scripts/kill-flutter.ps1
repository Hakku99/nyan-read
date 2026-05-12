$processes = "java.exe", "dart.exe", "flutter.exe"

foreach ($proc in $processes) {
    Stop-Process -Name $proc.Replace(".exe", "") -Force -ErrorAction SilentlyContinue
}

Write-Host "All locks cleared. Ready for flutter clean." -ForegroundColor Cyan