
# ================================
# Server Configuration Script
# ================================

# --- File explorer Settings ---
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced HideFileExt "0"
Stop-Process -Name Explorer -force

# sleep
Start-Sleep -Seconds 2

# --- Control panel Settings ---
If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1


# --- Disable IE Enhanced Security Configuration ---
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0

# --- Timezone Setting ---
Set-TimeZone -TimeZone "Central European Standard Time"

# --- Power Settings ---
# Set High Performance Power Plan
powercfg /S "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0


# --- Event Log Size Settings ---
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security" -Name "MaxSize" -Value 268435456
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System" -Name "MaxSize" -Value 67108864
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application" -Name "MaxSize" -Value 67108864

# --- Disk Timeout ---
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -Value 190

# --- Create Dump Folder ---
New-Item -Path "C:\Windows\Dump" -ItemType Directory -Force

# --- Pagefile Settings ---
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value "C:\pagefile.sys 0 0"

# --- Remote Desktop Settings ---
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fInheritMaxDisconnectionTime" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fInheritMaxIdleTime" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxDisconnectionTime" -Value 259200000
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 259200000




# --- Registry Hardening ---
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole\AppCompat" -Name "RequireIntegrityActivationAuthenticationLevel" -PropertyType DWord -Value 0 -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -PropertyType DWord -Value 1 -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Name "RunAsPPL" -PropertyType DWord -Value 1 -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\LSA" -Name "TokenLeakDetectDelaySecs" -PropertyType DWord -Value 30 -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -PropertyType DWord -Value 0 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "Negotiate" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet" -Name "EnableActiveProbing" -Value 0

# --- Disable Services ---
$servicesToEnable = @(
    "AVCTP", "BDESVC", "BTAGService", "bthserv", "Browser", "DiagTrack", "dmwappushservice",
    "DPS", "WdiServiceHost", "WdiSystemHost", "MapsBroker", "fhsvc", "lfsvc", "GraphicsPerfSvc",
    "irmon", "SharedAccess", "iphlpsvc", "DiagHub", "wlidsvc", "AppVClient",
    "smphost", "NcbService", "CscService", "ssh-agent", "WpcMonSvc", "SEMgrSvc",
    "PhoneSvc", "WPDBusEnum", "Spooler", "wercplsupport", "PcaSvc", "QWAVE", "RmSvc", "RemoteRegistry",
    "RemoteAccess", "seclogon", "SensorDataService", "SensorService", "SensrSvc", "SharedPCAccountManager",
    "ShellHWDetection", "SCardSvr", "ScDeviceEnum", "SmartCardRemovalPolicy", "SACSVR", "StillImage",
    "TapiSrv", "UEVAgentService", "WalletService", "WarpJITSvc", "Audiosrv", "AudioEndpointBuilder",
    "WbioSrvc", "FrameServer", "WerSvc", "Wia", "wisvc", "LicenseManagerSvc", "WMPNetworkSvc",
    "icssvc", "PushToInstall", "WSearch"
)


foreach ($svc in $servicesToDisable) {
    Get-Service -Name $svc -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
}

# --- Delete Scheduled Tasks ---
$tasksToDelete = @(
    "\Google", "\Feed Synchronization", "\OneDrive", "\Adobe Flash", "\Microsoft\Edge",
    "\Microsoft\Windows\DiskCleanup"
)
foreach ($task in $tasksToDelete) {
    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
}