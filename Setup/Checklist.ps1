#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks and prepares a system for Hyper-V installation and configuration.

.DESCRIPTION
    This script verifies system requirements, enables required Windows features,
    and performs a checklist to prepare a Windows Server or Windows 10/11 machine
    for Hyper-V installation. It includes logging with color-coded console output
    and generates a log file with detailed results.

.AUTHOR
    Xander Waeghe | Github:xwippie

.VERSION
    1.0.0

.LASTUPDATED
    2025-06-09

.NOTES
    - Requires administrative privileges.
    - Designed for Windows Server 2025 datacenter.
    - Requires PowerShell 5.1 or later.
    - Log file will be generated in the same directory as the script.
    - Make sure virtualization is enabled in BIOS before running this script.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Parameter help description
param (
    [switch]$verbose
)


#region Logging
# Define log file path
if (-not (Test-Path -Path "$($PWD.Path)/logs")) {
    New-Item -ItemType Directory -Path "$($PWD.Path)/logs" | Out-Null
}
$script:logFile = Join-Path -Path "$($PWD.Path)/logs" -ChildPath "Checklist_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("VERBOSE", "WARNING", "ERROR", "INFO")]
        [string]$Level = "VERBOSE"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "> $timestamp [$Level]: $Message"

    # Write to log file
    Add-Content -Path $script:logFile -Value $logEntry

    # Set color based on level
    switch ($Level) {
        "VERBOSE" { $color = "Cyan" }
        "INFO" { $color = "Green" }
        "WARNING" { $color = "Yellow" }
        "ERROR" { $color = "Red" }
        default { $color = "Cyan" }
    }
    if ($Level -ne "VERBOSE" -or $verbose) {
        Write-Host $logEntry -ForegroundColor $color
    }
    

}
#endregion

#region Initialization
Write-Log "Starting Checklist script."

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Stop'

# Check powerShell version
Write-Log "Checking PowerShell version."
$version = $PSVersionTable.PSVersion
Write-Log "Required PowerShell version: 5.1 or later."
if ($version.Major -lt 5 -or ($version.Major -eq 5 -and $version.Minor -lt 1)) {
    Write-Log "PowerShell version 5.1 or later is required." -Level "ERROR"
    exit 1
} 
else {
    Write-Log "PowerShell version $($version.ToString()) is sufficient." -Level "INFO"
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "This script must be run as an administrator." -Level "ERROR"
    exit 1
} 
else {
    Write-Log "Running with administrative privileges." -Level "INFO"
}
#endregion

#region Pre checks
Write-Log "Performing pre-checks."
# Check if Hyper-V is already installed
$hyperVFeature = (Get-WindowsFeature -Name Hyper-V)
if ($hyperVFeature.Installed -eq "Enabled") {
    Write-Log "Hyper-V is already installed." -Level "WARNING"
    Write-Log "Exiting..."
    exit 0
}
else {
    Write-Log "Hyper-V is not installed. Proceeding with installation." -Level "INFO"
}
#endregion

#region System Requirements
Write-Log "Checking system requirements."

Write-Log "Checking OS version."
$SupportedOS = @("Microsoft Windows Server 2025 Datacenter")
$osVersion = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
if ($SupportedOS -contains $osVersion) {
    Write-Log "Operating System: $osVersion is supported." -Level "INFO"
}
else {
    Write-Log "Unsupported operating system: $osVersion." -Level "ERROR"
    Write-Log "Supported OS versions: [$($SupportedOS -join ', ')]" -Level "ERROR"
    #exit 1
}

Write-Log "Checking CPU virtualization support."
$cpu = Get-CimInstance Win32_Processor

if ($cpu.VirtualizationFirmwareEnabled) {
    Write-Log "CPU virtualization is enabled." -Level "INFO"
} 
else {
    Write-Log "CPU virtualization is not enabled. Please enable it in BIOS." -Level "ERROR"
    #exit 1
}

if ($cpu.VMMonitorModeExtensions) {
    Write-Log "CPU supports VM Monitor Mode Extensions." -Level "INFO"
} 
else {
    Write-Log "CPU does not support VM Monitor Mode Extensions." -Level "ERROR"
    #exit 1
}

if ($cpu.SecondLevelAddressTranslationExtensions) {
    Write-Log "CPU supports Second Level Address Translation (SLAT)." -Level "INFO"
} 
else {
    Write-Log "CPU does not support SLAT." -Level "ERROR"
    #exit 1
}

Write-Log "All CPU Virtualization requirements are met." -Level "INFO"

Write-Log "Checking RAM requirements."
$minRamGB = 4
$ram = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
if ($ram -ge $minRamGB) {
    Write-Log "RAM: $([math]::Round($ram, 2)) GB is sufficient." -Level "INFO"
} 
else {
    Write-Log "Insufficient RAM: $([math]::Round($ram, 2)) GB. Minimum required: $minRamGB GB." -Level "ERROR"
    exit 1
}

Write-Log "Checking disk space requirements."
$minDiskSpaceGB = 20
$disks = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3")
foreach ($disk in $disks) {
    if ($disk.FreeSpace / 1GB -ge $minDiskSpaceGB) {
        Write-Log "Disk $($disk.DeviceID): $([math]::Round($disk.FreeSpace / 1GB, 2)) GB free space is sufficient." -Level "INFO"
    } 
    else {
        Write-Log "Insufficient disk space on $($disk.DeviceID): $([math]::Round($disk.FreeSpace / 1GB, 2)) GB free space. Minimum required: $minDiskSpaceGB GB." -Level "ERROR"
        exit 1
    }
}

Write-Log "Checking network adapter requirements."
$networkAdapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })
if ($networkAdapters.Count -gt 0) {
    Write-Log "Network adapter(s) are available." -Level "INFO"
} 
else {
    Write-Log "No active network adapters found." -Level "ERROR"
    exit 1
}

Write-Log "----------------------------------------------------" -Level "INFO"
Write-Log "System requirements check completed." -Level "INFO"
Write-Log "----------------------------------------------------" -Level "INFO"
#endregion

#region Enable Hyper-V Features
Write-Log "Enabling Hyper-V role and features."
# Enable Hyper-V role and features
$features = @(
    "Hyper-V",
    "Hyper-V-PowerShell",
    "Hyper-V-Management-PowerShell",
    "Hyper-V-Tools",
    "Hyper-V-Platform"
)
foreach ($feature in $features) {
    Write-Log "Enabling feature: $feature"
    try {
        Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log "Feature $feature enabled successfully." -Level "INFO"
    } 
    catch {
        Write-Log "Failed to enable feature $($feature): $_" -Level "ERROR"
        exit 1
    }
}
#endregion

#region Post Installation Checks
Write-Log "Performing post-installation checks."
# Check if Hyper-V is installed
$hyperVFeature = (Get-WindowsFeature -Name Hyper-V)
if ($hyperVFeature.Installed -eq "Enabled") {
    Write-Log "Hyper-V installation completed successfully." -Level "INFO"
} 
else {
    Write-Log "Hyper-V installation failed." -Level "ERROR"
    exit 1
}
# Check if Hyper-V Manager is available
try {
    $hyperVManager = Get-Command -Name "virtmgmt.msc" -ErrorAction Stop
    Write-Log "Hyper-V Manager is available." -Level "INFO"
} 
catch {
    Write-Log "Hyper-V Manager is not available. Please check the installation." -Level "ERROR"
    exit 1
}
Write-Log "Post-installation checks completed successfully." -Level "INFO"
#endregion

#region Finalization
Write-Log "Finalizing setup."
Write-Log "Hyper-V setup completed successfully." -Level "INFO"
Write-Log "Log file created at: $script:logFile" -Level "INFO"
Write-Log "Please restart your computer to complete the Hyper-V installation." -Level "INFO"
Write-Log "You can now start using Hyper-V to create and manage virtual machines." -Level "INFO"
Write-Log "Thank you for using this script!" -Level "INFO"
Write-Log "Exiting script." -Level "INFO"
#endregion

exit 0

