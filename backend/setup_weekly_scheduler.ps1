# PowerShell Script to Set Up Weekly Automated TxDOT Estimate Audit
# Runs every Monday at 8:00 AM on your Windows PC

$taskName = "Amestx_Weekly_TxDOT_Estimate_Audit"
$action = New-ScheduledTaskAction -Execute "python.exe" -Argument "C:\Users\fibrg\Desktop\Amestx Estimator App\backend\verify_txdot_estimates.py" -WorkingDirectory "C:\Users\fibrg\Desktop\Amestx Estimator App\backend"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8:00AM
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Runs weekly audit for Amestx TxDOT letting estimates against official TxDOT links." -Force

Write-Host "✅ Successfully scheduled weekly TxDOT estimate audit task!" -ForegroundColor Green
Write-Host "The audit will run automatically every Monday at 8:00 AM." -ForegroundColor Yellow
