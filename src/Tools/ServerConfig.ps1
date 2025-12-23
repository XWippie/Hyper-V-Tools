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

Write-Host @"
==========================================
 Windows Server Configuration Script
 Configures baseline settings for servers

    Requires Administrator Privileges

 Author: Xander Waeghe
 Date: Dec 2025
==========================================
"@ -ForegroundColor Cyan

# Check for Administrator privileges
if (-not [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") {
    Write-Warning "Must be executed in Administrator level shell."
    exit 1
}

#
# --- Quality Of Life Changes ---
#region
# Show File Extensions, Hidden Files, Full Path in Title Bar
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced HideFileExt "0"
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced Hidden "1"
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState FullPath "1"
Write-Host "> Setting File Explorer to show file extensions, hidden files and full path in title bar." -ForegroundColor Green

# Don't show recent files, Frequent folders
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer ShowRecent 0
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer ShowFrequent 0
Write-Host "> Disabling recent files and frequent folders in File Explorer." -ForegroundColor Green

# Open File Explorer to This PC
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced LaunchTo 1
Write-Host "> Setting File Explorer to open to This PC." -ForegroundColor Green

# Rright click to old style
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -Value ""
Write-Host "> Setting old style right click context menu." -ForegroundColor Green

# Control Panel to All Items View
If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
}
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1
Write-Host "> Setting Control Panel to All Items view." -ForegroundColor Green

# Num Lock on Login
Set-Itemproperty -path 'Microsoft.PowerShell.Core\Registry::HKEY_USERS\.Default\Control Panel\Keyboard' -Name 'InitialKeyboardIndicators' -value '2'
Write-Host "> Setting Num Lock to ON at login." -ForegroundColor Green

# Align Taskbar to Left
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced TaskbarAl 0
Write-Host "> Aligning Taskbar to Left." -ForegroundColor Green

# Display only search icon
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Search SearchboxTaskbarMode 1
Write-Host "> Setting Taskbar search to display only search icon." -ForegroundColor Green

# Disable Taskbar Widgets
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced TaskbarDa 0
Write-Host "> Disabling Taskbar Widgets." -ForegroundColor Green

# Disable Taskbar Chat
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced TaskbarMn 0
Write-Host "> Disabling Taskbar Chat." -ForegroundColor Green

# Disable Search Highlights
New-Item HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings -Force | Out-Null
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings IsDynamicSearchBoxEnabled 0
Write-Host "> Disabling Search Highlights." -ForegroundColor Green

# Disable Tips, Tricks and Suggestions
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager SubscribedContent-338389Enabled 0
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager SubscribedContent-353694Enabled 0
Write-Host "> Disabling Tips, Tricks and Suggestions." -ForegroundColor Green

# Disable Lock Screen Ads
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager RotatingLockScreenEnabled 0
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager RotatingLockScreenOverlayEnabled 0
Write-Host "> Disabling Lock Screen Ads." -ForegroundColor Green

# Disable Cortana
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Search AllowCortana 0
Write-Host "> Disabling Cortana." -ForegroundColor Green

# Disable Sticky keys
Set-ItemProperty HKCU:\Control Panel\Accessibility\StickyKeys Flags 506
Write-Host "> Disabling Sticky Keys." -ForegroundColor Green

# Disable Toggle keys
Set-ItemProperty HKCU:\Control Panel\Accessibility\ToggleKeys Flags 506
Write-Host "> Disabling Toggle Keys." -ForegroundColor Green

# Disable Filter keys
Set-ItemProperty HKCU:\Control Panel\Accessibility\FilterKeys Flags 506
Write-Host "> Disabling Filter Keys." -ForegroundColor Green

#  Set Menu Delay to 0
Set-ItemProperty HKCU:\Control Panel\Desktop MenuShowDelay 0
Write-Host "> Setting Menu Show Delay to 0." -ForegroundColor Green

# restart explorer to apply file explorer settings
Stop-Process -Name Explorer -force
FileWrite-Host "> Restarting Explorer to apply File Explorer settings." -ForegroundColor Green
Start-Sleep -Seconds 2
#endregion

#
# --- System Configuration ---
#region
# Disable IE Enhanced Security Configuration
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Write-Host "> Disabling IE Enhanced Security Configuration." -ForegroundColor Green

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
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -Value 190
Write-Host "> Setting Disk Timeout to 190 seconds." -ForegroundColor Green

# Create Dump Folder
New-Item -Path "C:\Windows\Dump" -ItemType Directory -Force
Write-Host "> Creating Dump folder at C:\Windows\Dump." -ForegroundColor Green

# Pagefile Settings
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value "C:\pagefile.sys 0 0"
Write-Host "> Setting Pagefile to System Managed Size on C: drive." -ForegroundColor Green

# Visable Visual Effects Settings
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
Write-Host "> Setting Visual Effects to 'Adjust for best appearance'." -ForegroundColor Green

# Event Log Size Settings
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security" -Name "MaxSize" -Value 268435456
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\System" -Name "MaxSize" -Value 67108864
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application" -Name "MaxSize" -Value 67108864
Write-Host "> Setting Event Log sizes." -ForegroundColor Green

# disable IPv6
Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6 -PassThru
Write-Host "> Disabling IPv6 on all network adapters." -ForegroundColor Green
#endregion

#
# --- Remote Desktop Settings ---
#region
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

# Enable Remote Desktop Firewall Rules
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Get-NetFirewallRule -DisplayGroup "Remote Desktop" | Set-NetFirewallRule -Profile Domain,Private
Write-Host "> Enabling Remote Desktop Firewall Rules for Domain and Private profiles." -ForegroundColor Green
#endregion

#
# --- Disable Unnecessary Features & Services ---
#region
$DisabledFeatures = @(
    "Printing-XPSServices-Features"
    "TelnetClient"
    "TFTP"
    "TIFFIFilter"
    "VirtualMachinePlatform"
    "Client-ProjFS"
    "SimpleTCP"
    "WorkFolders-Client"
    "WCF-HTTP-Activation"
    "WCF-NonHTTP-Activation"
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
    "IIS-WebServerManagementTools"
    "IIS-ManagementScriptingTools"
    "IIS-IIS6ManagementCompatibility"
    "IIS-Metabase"
    "WAS-WindowsActivationService"
    "WAS-ProcessModel"
    "WAS-NetFxEnvironment"
    "WAS-ConfigurationAPI"
    "IIS-HostableWebCore"
    "WCF-Services45"
    "WCF-HTTP-Activation45"
    "WCF-TCP-Activation45"
    "WCF-Pipe-Activation45"
    "WCF-MSMQ-Activation45"
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
    "IIS-HttpCompressionStatic"
    "IIS-ManagementConsole"
    "IIS-ManagementService"
    "IIS-WMICompatibility"
    "IIS-LegacyScripts"
    "IIS-FTPServer"
    "IIS-FTPSvc"
    "IIS-FTPExtensibility"
    "MSMQ-Container"
    "MSMQ-DCOMProxy"
    "MSMQ-Server"
    "MSMQ-ADIntegration"
    "MSMQ-HTTP"
    "MSMQ-Multicast"
    "MSMQ-Triggers"
    "IIS-CertProvider"
    "IIS-WindowsAuthentication"
    "IIS-DigestAuthentication"
    "IIS-ClientCertificateMappingAuthentication"
    "IIS-IISCertificateMappingAuthentication"
    "IIS-ODBCLogging"
    "SMB1Protocol-Deprecation"
    "MediaPlayback"
    "WindowsMediaPlayer"
    "DirectoryServices-ADAM-Client"
    "SmbDirect"
    "AppServerClient"
    "Printing-PrintToPDFServices-Features"
    "LegacyComponents"
    "DirectPlay"
    "MSRDC-Infrastructure"
    "NetFx4Extended-ASPNET45"
    "HostGuardian"
    "ServicesForNFS-ClientOnly"
    "ClientForNFS-Infrastructure"
    "NFS-Administration"
    "Recall"
    "SearchEngine-Client-Package"
    "Microsoft-RemoteDesktopConnection"
    "HypervisorPlatform"
    "Windows-Identity-Foundation"
    "Microsoft-Windows-Subsystem-Linux"
    "Printing-Foundation-Features"
    "Printing-Foundation-InternetPrinting-Client"
    "Printing-Foundation-LPDPrintService"
    "Printing-Foundation-LPRPortMonitor"
    "Microsoft-Hyper-V-All"
    "Microsoft-Hyper-V"
    "Microsoft-Hyper-V-Tools-All"
    "Microsoft-Hyper-V-Management-PowerShell"
    "Microsoft-Hyper-V-Hypervisor"
    "Microsoft-Hyper-V-Services"
    "Microsoft-Hyper-V-Management-Clients"
    "Client-DeviceLockdown"
    "Client-EmbeddedShellLauncher"
    "Client-EmbeddedBootExp"
    "Client-EmbeddedLogon"
    "Client-KeyboardFilter"
    "Client-UnifiedWriteFilter"
    "Containers-DisposableClientVM"
    "Containers-Server-For-Application-Guard"
    "HyperV-KernelInt-VirtualDevice"
    "HyperV-Guest-KernelInt"
    "DataCenterBridging"
    "Containers"
    "Containers-HNS"
    "Containers-SDN"
    "SMB1Protocol"
    "SMB1Protocol-Client"
    "SMB1Protocol-Server"
    "MultiPoint-Connector"
    "MultiPoint-Connector-Services"
    "MultiPoint-Tools"
)

# Check if features are enabled before disabling
$enabledFeatures = Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed'} | Select-Object -ExpandProperty Name
foreach ($feature in $DisabledFeatures) {
    if ($enabledFeatures -contains $feature) {
        Write-Host "> Disabling feature: $feature" -ForegroundColor Green
        Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue
    } else {
        Write-Host "> Skipping feature: $feature (not enabled)" -ForegroundColor Gray
    }
}
#endregion

#
# --- Disable Unnecessary Services ---
#region
$ServicesToDisable = @(
    # Bluetooth / Wireless
    "AVCTP"
    "BTAGService"
    "bthserv"

    # BitLocker / Disk
    "BDESVC"

    # Legacy / Deprecated
    "Browser"
    "irmon"
    "smphost"
    "NcbService"
    "SACSVR"
    "TapiSrv"
    "StillImage"

    # Telemetry / Diagnostics
    "DiagTrack"
    "dmwappushservice"
    "DPS"
    "WdiServiceHost"
    "WdiSystemHost"
    "DiagHub"
    "wercplsupport"
    "WerSvc"
    "PcaSvc"

    # Maps / Location / Sensors
    "MapsBroker"
    "lfsvc"
    "SensorDataService"
    "SensorService"
    "SensrSvc"

    # Networking / Sharing
    "SharedAccess"
    "iphlpsvc"
    "QWAVE"
    "RmSvc"
    "RemoteRegistry"
    "RemoteAccess"
    "icssvc"

    # Offline / Sync
    "CscService"
    "fhsvc"

    # Identity / Consumer
    "wlidsvc"
    "PhoneSvc"
    "WalletService"
    "LicenseManagerSvc"

    # App / Store / App-V
    "AppVClient"
    "PushToInstall"

    # Printing / Imaging
    "Spooler"
    "Wia"

    # Security / Credentials
    "seclogon"
    "WpcMonSvc"
    "SEMgrSvc"
    "WbioSrvc"

    # Smart Card / USB
    "SCardSvr"
    "ScDeviceEnum"
    "SmartCardRemovalPolicy"
    "WPDBusEnum"
    "ShellHWDetection"

    # Media / Audio / Camera
    "Audiosrv"
    "AudioEndpointBuilder"
    "FrameServer"
    "WMPNetworkSvc"

    # Search / UI
    "WSearch"

    # UE-V / Performance
    "UEVAgentService"
    "WarpJITSvc"

    # Insider / Update
    "wisvc"
)

foreach ($svc in $ServicesToDisable) {
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
    "Microsoft.MicrosoftEdge"
    "Microsoft.YourPhone"
)

foreach ($app in $AppsToRemove) {
    $package = Get-AppxPackage -Name $app -AllUsers
    if ($package) {
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers
        Write-Host "> Removing app package: $app" -ForegroundColor Green
    } else {
        Write-Host "> App package $app not found, skipping." -ForegroundColor Gray
    }
}
#endregion

#
# --- Deleteing Schedules Tasks ---
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
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "> Deleting scheduled task: $task" -ForegroundColor Green
    }
    catch {
        Write-Host "> Scheduled task $task not found, skipping." -ForegroundColor Gray
    }
}
#endregion

#
# --- Security Hardening ---
#region
New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Ole\AppCompat' 'RequireIntegrityActivationAuthenticationLevel' 0 -Force
New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 1 -Force
New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' 'RunAsPPL' 1 -Force
New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA' 'TokenLeakDetectDelaySecs' 30 -Force
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 1 -Force
New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 0 -Force
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'Negotiate' 0
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' 'EnableActiveProbing' 0
Write-Host "> Applying Registry-based security authentications hardening." -ForegroundColor Green

#Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Set-SmbClientConfiguration -EnableSMB1Protocol $false -Force
Write-Host "> Disabling SMBv1 protocol." -ForegroundColor Green

# Disable Insecure Guest Authentication
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' 'AllowInsecureGuestAuth' 0 -Force
Write-Host "> Disabling Insecure Guest Authentication for SMB." -ForegroundColor Green

# Disable OLD powershell versions
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart
Write-Host "> Disabling Windows PowerShell V2." -ForegroundColor Green

# Enable Windows Defender Firewall for all profiles
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Write-Host "> Enabling Windows Defender Firewall for all profiles." -ForegroundColor Green

# Block LLMNR
New-Item  'HKLM:\Software\Policies\Microsoft\Windows' 'NT DNSClient' -Force | Out-Null
Set-ItemProperty  'HKLM:\Software\Policies\Microsoft\Windows' 'NT DNSClient' 'EnableMulticast'  0 -Force
Write-Host "> Blocking LLMNR." -ForegroundColor Green


# Disable NetBIOS over TCP/IP
Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object { $_.SetTcpipNetbios(2) }
Write-Host "> Disabling NetBIOS over TCP/IP." -ForegroundColor Green

# Enable Windows Defender Default Definitions
Enable-WindowsOptionalFeature -Online -FeatureName Windows-Defender-Default-Definitions -NoRestart
Write-Host "> Enabling Windows Defender Default Definitions." -ForegroundColor Green

# Configure UAC to highest level
Set-ItemProperty  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' ConsentPromptBehaviorAdmin  2
Write-Host "> Setting UAC to highest level." -ForegroundColor Green

# Disable LM Hash Storage
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 1 -Force
Write-Host "> Disabling LM Hash storage." -ForegroundColor Green
#endregion

#
# --- OSConfig ---
#region
#get os is not server in name skip this
$os = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
if ($os -notlike "*Server*"){
    Write-Host @"
This is a not a server edition of Windows.
Skipping OSConfig hardening.

To apply similar hardening please use Microsoft.SecurityComplianceToolkit.
"@ -ForegroundColor Yellow
    exit
} else {
    Install-Module -Name Microsoft.OSConfig -Scope AllUsers -Repository PSGallery -Force
    Write-Host "> Installing Microsoft.OSConfig module." -ForegroundColor Green

    Import-Module Microsoft.OSConfig
    #ask for a domain joind or workgroup

    $joinType = Read-Host "Is this server joining a Domain or Workgroup? (D/W/DC)"
    while ($joinType.ToUpper() -ne "D" -and $joinType.ToUpper() -ne "W" -and $joinType.ToUpper() -ne "DC") {
        Write-Warning "Invalid input. Please enter 'D' for Domain, 'W' for Workgroup, or 'DC' for Domain Controller."
        $joinType = Read-Host "Is this server joining a Domain or Workgroup? (D/W/DC)"
    }


    if ($joinType.ToUpper() -eq "D") {
        Set-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/MemberServer -Default
    }
    else if ($joinType.ToUpper() -eq "W") {
        Set-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/WorkgroupServer -Default
    }
    else {
        Set-OSConfigDesiredConfiguration -Scenario SecurityBaseline/WS2025/DomainController -Default
    }
    Write-Host "> Applying OS Security Baseline Hardening using Microsoft.OSConfig." -ForegroundColor Green

    Set-OSConfigDesiredConfiguration -Scenario SecuredCore -Default
    Write-Host "> Applying Secured Core configuration using Microsoft.OSConfig." -ForegroundColor Green

    Set-OSConfigDesiredConfiguration -Scenario Defender/Antivirus -Default
    Write-Host "> Applying Defender Antivirus configuration using Microsoft.OSConfig." -ForegroundColor Green
}
#endregion

Write-Host @"
==================================================
|            Configuration Complete!             |
|  Please restart the server to apply changes.   |
==================================================
"@ -ForegroundColor Green