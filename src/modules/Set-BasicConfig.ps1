<#
.SYNOPSIS
    This script give windows servers a baseline configuration and ajusts settings for performance and security.
.DESCRIPTION
    This script configures various settings on Windows Server operating systems to enhance performance, security, and usability.
    It disables unnecessary features and services, removes unwanted applications, and applies security hardening measures.
    The script is intended to be run with Administrator privileges.
.PARAMETER None
    This script does not take any parameters.
.EXAMPLE
    .\configure_all_servers.ps1
.NOTES
    Author: Xander Waeghe
    Date Created: Dec 2025
#>

#TODO: https://community.spiceworks.com/t/remote-desktop-allow-admin-to-login-without-user-confirmation/278614

$errorActionPreference = "SilentlyContinue"

#
# --- Backup Current Registry Settings ---
#region
try {
    Write-Host "> Backing up current Registry settings..." -ForegroundColor DarkGray
    $backupPathHKCU = "C:\RegistryBackup_HKCU_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    reg export "HKCU" "$backupPathHKCU" /y | Out-Null
    $backupPathHKLM = "C:\RegistryBackup_HKLM_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    reg export "HKLM" "$backupPathHKLM" /y | Out-Null
    Write-Host "> Backed up Registry to C:\RegistryBackup_...reg" -ForegroundColor Green
}
catch {
    Write-Host "> Could not create backup directory C:\RegistryBackup." -ForegroundColor Red
    Start-Sleep -Seconds 2
    & "$PSScriptRoot\..\main.ps1"
}

#endregion

#
# --- Getting System Information ---
#region
$osVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
#endregion


#
# --- Quality Of Life Changes ---
#region
# Creating all needed paths
Write-Host "> Creating necessary registry paths..." -ForegroundColor DarkGray
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" | Out-Null
New-Item -Path "HKCU:\Software\Classes\CLSID\" | Out-Null
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" | Out-Null
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" | Out-Null
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" | Out-Null
New-Item -Path "HKCU:\Control Panel\Accessibility\StickyKeys" | Out-Null
New-Item -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" | Out-Null
New-Item -Path "HKCU:\Control Panel\Accessibility\FilterKeys" | Out-Null
New-Item -Path "HKCU:\Control Panel\Desktop" | Out-Null
Write-Host "> Necessary registry paths created." -ForegroundColor Green

Write-Host "> Applying Quality of Life registry settings..." -ForegroundColor DarkGray

# Show File Extensions, Hidden Files, Full Path in Title Bar
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name "FullPath" -Value 1 -Force | Out-Null
Write-Host "> Setting File Explorer to show file extensions, hidden files and full path in title bar." -ForegroundColor Green

# Don't show recent files, Frequent folders
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Force | Out-Null
Write-Host "> Disabling recent files and frequent folders in File Explorer." -ForegroundColor Green

# Open File Explorer to This PC
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Force | Out-Null
Write-Host "> Setting File Explorer to open to This PC." -ForegroundColor Green

# Rright click to old style
Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -Value "" -Force | Out-Null
Write-Host "> Setting old style right click context menu." -ForegroundColor Green

# Control Panel to All Items View
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1 -Force | Out-Null
Write-Host "> Setting Control Panel to All Items view." -ForegroundColor Green

# Num Lock on Login
Set-ItemProperty -Path 'Registry::HKU\.DEFAULT\Control Panel\Keyboard' -Name "InitialKeyboardIndicators" -Value "2" -Force | Out-Null
Write-Host "> Setting Num Lock to ON at login." -ForegroundColor Green

# Align Taskbar to Left
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Force | Out-Null
Write-Host "> Aligning Taskbar to Left." -ForegroundColor Green

# Display only search icon
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Force | Out-Null
Write-Host "> Setting Taskbar search to display only search icon." -ForegroundColor Green

# Disable Taskbar Chat
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Force | Out-Null
Write-Host "> Disabling Taskbar Chat." -ForegroundColor Green

# Disable Search Highlights
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -Name "IsDynamicSearchBoxEnabled" -Value 0 -Force | Out-Null
Write-Host "> Disabling Search Highlights." -ForegroundColor Green

# Disable Tips, Tricks and Suggestions
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Value 0 -Force | Out-Null
Write-Host "> Disabling Tips, Tricks and Suggestions." -ForegroundColor Green

# Disable Lock Screen Ads
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled" -Value 0 -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Force | Out-Null
Write-Host "> Disabling Lock Screen Ads." -ForegroundColor Green

# Disable Cortana
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "AllowCortana" -Value 0 -Force | Out-Null
Write-Host "> Disabling Cortana." -ForegroundColor Green

# Disable Sticky keys
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value 506 -Force | Out-Null
Write-Host "> Disabling Sticky Keys." -ForegroundColor Green

# Disable Toggle keys
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value 506 -Force | Out-Null    
Write-Host "> Disabling Toggle Keys." -ForegroundColor Green

# Disable Filter keys
Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\FilterKeys" -Name "Flags" -Value 506 -Force | Out-Null
Write-Host "> Disabling Filter Keys." -ForegroundColor Green

#  Set Menu Delay to 0
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0 -Force | Out-Null
Write-Host "> Setting Menu Show Delay to 0." -ForegroundColor Green

#Disable Search suggestions in File Explorer
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Force | Out-Null
Write-Host "> Disabling Search suggestions in File Explorer." -ForegroundColor Green



if ($osVersion -like "*Server*") {
    Write-Host "> Detected Windows Server OS. Applying server-specific QoL settings..." -ForegroundColor DarkGray

    # Disable Taskbar Widgets
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Force | Out-Null
    Write-Host "> Disabling Taskbar Widgets." -ForegroundColor Green

    # Disable Windows server manager auto launch at login
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -Value 1 -Force | Out-Null
    Write-Host "> Disabling Server Manager auto launch at login." -ForegroundColor Green

    # Disable Azure Arc Sys Tray Icon
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name "AzureConnectedMachineAgent" -Value ([byte[]](0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)) -Force | Out-Null

}
else {
    # Disable Task View Button
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Force | Out-Null
    Write-Host "> Disabling Task View Button." -ForegroundColor Green

    # Disable Game Bar
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Force | Out-Null
    Write-Host "> Disabling Gamebar." -ForegroundColor Green

    # Disable Windows Welciome Experience
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -Force | Out-Null

}

# Disable Advertising ID
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Force | Out-Null
Write-Host "> Disabling Advertising ID." -ForegroundColor Green

# Disable activity history
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Force | Out-Null



# restart explorer to apply file explorer settings
Stop-Process -Name Explorer -force
Write-Host "> Restarting Explorer to apply File Explorer settings." -ForegroundColor Green
Start-Sleep -Seconds 2
#endregion

#
# --- System Configuration ---
#region
Write-Host "> Applying System configuration settings..." -ForegroundColor DarkGray

# Disable IE Enhanced Security Configuration
if ($osVersion -like "*Server*") {
    Write-Host "> Detected Windows Server OS. Applying server-specific system settings..." -ForegroundColor DarkGray

    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Type DWord -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -Type DWord -Force | Out-Null
    Write-Host "> Disabling IE Enhanced Security Configuration." -ForegroundColor Green
}

# Timezone Setting
Set-TimeZone -Id "Romance Standard Time"
Write-Host "> Setting Timezone to Romance Standard Time." -ForegroundColor Green

# Enable High Performance Power Plan
powercfg /S "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
powercfg -change -monitor-timeout-ac 0
powercfg -change -monitor-timeout-dc 0
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0
powercfg -change -hibernate-timeout-ac 0
powercfg -change -hibernate-timeout-dc 0
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0
Write-Host "> Enabling High Performance Power Plan and disabling sleep/hibernate." -ForegroundColor Green

# Disk Timeout
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -Value 190 | Out-Null
Write-Host "> Setting Disk Timeout to 190 seconds." -ForegroundColor Green

# Create Dump Folder
New-Item -Path "C:\Windows\Dump" -ItemType Directory -Force | Out-Null
Write-Host "> Creating Dump folder at C:\Windows\Dump." -ForegroundColor Green

# Pagefile Settings
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value "C:\pagefile.sys 0 0" | Out-Null
Write-Host "> Setting Pagefile to System Managed Size on C: drive." -ForegroundColor Green

# Visable Visual Effects Settings
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 | Out-Null
Write-Host "> Setting Visual Effects to 'Adjust for best appearance'." -ForegroundColor Green

# Event Log Size Settings
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security" -Name "MaxSize" -Value 268435456 | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System" -Name "MaxSize" -Value 67108864 | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application" -Name "MaxSize" -Value 67108864 | Out-Null
Write-Host "> Setting Event Log sizes." -ForegroundColor Green

# disable IPv6
Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 | Out-Null
Write-Host "> Disabling IPv6 on all network adapters." -ForegroundColor Green
#endregion

#
# --- Remote Desktop Settings ---
#region
Write-Host "> Applying Remote Desktop settings..." -ForegroundColor DarkGray

# Enable RDP
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Write-Host "> Enabling Remote Desktop." -ForegroundColor Green

# Configure RDP Session Timeouts
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fInheritMaxDisconnectionTime" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fInheritMaxIdleTime" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxDisconnectionTime" -Value 259200000
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MaxIdleTime" -Value 259200000
Write-Host "> Configuring RDP session timeouts." -ForegroundColor Green

# Configure RDP Encryption Level
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MinEncryptionLevel" -Value 3
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value 1
Write-Host "> Setting RDP Encryption Level to High." -ForegroundColor Green

# Configure RDP Clipboard & Drive Redirection
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fDisableClip" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fDisableCdm" -Value 0
Write-Host "> Enabling RDP Clipboard and Drive Redirection." -ForegroundColor Green

# Enable Network Level Authentication for RDP
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' 1 -Force
Write-Host "> Enabling Network Level Authentication for RDP." -ForegroundColor Green
#endregion

#
# --- Disable Unnecessary Features & Services ---
Write-Host "> Disabling Unnecessary Features and Services..." -ForegroundColor DarkGray

#region
$DisabledFeatures = @(
    # Core / legacy / networking
    "Printing-XPSServices-Features"
    "TelnetClient"
    "TFTP"
    "TIFFIFilter"
    "VirtualMachinePlatform"
    "Client-ProjFS"
    "SimpleTCP"
    "WorkFolders-Client"
    "SMB1Protocol"
    "SMB1Protocol-Client"
    "SMB1Protocol-Server"
    "SmbDirect"
    "PeerDist"
    "QWAVE"
    "SNMP"
    "WMISnmpProvider"
    "MSRDC-Infrastructure"
    "RemoteAssistance"
    "ResumeKeyFilter"
    "SetupAndBootEventCollection"

    # IIS / Web / WCF / WAS
    "WCF-HTTP-Activation"
    "WCF-NonHTTP-Activation"
    "WCF-Services45"
    "WCF-HTTP-Activation45"
    "WCF-TCP-Activation45"
    "WCF-Pipe-Activation45"
    "WCF-MSMQ-Activation45"
    "IIS-WebServerRole"
    "IIS-WebServer"
    "IIS-CommonHttpFeatures"
    "IIS-HttpErrors"
    "IIS-HttpRedirect"
    "IIS-ApplicationDevelopment"
    "IIS-Security"
    "IIS-RequestFiltering"
    "IIS-NetFxExtensibility"
    "IIS-NetFxExtensibility45"
    "IIS-HealthAndDiagnostics"
    "IIS-HttpLogging"
    "IIS-LoggingLibraries"
    "IIS-RequestMonitor"
    "IIS-HttpTracing"
    "IIS-URLAuthorization"
    "IIS-IPSecurity"
    "IIS-Performance"
    "IIS-HttpCompressionDynamic"
    "IIS-HttpCompressionStatic"
    "IIS-WebServerManagementTools"
    "IIS-ManagementConsole"
    "IIS-ManagementScriptingTools"
    "IIS-ManagementService"
    "IIS-IIS6ManagementCompatibility"
    "IIS-Metabase"
    "IIS-WMICompatibility"
    "IIS-LegacyScripts"
    "IIS-FTPServer"
    "IIS-FTPSvc"
    "IIS-FTPExtensibility"
    "IIS-StaticContent"
    "IIS-DefaultDocument"
    "IIS-DirectoryBrowsing"
    "IIS-WebDAV"
    "IIS-WebSockets"
    "IIS-ApplicationInit"
    "IIS-ISAPIFilter"
    "IIS-ISAPIExtensions"
    "IIS-ASPNET"
    "IIS-ASPNET45"
    "IIS-ASP"
    "IIS-CGI"
    "IIS-ServerSideIncludes"
    "IIS-CustomLogging"
    "IIS-BasicAuthentication"
    "IIS-WindowsAuthentication"
    "IIS-DigestAuthentication"
    "IIS-ClientCertificateMappingAuthentication"
    "IIS-IISCertificateMappingAuthentication"
    "IIS-ODBCLogging"
    "IIS-CertProvider"
    "IIS-HostableWebCore"
    "WAS-WindowsActivationService"
    "WAS-ProcessModel"
    "WAS-NetFxEnvironment"
    "WAS-ConfigurationAPI"

    # MSMQ / Messaging
    "MSMQ"
    "MSMQ-Container"
    "MSMQ-DCOMProxy"
    "MSMQ-Server"
    "MSMQ-ADIntegration"
    "MSMQ-HTTP"
    "MSMQ-Multicast"
    "MSMQ-Triggers"

    # Hyper-V / Containers / Virtualization
    "Microsoft-Hyper-V-All"
    "Microsoft-Hyper-V"
    "Microsoft-Hyper-V-Tools-All"
    "Microsoft-Hyper-V-Management-PowerShell"
    "Microsoft-Hyper-V-Hypervisor"
    "Microsoft-Hyper-V-Services"
    "Microsoft-Hyper-V-Management-Clients"
    "HypervisorPlatform"
    "HyperV-KernelInt-VirtualDevice"
    "HyperV-Guest-KernelInt"
    "Containers"
    "Containers-HNS"
    "Containers-SDN"
    "Containers-DisposableClientVM"
    "Containers-Server-For-Application-Guard"

    # Printing / Media / UI
    "Printing-Foundation-Features"
    "Printing-Foundation-InternetPrinting-Client"
    "Printing-Foundation-LPDPrintService"
    "Printing-Foundation-LPRPortMonitor"
    "Printing-PrintToPDFServices-Features"
    "Printing-Client"
    "Printing-Client-Gui"
    "Printing-AdminTools-Collection"
    "MediaPlayback"
    "WindowsMediaPlayer"
    "Xps-Foundation-Xps-Viewer"
    "ServerMediaFoundation"
    "Microsoft-Windows-Printing-PremiumTools"

    # Identity / AD / Auth
    "DirectoryServices-ADAM"
    "DirectoryServices-ADAM-Client"
    "Windows-Identity-Foundation"
    "AuthManager"
    "HostGuardian"
    "HostGuardianService-Package"

    # Storage / clustering / fabric
    "DataCenterBridging"
    "EnhancedStorage"
    "FabricShieldedTools"
    "ShieldedVMToolsAdminPack"
    "SmbWitness"
    "MultipathIo"
    "Dedup-Core"
    "Storage-Replica"

    # Backup / monitoring / admin portals
    "WindowsServerBackup"
    "WindowsServerBackupSnapin"
    "SystemInsights"
    "SystemInsightsManagement"
    "SystemDataArchiver"
    "WindowsAdminCenterSetup"

    # Search / indexing
    "SearchEngine-Client-Package"
    "SearchEngine-Server-Package"

    # Legacy / compatibility
    "LegacyComponents"
    "DirectPlay"
    "CCFFilter"
    "OEM-Appliance-OOBE"
)

# Check if features are enabled before disabling
$enabledFeatures = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -eq 'Enabled' } | Select-Object -ExpandProperty FeatureName
foreach ($feature in $DisabledFeatures) {
    if ($enabledFeatures -contains $feature) {
        Write-Host "> Disabling feature: $feature" -ForegroundColor Green
        Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        Write-Host "> Skipping feature: $feature (not enabled)" -ForegroundColor Gray
    }
}
#endregion

#
# --- Disable Unnecessary Services ---
Write-Host "> Disabling Unnecessary Services..." -ForegroundColor DarkGray

#region
$SafeServicesToDisable = @(
    # --- Legacy / Deprecated ---
    "Browser"
    "RemoteRegistry"

    # --- Bluetooth (if no BT hardware) ---
    "AVCTP"
    "BTAGService"
    "bthserv"

    # --- Maps / Location / Sensors ---
    "MapsBroker"
    "lfsvc"
    "SensorDataService"
    "SensorService"
    "SensrSvc"

    # --- Offline Files / Backup ---
    "CscService"
    "fhsvc"

    # --- Consumer / Identity ---
    "wlidsvc"                 # Microsoft Account Sign-In
    "PhoneSvc"
    "WalletService"

    # --- App Virtualization / UE-V ---
    "AppVClient"
    "UEVAgentService"

    # --- Media Sharing ---
    "WMPNetworkSvc"

    # --- Smart Card (if not used) ---
    "SCardSvr"
    "ScDeviceEnum"
    "SmartCardRemovalPolicy"

    # --- Printing (ONLY if no printing is required) ---
    "Spooler"

    "WSearch"
    "Wia"
    "FrameServer"

    # --- Xbox Services ---
    "XblAuthManager"
    "XblGameSave"
    "XboxGipSvc"
    "XboxNetApiSvc"
    
    # --- Diagnostics / Feedback ---
    "DPS"
    "DiagTrack"
    "WdiServiceHost"
    "WdiSystemHost"

)


foreach ($svc in $ServicesToDisable) {
    if (-not (Get-Service -Name $svc -ErrorAction SilentlyContinue)) {
        Write-Host "> Service $svc not found, skipping." -ForegroundColor Cyan
    }
    try {
        Get-Service -Name $svc | Set-Service -StartupType Disabled 
        Write-Host "> Disabling service: $svc" -ForegroundColor Green
    }
    catch {
        Write-Host "> Service $svc not found, skipping." -ForegroundColor Cyan
    }
}
#endregion

#
# --- Remove Unnecessary Apps ---
Write-Host "> Removing Unnecessary App Packages..." -ForegroundColor DarkGray
#region
$AppsToRemove = @(
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MSPaint"
    "Microsoft.WindowsCamera"
    "Microsoft.BingWeather"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingFinance"
    "Microsoft.BingTravel"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.YourPhone"
    "Microsoft.Whiteboard"
    "Microsoft.MSPowerPoint"
    "Microsoft.MSExcel"
    "Microsoft.MSWord"
    "Microsoft.Office.OneNote"
    "Microsoft.YourPhone"
    "Microsoft.MicrosoftTeams"

)

foreach ($app in $AppsToRemove) {
    $package = Get-AppxPackage -Name $app -AllUsers
    if ($package) {
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers
        Write-Host "> Removing app package: $app" -ForegroundColor Green
    }
    else {
        Write-Host "> Application $app not found, skipping." -ForegroundColor Gray
    }
}
#endregion

#
# --- Deleting Scheduled Tasks ---
Write-Host "> Deleting Unnecessary Scheduled Tasks..." -ForegroundColor DarkGray

#region
$tasksToDelete = @(
    "\Google"
    "\Feed Synchronization"
    "\OneDrive"
    "\Adobe Flash"
    "\Microsoft\Edge"
    "\Microsoft\Windows\DiskCleanup"
    "\Microsoft\XblGameSave"
)
foreach ($task in $tasksToDelete) {
    try {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Host "> Deleting scheduled task: $task" -ForegroundColor Green
    }
    catch {
        Write-Host "> Scheduled task $task not found, skipping." -ForegroundColor Gray
    }
}
#endregion

#
# --- Security Hardening ---
Write-Host "> Applying Security Hardening settings..." -ForegroundColor DarkGray

#region
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Ole\AppCompat' -ErrorAction SilentlyContinue | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -ErrorAction SilentlyContinue | Out-Null
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' -ErrorAction SilentlyContinue | Out-Null
New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -ErrorAction SilentlyContinue | Out-Null

Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Ole\AppCompat' -Name 'RequireIntegrityActivationAuthenticationLevel' -Value 0 -Force | Out-Null    
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name 'MaintenanceDisabled' -Value 1 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' -Name 'RunAsPPL' -Value 1 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' -Name 'TokenLeakDetectDelaySecs' -Value 30 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'NoLMHash' -Value 1 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential' -Value 0 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'Negotiate' -Value 0 -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' -Name 'EnableActiveProbing' -Value 0 -Force | Out-Null
Write-Host "> Applying Registry-based security authentications hardening." -ForegroundColor Green

#Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol 0 -Force | Out-Null
Set-SmbClientConfiguration -Smb2DialectMin SMB202 -Force | Out-Null
Write-Host "> Disabling SMBv1 protocol." -ForegroundColor Green

# Disable Insecure Guest Authentication
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 0 -Force | Out-Null
Write-Host "> Disabling Insecure Guest Authentication for SMB." -ForegroundColor Green

# Enable Windows Defender Firewall for all profiles
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True | Out-Null
Write-Host "> Enabling Windows Defender Firewall for all profiles." -ForegroundColor Green

# Block LLMNR
New-Item  'HKLM:\Software\Policies\Microsoft\Windows\NT DNSClient' -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty  'HKLM:\Software\Policies\Microsoft\Windows\NT DNSClient' 'EnableMulticast'  0 -Force
Write-Host "> Blocking LLMNR." -ForegroundColor Green

# Disable NetBIOS over TCP/IP
Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object { $_.SetTcpipNetbios(2) } | Out-Null
Write-Host "> Disabling NetBIOS over TCP/IP." -ForegroundColor Green

# Configure UAC to highest level
Set-ItemProperty  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' ConsentPromptBehaviorAdmin  2
Write-Host "> Setting UAC to highest level." -ForegroundColor Green

# Disable LM Hash Storage
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 1 -Force
Write-Host "> Disabling LM Hash storage." -ForegroundColor Green
#endregion

Write-Host @"
======================================================
|    System Optimization and Hardening Complete!    |
======================================================
"@ -ForegroundColor Green

