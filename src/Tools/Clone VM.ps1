<#
.SYNOPSIS
    Clones a Hyper-V virtual machine from a specified template VM.
.DESCRIPTION
    This script exports a specified template VM, imports it as a new VM with a unique ID,
    and allows the user to configure various settings for the cloned VM, including memory,
    CPU, disk size, and Out-Of-Box Experience (OOBE) settings.
.PARAMETER TemplateVM
    The name of the template VM to clone.
.PARAMETER ImportPath
    The path where the cloned VM will be imported.
.PARAMETER CloneName
    The name for the cloned VM.
.NOTES
    Author: XWippie
    Date: 11 Nov 2025
    Version: 1.0

    IS NOT TESTED YET
#>

#
# Configuration
#region
$config = @{
    'TemplateVM'        = 'TemplateVM'
    'TemplateVMPath'    = 'D:\\VMs\\Exports'
    'ImportPathOptions' = @(
        'C:\\ClusterStorage\\SharedStorage',
        'D:\\VMs'
    ),
    'DefaultPassword'   = 'P@ssw0rd'
}

$LogFile = "$($PSScriptRoot)\logs\" + ((Get-Date).ToString('ddMMyyHHmmss')) + '_CloneVM.log'
#endregion


#
# Logging
#region
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$type = 'INFO'
    )

    # Ensure the logs directory exists
    if (-Not (Test-Path -Path "$($PSScriptRoot)\logs")) {
        New-Item -ItemType Directory -Path "$($PSScriptRoot)\logs" | Out-Null
    }

    # Create a timestamped log entry
    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'dd-MM-yyyy HH:mm:ss'), $type, $Message

    # Run the write in a background job to avoid blocking
    Start-Job -ScriptBlock {
        param($entry, $logFile)
        Add-Content -Path $logFile -Value $entry
    } -ArgumentList $entry, $LogFile | Out-Null
}
#endregion

#
# Import Modules
#region
try {
    # Try to import the Hyper-V module
    Import-Module Hyper-V -ErrorAction Stop
}
catch {
    Write-Host 'Failed to import Hyper-V module. Please ensure Hyper-V is installed and the module is available. Check the logs for more details.' -ForegroundColor Red
    Write-Log 'Failed to import Hyper-V module. Please ensure Hyper-V is installed and the module is available.' 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    exit
}
#endregion

#
# Function Get-Input
#region
function Get-Input {
    param (
        [Parameter(Mandatory)]
        [string]$prompt,

        [Parameter(Mandatory)]
        [int]$defaultValue,

        [Parameter(Mandatory)]
        [ValidateSet("int", "integer", "str", "string")]
        [string]$inputType,

        [Parameter(Mandatory = $false)]
        [string[]]$options
    )

    Write-Log "Prompting user for input: $prompt with default value: $defaultValue and input type: $inputType" 'DEBUG'

    # Display the prompt and get user input
    while ($true) {
        Write-Log "Displaying prompt to user: $prompt" 'DEBUG'
        $userInput = Read-Host "$prompt [Default: $defaultValue]"
        $userInput = $userInput.Trim()

        # Use default value if input is empty
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-Log "No input provided, using default value: $defaultValue" 'INFO'
            return $defaultValue
        }

        # Validate against options if provided
        if ($options) {
            if ($userInput -notin $options) {
                Write-Log "Input '$userInput' not in allowed options: $($options -join ', ')" 'ERROR'
                Write-Host "Invalid option. Please choose from the following: $($options -join ', ')" -ForegroundColor Yellow
                continue
            }
        }

        # Validate input type
        if ($inputType -in @('int', 'integer')) {
            if (-not [int]::TryParse($userInput, [ref]$parsedInput)) {
                Write-Log "Invalid integer input provided: $userInput" 'ERROR'
                Write-Host "Please enter a valid integer value." -ForegroundColor Yellow
                continue
            }

            # Return the parsed integer & log
            Write-Log "Valid integer input provided: $parsedInput" 'INFO'
            return $parsedInput
        }
        else {
            # Return the user input & log
            Write-Log "Valid string input provided: $userInput" 'INFO'
            return $userInput
        }
    }
}
#endregion

#
# Function Show-Loader
#region
function Show-Loader {
    param (
        $enable = $true
    )

    $loader = @(
        '|',
        '/',
        '-',
        '\'
    )
    if ($enable) {
        $script:loaderJob = Start-Job -ScriptBlock {
            while ($true) {
                foreach ($frame in $using:loader) {
                    Write-Host -NoNewline "`rCloning VM... $frame"
                    Start-Sleep -Milliseconds 200
                }
            }
        }
    }
    else {
        if ($script:loaderJob) {
            Stop-Job -Job $script:loaderJob | Out-Null
            Remove-Job -Job $script:loaderJob | Out-Null
        }
    }
}
#endregion

#
# Function Wait-VMReady
#region
function Wait-VMReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $VMName,
        [ValidateSet('Running','Heartbeat','IP','PsDirect')] [string[]] $Stages = @('Running','Heartbeat'),
        [int] $TimeoutRunningSec  = 300,
        [int] $TimeoutHeartbeatSec = 600,
        [int] $TimeoutIPSec       = 900,
        [int] $TimeoutPsDirectSec = 1200,
        [System.Management.Automation.PSCredential] $Credential
    )

    # 1) Running
    if ($Stages -contains 'Running') {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        do {
            $state = (Get-VM -Name $VMName).State
            if ($state -eq 'Running') { break }
            Start-Sleep 2
        } while ($sw.Elapsed.TotalSeconds -lt $TimeoutRunningSec)
        if ($state -ne 'Running') { throw "[$VMName] did not enter 'Running' within $TimeoutRunningSec sec (state: $state)" }
        Write-Verbose "[$VMName] Running"
    }

    # 2) Heartbeat
    if ($Stages -contains 'Heartbeat') {
        $sw.Restart()
        do {
            $hb = Get-VMIntegrationService -VMName $VMName -Name 'Heartbeat' -ErrorAction SilentlyContinue
            $ok = $hb -and $hb.PrimaryStatusDescription -eq 'OK'
            if ($ok) { break }
            Start-Sleep 3
        } while ($sw.Elapsed.TotalSeconds -lt $TimeoutHeartbeatSec)
        if (-not $ok) { throw "[$VMName] Heartbeat not OK within $TimeoutHeartbeatSec sec" }
        Write-Verbose "[$VMName] Heartbeat OK"
    }

    # 3) IP
    $ipv4 = $null
    if ($Stages -contains 'IP') {
        $sw.Restart()
        do {
            $ips = (Get-VMNetworkAdapter -VMName $VMName).IPAddresses 2>$null
            $ipv4 = $ips | Where-Object {
                $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and
                -not ($_ -like '169.254.*') -and -not ($_ -like '0.*')
            } | Select-Object -First 1
            if ($ipv4) { break }
            Start-Sleep 3
        } while ($sw.Elapsed.TotalSeconds -lt $TimeoutIPSec)
        if (-not $ipv4) { throw "[$VMName] no usable IPv4 within $TimeoutIPSec sec" }
        Write-Verbose "[$VMName] IPv4: $ipv4"
    }

    # 4) PowerShell Direct
    if ($Stages -contains 'PsDirect') {
        if (-not $Credential) { throw "[$VMName] Provide -Credential for PsDirect stage." }
        $sw.Restart()
        $psd = $false
        do {
            try {
                $s = New-PSSession -VMName $VMName -Credential $Credential -ErrorAction Stop
                Remove-PSSession $s
                $psd = $true
            } catch {
                Start-Sleep 5
            }
        } while (-not $psd -and $sw.Elapsed.TotalSeconds -lt $TimeoutPsDirectSec)
        if (-not $psd) { throw "[$VMName] PowerShell Direct not available within $TimeoutPsDirectSec sec" }
        Write-Verbose "[$VMName] PowerShell Direct OK"
    }

    [pscustomobject]@{
        VMName    = $VMName
        IPv4      = $ipv4
        Running   = $true
        Heartbeat = if ($Stages -contains 'Heartbeat') { $ok } else { $null }
        PsDirect  = if ($Stages -contains 'PsDirect')  { $psd } else { $null }
    }
}
#endregion

#
# Start of Script
#region
Write-Host '--------Starting Clone VM Script--------' -ForegroundColor Cyan
Write-Log '--------Starting Clone VM Script--------' 'INFO'
#endregion

#
# Check If template vm is valid and exists
#region
Write-Host 'Checking Template VM configuration...'
Write-Log 'Beginning Template Export Check' 'INFO'

if ([string]::IsNullOrWhiteSpace($config.TemplateVM)) {
    Write-Host "Template VM is not set in the config file.`nPlease enter the name of the VM you want to in the config file under $($config.TemplateVM)" -ForegroundColor Red
    Write-Log 'Template VM is not set in the config file. Exiting script.' 'ERROR'
    exit 
}

# If the template variable is a list let the user choose from the list
if ($config.TemplateVM -is [array]) {
    if ($config.TemplateVM.Count -gt 1) {
        Write-Host 'Multiple template VMs found in config. Please select one:'
        for ($i = 0; $i -lt $config.TemplateVM.Count; $i++) {
            Write-Host "$($i + 1). $($config.TemplateVM[$i])"
        }
        $selection = Get-Input -prompt 'Enter the number corresponding to your choice' -defaultValue 1 -inputType 'int'
        if ($selection -lt 1 -or $selection -gt $config.TemplateVM.Count) {
            Write-Host 'Invalid selection. Exiting script.' -ForegroundColor Red
            Write-Log 'Invalid selection for Template VM. Exiting script.' 'ERROR'
            exit
        }
        $TemplateVM = $config.TemplateVM[$selection - 1]
    }
    else {
        $TemplateVM = $config.TemplateVM[0]
    }
}
else {
    $TemplateVM = $config.TemplateVM
}
Write-Host "Template VM set to: $TemplateVM"
Write-Log "Template VM set to: $TemplateVM" 'INFO'


if ( (Test-Path -Path "$($ExportPath)\$($TemplateVM)") ) {
    Write-Host 'An export for the template VM already exists. Skipping export step.'
}
else {
    try {
        Write-Host "Exporting VM $($TemplateVM)"
        Write-Log "Exporting VM $($TemplateVM) to path $ExportPath" 'INFO'
        Export-VM -Name $TemplateVM -Path $ExportPath -WhatIf
        Write-Host 'Export completed.'
        Write-Log "Export of VM $($TemplateVM) completed successfully." 'INFO'
    }
    catch {
        Write-Host "An error occurred during export of VM $($TemplateVM)"
        Write-Log "An error occurred during export of VM $($TemplateVM). Check the logs for more details." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        exit
    }   
}
#endregion

#
# Variables and User Input
#region
#TODO $TargetHost = Get-Input -prompt 'Enter the target Hyper-V host name' -defaultValue $env:COMPUTERNAME -inputType 'string'
$CloneName = Get-Input -prompt 'Enter the name for the cloned VM' -defaultValue "$($TemplateVM)_Clone" -inputType 'string'
$ImportPath = Get-Input -prompt 'Select the import path for the cloned VM' -defaultValue '1' -inputType 'string' -options $config.ImportPathOptions
#endregion

#
# Pre requisites
#region
# check in a VMCX file iwith extension exists in the import path (i don't know the name of the file so i check for the extension) if exists get the path of the file
Write-Host 'Checking for VMCX file in the exported VM directory...'
Write-Log 'Checking for VMCX file in the exported VM directory...' 'INFO'
try {
    $vmcxPath = Get-ChildItem -Path "$($ExportPath)/$($TemplateVM)" -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
    if (-Not $vmcxPath) {
        Write-Host 'No VMCX file found in the export directory. Cannot proceed with import., Check the logs for more details.' -ForegroundColor Red
        Write-Log "No VMCX file found in the export directory. ( $($ExportPath)/$($TemplateVM)). Exiting script." 'ERROR'
        Write-Log "Ensure that the VM was exported correctly and the VMCX file is present." 'ERROR'
        exit
    }
    Write-Host "Found VMCX file at $vmcxPath"
    Write-Log "Found VMCX file at $vmcxPath" 'INFO'
}
catch {
    Write-Host 'An error occurred while checking for the VMCX file. Check the logs for more details.' -ForegroundColor Red
    Write-Log 'An error occurred while checking for the VMCX file. Exiting script.' 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    exit
}


Write-Host 'Verifying import directory...'
Write-Log 'Verifying import directory...' 'INFO'
if (-Not (Test-Path -Path $ImportPath -ErrorAction SilentlyContinue)) {
    try {
        Write-Host 'The specified import directory does not exist. Creating it now...'
        Write-Log "The specified import directory does not exist at $($ImportPath). Creating it now..." 'INFO'
        New-Item -ItemType Directory -Path $ImportPath
        Write-Host "Import directory created at $($ImportPath)"
        Write-Log "Import directory created at $($ImportPath)" 'INFO'
    }
    catch {
        Write-Host 'Failed to create the import directory. Check the logs for more details.' -ForegroundColor Red
        Write-Log "Failed to create the import directory at $($ImportPath). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        exit
    }    
}
else {
    Write-Host "Import directory already exists at $($ImportPath), continuing..."
    Write-Log "Import directory already exists at $($ImportPath), continuing..." 'INFO'
}


# Create subdirectories for the import process
Write-Host 'Ensuring necessary subdirectories exist in the import path...'
Write-Log 'Ensuring necessary subdirectories exist in the import path...' 'INFO'
$subDirs = @('Virtual Machines', 'Snapshots', 'Virtual Hard Disks')
foreach ($dir in $subDirs) {
    $fullPath = Join-Path -Path $ImportPath -ChildPath $dir
    if (-Not (Test-Path -Path $fullPath)) {
        try {
            New-Item -ItemType Directory -Path $fullPath
            Write-Host "Subdirectory Created: $($fullPath)"
            Write-Log "Subdirectory Created: $($fullPath)" 'INFO'
        }
        catch {
            Write-Host "An error occurred while creating subdirectory $($dir). Check the logs for more details." -ForegroundColor Red
            Write-Log "An error occurred while creating subdirectory $($dir) at $($fullPath). Exiting script." 'ERROR'
            Write-Log "Details: $($_.Exception.Message)" 'ERROR'
            exit
        }
    }
    else {
        Write-Host "Subdirectory already exists: $fullPath"
        Write-Log "Subdirectory already exists: $fullPath" 'INFO'
    }
}
#endregion

#
# Import the VM
#region
Write-Host "Importing VM from $($vmcxPath) to $($ImportPath) with new name $($CloneName)..."
Write-Log "Importing VM from $($vmcxPath) to $($ImportPath) with new name $($CloneName)..." 'INFO'
try {
    # Import as a new VM with a unique ID
    Start-Transaction
    Show-Loader
    Import-VM -Path $vmcxPath -Copy -GenerateNewId -VirtualMachinePath '$ImportPath' -SnapshotFilePath '$ImportPath/Snapshots' -VhdDestinationPath '$ImportPath/Virtual Hard Disks' | Rename-VM -NewName $CloneName
    Show-Loader -enable $false
    Write-Host "Import completed. VM $($CloneName) has been created."
    Write-Log "Import of VM $($TemplateVM) completed successfully as $($CloneName)." 'INFO'
    Commit-Transaction
}
catch {
    Write-Host "An error occurred during import, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred during import of VM $($TemplateVM). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    Rollback-Transaction
    exit
}

Write-Host 'Verifying the new VM exists...'
Write-Log 'Verifying the new VM exists...' 'INFO'
# Verify the new VM
if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
    Write-Host "VM $($CloneName) has been successfully created and is available."
    Write-Log "VM $($CloneName) has been successfully created and is available." 'INFO'
}
else {
    Write-Host "Unknown error occurred during the import process."
    Write-Log "Unknown error occurred during the import process." 'ERROR'
    exit
}

# Rename the disk files to match the new VM name
Write-Host 'Renaming disk files to match the new VM name...'
Write-Log 'Renaming disk files to match the new VM name...' 'INFO'
$diskFiles = Get-ChildItem -Path "$($ImportPath)/Virtual Hard Disks"
foreach ($disk in $diskFiles) {
    $newDiskName = $disk.Name -replace [regex]::Escape($TemplateVM), $CloneName
    try {
        Rename-Item -Path $disk.FullName -NewName $newDiskName
        Write-Host 'Renamed disk file Successfully' -ForegroundColor Green
        Write-Log "Renamed disk file $($disk.Name) to $($newDiskName)" 'INFO'
    }
    catch {
        Write-Host "An error occurred while renaming disk file $($disk.Name), Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while renaming disk file $($disk.Name). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }
}

# Set the vm to use the new disk files
try {
    Write-Host 'Setting the new VM to use the renamed disk files...'
    Write-Log 'Setting the new VM to use the renamed disk files...' 'INFO'
    Set-VMHardDiskDrive -VMName $CloneName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path '$ImportPath/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($TemplateVM), $CloneName)' 
    Write-Host 'Set the VM to use the new disk file successfully.' -ForegroundColor Green
    Write-Log "Set the VM '$CloneName' to use the new disk file." 'INFO'
}
catch {
    Write-Host 'An error occurred while setting the VM to use the new disk file, Check the logs for more details.' -ForegroundColor Red
    Write-Log "An error occurred while setting the VM to use the new disk file for VM '$CloneName'. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}
#endregion

#
# Configure the new VM
#region
Write-Host 'Configuring the new VM settings...'
Write-Log 'Configuring the new VM settings...' 'INFO'

# Set the startup delay for the new VM
$startDelay = Get-Input -prompt "Enter the startup delay (in seconds) for the new VM $($CloneName)" -defaultValue 0 -inputType 'int'
try {
    Set-VM -Name $CloneName -AutomaticStartDelay $startDelay
    Write-Host "Startup delay set at $($startDelay) seconds" -ForegroundColor Green
    Write-Log "Set the startup delay of VM $($CloneName) to $($startDelay) seconds." 'INFO'
}
catch {
    Write-Host "An error occurred while setting the startup delay, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while setting the startup delay for VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

$stopaction = Get-Input -prompt "Enter the automatic stop action for the new VM $($CloneName) (0: Save, 1: Turn Off, 2: Shut Down)" -defaultValue 2 -inputType 'int'
try {
    Set-VM -Name $CloneName -AutomaticStopAction $stopaction
    Write-Host "Stop action set to $($stopaction)" -ForegroundColor Green
    Write-Log "Set the automatic stop action of VM $($CloneName) to $($stopaction)." 'INFO'
}
catch {
    Write-Host "An error occurred while setting the automatic stop action, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while setting the automatic stop action for VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

$ramValue = Get-Input -prompt "Enter the amount of memory (in GB) to allocate to the new VM $($CloneName)" -defaultValue 4 -inputType 'int'
try {
    Set-VMMemory -VMName $CloneName -StartupBytes ($ramValue * 1GB)
    Write-Host "Set the memory of VM $($CloneName) to $($ramValue) GB."
    Write-Log "Set the memory of VM $($CloneName) to $($ramValue) GB." 'INFO'
}
catch {
    Write-Host "An error occurred while setting the memory for VM $($CloneName): $_"
    Write-Log "An error occurred while setting the memory for VM $($CloneName). Exiting script." 'ERROR'
}

$cpuAmount = Get-Input -prompt "Enter the number of virtual processors to allocate to the new VM $($CloneName)" -defaultValue 1 -inputType 'int'
try {
    Set-VMProcessor -VMName $CloneName -Count $cpuAmount
    Write-Host "Set the CPU count of VM $($CloneName) to $($cpuAmount)."
    Write-Log "Set the CPU count of VM $($CloneName) to $($cpuAmount)." 'INFO'
}
catch {
    Write-Host "An error occurred while setting the CPU count for VM $($CloneName)"
    Write-Log "An error occurred while setting the CPU count for VM $($CloneName). Exiting script." 'ERROR'
}

$diskSizeGB = Get-Input -prompt "Enter the new disk size (in GB) for the VM $($CloneName)" -defaultValue 50 -inputType 'int'
if ($diskSizeGB -gt 50) {
    try {
        Resize-VHD -Path "$ImportPath/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($TemplateVM), $CloneName)" -SizeBytes ($diskSizeGB * 1GB)
        Write-Host "Resized the virtual hard disk of VM $($CloneName) to $($diskSizeGB) GB."
        Write-Log "Resized the virtual hard disk of VM $($CloneName) to $($diskSizeGB) GB." 'INFO'
    }
    catch {
        Write-Host "An error occurred while resizing the virtual hard disk for VM $($CloneName): $_"
        Write-Log "An error occurred while resizing the virtual hard disk for VM $($CloneName): $_" 'ERROR'
    }
} 
else {
    Write-Host "Disk size is set to $($diskSizeGB) GB which is not greater than the template size. Skipping resize."
    Write-Log "Disk size is set to $($diskSizeGB) GB which is not greater than the template size. Skipping resize." 'INFO'
}
#endregion

#
# configer OOB
#region
Write-Host 'Configuring Out-Of-Box Experience (OOBE) settings for the new VM...'
Write-Log 'Configuring Out-Of-Box Experience (OOBE) settings for the new VM...' 'INFO'


$oobConfigPath = 'Config\unattend.xml'
if (-Not (Test-Path -Path 'Config')) {
    try {
        New-Item -ItemType Directory -Path 'Config'
        Write-Host 'Created Config directory for OOBE configuration.'
        Write-Log 'Created Config directory for OOBE configuration.' 'INFO'
    }
    catch {
        Write-Host 'An error occurred while creating the Config directory for OOBE configuration, Check the logs for more details.' -ForegroundColor Red
        Write-Log 'An error occurred while creating the Config directory for OOBE configuration. Exiting script.' 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        exit
    }
} else {
    Write-Host 'Config directory already exists, continuing...'
    Write-Log 'Config directory already exists, continuing...' 'INFO'
}

$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" versionScope="nonSxS">
      <ComputerName>$CloneName</ComputerName>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>$($Config.DefaultPassword)</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <AutoLogon>
        <Enabled>true</Enabled>
       LogonCount>1</LogonCount>
        <Username>Administrator</Username>
        <Password>
          <Value>$($Config.DefaultPassword)</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>
    </component>
  </settings>

  <cpi:offlineImage cpi:source="wim://wimfile" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@

try {
    Write-Host "Creating unattend at $oobConfigPath..."
    Write-Log "Creating unattend at $oobConfigPath..." 'INFO'
    $unattendXml | Set-Content -Path $oobConfigPath -Encoding utf8BOM -Force
    Write-Host "Unattend created."
    Write-Log "Unattend created successfully at $oobConfigPath." 'INFO'
}
catch {
    Write-Host "An error occurred while creating unattend.xml, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while creating unattend.xml at $oobConfigPath. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    exit
}

$vmDiskPath = Join-Path -Path $ImportPath -ChildPath "Virtual Hard Disks\$CloneName.vhdx"
$mounted = $false
try {
    Write-Host "Mounting $vmDiskPath ..."
    Write-Log "Mounting $vmDiskPath ..." 'INFO'
    
    Mount-DiskImage -ImagePath $vmDiskPath -PassThru | Out-Null
    $mounted = $true

    Write-Host "Mounted VHDX successfully."
    Write-Log "Mounted VHDX successfully." 'INFO'

    $disk = Get-DiskImage -ImagePath $vmDiskPath | Get-Disk
    Write-Log "Retrieved disk information for mounted VHDX." 'DEBUG'
    $osDrive = $null
    foreach ($p in ($disk | Get-Partition | Where-Object DriveLetter)) {
        $dl = "$($p.DriveLetter):"
        Write-Log "Checking partition $dl for Windows\System32..." 'DEBUG'
        if (Test-Path "$dl\Windows\System32") {
            $osDrive = $dl;
            break 
        }
    }
    if (-not $osDrive) {
        Write-Host "Failed to locate OS volume in mounted VHDX, check the logs for more details." -ForegroundColor Red
        Write-Log "Failed to locate OS volume in mounted VHDX. Exiting script." 'ERROR'
        Exit
    }
    Write-Host "OS volume detected at $osDrive"
    Write-Log "OS volume detected at $osDrive" 'INFO'

    foreach ($dst in @("$osDrive\Windows\Panther", "$osDrive\Windows\System32\Sysprep")) {
        if (-not (Test-Path $dst)) {
            Write-Host "Creating directory $dst ..."
            Write-Log "Creating directory $dst ..." 'INFO'
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
        } else {
            Write-Host "Directory $dst already exists. Continuing..."
            Write-Log "Directory $dst already exists. Continuing..." 'INFO'
        }
    }

    Write-Host "Injecting unattend.xml into the VM disk..."
    Write-Log "Injecting unattend.xml into the VM disk..." 'INFO'
    Copy-Item -Path $oobConfigPath -Destination "$($osDrive)\Windows\Panther\unattend.xml" -Force

    Write-Host "Copied unattend.xml to Panther."
    Write-Log "Copied unattend.xml to Panther." 'INFO'
    Copy-Item -Path $oobConfigPath -Destination "$($osDrive)\Windows\System32\Sysprep\unattend.xml" -Force
    Write-Host "Copied unattend.xml to Panther and Sysprep."
    Write-Log "Copied unattend.xml to Sysprep." 'INFO'
}
catch {
    Write-Host "An error occurred while injecting unattend.xml into the VM disk, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while injecting unattend.xml into the VM disk. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}
finally {
    if ($mounted) {
        Dismount-DiskImage -ImagePath $vmDiskPath -ErrorAction SilentlyContinue
        Write-Host "VHDX dismounted."
        Write-Log "VHDX dismounted." 'INFO'
    }
}
#endregion

$cred = New-Object System.Management.Automation.PSCredential(
    'Administrator',
    ($Config.DefaultPassword | ConvertTo-SecureString -AsPlainText -Force)
)

#
# Start the VM
#region
try {
    Write-Host "Starting VM $($CloneName)..."
    Write-Log "Starting VM $($CloneName)..." 'INFO'
    Start-VM -Name $CloneName -ErrorAction Stop
}
catch {
    Write-Host "An error occurred while starting VM $($CloneName), Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while starting VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

Start-VM -Name $CloneName | Out-Null
$result = Wait-VMReady -VMName $CloneName -Stages Running,Heartbeat,IP,PsDirect -Credential $cred -Verbose
$result | Format-List | Out-String | Write-Host
Write-Log "VM $($CloneName) is running and ready." 'INFO'
#endregion

#
# Configure Static IP if needed
#region
Write-Host "Configuring static IP address for VM $($CloneName) if needed..."
try {
    Get-Input -prompt "The VM $($CloneName) has been started.`nDo you want to configure a static IP address now? (y/n)" `
        -defaultValue 'n' `
        -inputType 'string' `
        -options @('y', 'n')
    if ($?) {
        $ipAddress = Get-Input -prompt "Enter the static IP address for VM $($CloneName)" -defaultValue '192.168.1.100' -inputType 'string'
        Write-Host "IP will be set to $($ipAddress)"
        Write-Log "IP will be set to $($ipAddress) for VM $($CloneName)" 'INFO'

        $prefixLength = Get-Input -prompt "Enter the subnet prefix length for VM $($CloneName) (e.g., 24)" -defaultValue 24 -inputType 'int'
        Write-Host "Prefix length will be set to $($prefixLength)"
        Write-Log "Prefix length will be set to $($prefixLength) for VM $($CloneName)" 'INFO'

        $gateway = Get-Input -prompt "Enter the default gateway for VM $($CloneName)" -defaultValue '192.168.1.1' -inputType 'string'
        Write-Host "Gateway will be set to $($gateway)"
        Write-Log "Gateway will be set to $($gateway) for VM $($CloneName)" 'INFO'

        $dnsServersInput = Get-Input -prompt "Enter the DNS server addresses for VM $($CloneName) separated by commas" -defaultValue '8.8.8.8, 8.8.4.4' -inputType 'string'
        Write-Host "DNS servers will be set to $($dnsServersInput)"
        Write-Log "DNS servers will be set to $($dnsServersInput) for VM $($CloneName)" 'INFO'

        $dnsServers = $dnsServersInput -split ',\s*'

        $scriptBlock = {
            param ($ipAddress, $prefixLength, $gateway, $dnsServers)
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1

            Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled
            Set-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway
            for ($i = 0; $i -lt $dnsServers.Count; $i++) {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $dnsServers[$i] -Append
            }
        }

        Write-Host "Applying network configuration to VM $($CloneName)..."
        Write-Log "Applying network configuration to VM $($CloneName)..." 'INFO'
        
        try {
            Invoke-Command -VMName $CloneName -ScriptBlock $scriptBlock -ArgumentList $ipAddress, $prefixLength, $gateway, $dnsServers -Credential $cred
            Write-Host "Configured static IP address for VM $($CloneName)."
            Write-Log "Configured static IP address for VM $($CloneName)." 'INFO'
        }
        catch {
            Write-Host "An error occurred while configuring static IP address for VM $($CloneName), Check the logs for more details." -ForegroundColor Red
            Write-Log "An error occurred while configuring static IP address for VM $($CloneName). Exiting script." 'ERROR'
            Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        }
    }
}
catch {
    Write-Host "An error occurred during static IP configuration prompt, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred during static IP configuration prompt. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}
#endregion

#
# Disk Extension
#region
$extendScriptBlock = {
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $partition = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($disk.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
    $volume = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass=Win32_VolumeToPartition"
    $volume.Expand()
}

Write-Host "Extending C: drive to maximum size on VM $($CloneName)..."


try {
    Invoke-Command -VMName $CloneName -ScriptBlock $extendScriptBlock -Credential $cred
    Write-Host "Extended C: drive to maximum size on VM $($CloneName)."
    Write-Log "Extended C: drive to maximum size on VM $($CloneName)." 'INFO'
}
catch {
    Write-Host "An error occurred while extending C: drive on VM $($CloneName), Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while extending C: drive on VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}
#endregion

Write-Host 'VM cloning process completed successfully.'
Write-Log '--------Clone VM Script Completed--------' 'INFO'
# Clean up log jobs
Get-Job | Where-Object { $_.ScriptBlock.ToString().Contains('Add-Content') } | Remove-Job -Force
exit 0
