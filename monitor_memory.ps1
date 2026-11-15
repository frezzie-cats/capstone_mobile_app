$PackageName = "com.example.capstone_mobile_app"

# Confirm that ADB is available and a device is connected.
adb get-state
if ($LASTEXITCODE -ne 0) {
    Write-Host "No ADB device detected. Check your USB connection and USB debugging."
    exit
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CsvPath = ".\memory_log_$timestamp.csv"

Write-Host "Monitoring memory for: $PackageName"
Write-Host "Output file: $CsvPath"
Write-Host "Sampling interval: approximately 1 second"
Write-Host "Press Ctrl+C to stop monitoring."
Write-Host ""

while ($true) {
    $sampleTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    # Find the app's current process ID.
    $pidText = (& adb shell pidof $PackageName 2>$null | Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($pidText)) {
        $appPid = ""
        $pssKb = $null
        $pssMb = $null
        $status = "App process not found"
    }
    else {
        $appPid = ($pidText -split '\s+')[0]

        # Retrieve Android memory information for the app.
        $memInfo = (& adb shell dumpsys meminfo $appPid 2>$null | Out-String)

        if ($memInfo -match '(?m)^\s*TOTAL\s+PSS:\s*([\d,]+)') {
            $pssKb = [long](($Matches[1]) -replace ',', '')
            $pssMb = [math]::Round($pssKb / 1024, 2)
            $status = "OK"
        }
        else {
            $pssKb = $null
            $pssMb = $null
            $status = "PSS value not found"
        }
    }

    $record = [PSCustomObject]@{
        Timestamp  = $sampleTime
        PID        = $appPid
        TotalPSS_KB = $pssKb
        TotalPSS_MB = $pssMb
        Status     = $status
    }

    $record | Export-Csv -Path $CsvPath -NoTypeInformation -Append

    if ($status -eq "OK") {
        Write-Host "$sampleTime | PID: $appPid | PSS: $pssMb MB"
    }
    else {
        Write-Host "$sampleTime | $status"
    }

    Start-Sleep -Seconds 1
}