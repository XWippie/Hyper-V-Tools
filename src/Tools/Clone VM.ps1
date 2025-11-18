<#
.SYNOPSIS
    Clones a Hyper-V virtual machine from a specified template VM.
.DESCRIPTION
    This script exports a specified template VM, imports it as a new VM with a unique ID,
    and allows the user to configure various settings for the cloned VM, including memory,
    CPU, disk size, and Out-Of-Box Experience (OOBE) settings.
.NOTES
    Author: XWippie
    Date: 11 Nov 2025
    Version: 1.1

    Half tested on Windows Server 2025 with Hyper-V role installed.
    Use at your own risk.
#>

#
# Configuration
#region
$config = @{
    'TemplateVM'        = 'TemplateVM'
    'TemplateVMPath'    = 'C:\\ClusterStorage\\SharedStorage\\Export'
    'ImportPathOptions' = @(
        'C:\\ClusterStorage\\SharedStorage\\VMs',
        'D:\\VMs'
    );
    'DefaultPassword'   = 'P@ssw0rd';
}

$LogFile = "$($PSScriptRoot)\logs\" + ((Get-Date).ToString('ddMMyyHHmmss')) + '_CloneVM.log'

$cred = New-Object System.Management.Automation.PSCredential(
    'Administrator',
    ($Config.DefaultPassword | ConvertTo-SecureString -AsPlainText -Force)
)

$ErrorActionPreference = 'Stop'
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
        $defaultValue,

        [Parameter(Mandatory)]
        [ValidateSet("int", "integer", "str", "string")]
        [string]$inputType,

        [Parameter(Mandatory = $false)]
        [string[]]$options
    )

    Write-Log "Prompting user for input: $prompt with default value: $defaultValue and input type: $inputType" 'DEBUG'

    #if options are provided, loop and go over them 1. www 2. xxx
    if ($options) {
        Write-Host "Please select from the following options:"
        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host "> $($i + 1) - $($options[$i])"
        }
    }

    # Display the prompt and get user input
    while ($true) {
        Write-Log "Displaying prompt to user: $prompt" 'DEBUG'
        $userInput = Read-Host "$prompt [Default: $defaultValue]"
        $userInput = $userInput.Trim()

        Write-Host "User input received: '$userInput'"
        Write-Log "User input received: '$userInput'" 'DEBUG'

        # Use default value if input is empty
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-Log "No input provided, using default value: $defaultValue" 'INFO'
            Write-Host "No input provided, using default value: $defaultValue"
            if ([string]::IsNullOrWhiteSpace($options)) {
                return $defaultValue
            }
            if ($inputType -in @('int', 'integer')) {
                return $options[$defaultValue - 1]
            }
            else {
                return $defaultValue
            }
        }

        # Validate against options if provided
        if ([string]::IsNullOrWhiteSpace($options) -eq $false) {
            if ($inputType -in @('int', 'integer')) {
                foreach ($option in $options) {
                    $index = $options.IndexOf($option) + 1
                    if ($userInput -eq $index) {
                        Write-Log "Valid option selected: $option" 'INFO'
                        return $option
                    }
                }
            }
            else {
                if ($options -notcontains $userInput) {
                    Write-Log "Invalid selection provided: $userInput" 'ERROR'
                    Write-Host "Please enter a valid option from the list." -ForegroundColor Yellow
                    continue
                }
                Write-Log "Valid option selected: $userInput" 'INFO'
                return $userInput
            }
        }

        # Validate input type
        if ($inputType -in @('int', 'integer')) {
            return [int]$userInput
        }
        else {
            return $userInput
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
        [Parameter(Mandatory)] [string] $VMName
    )

    Write-Log "Waiting for VM $VMName to be ready..." 'INFO'
    while ((Get-VM -Name $VMName).State -ne 'Running') {
        Start-Sleep -Seconds 1
        Write-Host "VM $VMName is not running yet. Current state: $((Get-VM -Name $VMName).State)"
    }
    Write-Host "VM $VMName is now running."
    Write-Log "VM $VMName is now running." 'INFO'
    
    Write-Host "Waiting for VM $VMName heartbeat to be OK..."
    Write-Log "Waiting for VM $VMName heartbeat to be OK..." 'INFO'
    while ((Get-VM -Name $VMName).Heartbeat -notlike '*Ok*') {
        Start-Sleep -Seconds 2
        Write-Host "VM $VMName heartbeat is not OK yet. Current heartbeat: $((Get-VM -Name $VMName).Heartbeat)"
    }
    Write-Host "VM $VMName heartbeat is OK."
    Write-Log "VM $VMName heartbeat is OK." 'INFO'

    Write-Host "Waiting for the VM to be reachable via PowerShell Direct..."
    Write-Log "Waiting for the VM to be reachable via PowerShell Direct..." 'INFO'
    #try to connect via powershell direct, while it doen't work wait 3 seconds and try again
    while ($true) {
        try {
            $session = New-PSSession -VMName $VMName -Credential $cred
            if ($session.State -eq 'Opened') {
                Write-Host "Successfully connected to VM $VMName via PowerShell Direct."
                Write-Log "Successfully connected to VM $VMName via PowerShell Direct." 'INFO'
                Remove-PSSession -Session $session
                break
            }
        }
        catch {
            Write-Host "Failed to connect to VM $VMName via PowerShell Direct. Retrying in 3 seconds..."
            Write-Log "Failed to connect to VM $VMName via PowerShell Direct. Retrying in 3 seconds..." 'DEBUG'
            Start-Sleep -Seconds 3
        }
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

# Check if the template VM exists
if (-Not (Get-VM -Name $config.TemplateVM -ErrorAction SilentlyContinue)) {
    Write-Host "Template VM '$($config.TemplateVM)' does not exist on this host. Please check the config file and ensure the VM exists." -ForegroundColor Red
    Write-Log "Template VM '$($config.TemplateVM)' does not exist on this host. Please check the config file and ensure the VM exists." 'ERROR'
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


if ( (Test-Path -Path "$($config.TemplateVMPath)\$($TemplateVM)") ) {
    Write-Host 'An export for the template VM already exists. Skipping export step.'
}
else {
    try {
        Write-Host "Exporting VM $($TemplateVM)"
        Write-Log "Exporting VM $($TemplateVM) to path $($config.TemplateVMPath)" 'INFO'
        Export-VM -Name $TemplateVM -Path $config.TemplateVMPath
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
if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
    Write-Host "A VM with the name $($CloneName) already exists. Please choose a different name. Exiting script." -ForegroundColor Red
    Write-Log "A VM with the name $($CloneName) already exists. Exiting script." 'ERROR'
    exit
}

$ImportPath = Get-Input -prompt 'Select the import path for the cloned VM' -defaultValue 1 -inputType 'int' -options $config.ImportPathOptions

#create a directory for the new vm using import path + vm name
$ImportPath = Join-Path -Path $ImportPath -ChildPath "\\$($CloneName)"

Write-Host "Import directory set to: $($ImportPath)"
Write-Log "Import directory set to: $($ImportPath)" 'INFO'

if (-Not (Test-Path -Path $ImportPath -ErrorAction SilentlyContinue)) {
    try {
        New-Item -ItemType Directory -Path $ImportPath | Out-Null
        Write-Host "Created import directory at $($ImportPath)"
        Write-Log "Created import directory at $($ImportPath)" 'INFO'
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

#endregion

#
# Pre requisites
#region
Write-Host 'Checking for VMCX file in the exported VM directory...'
Write-Log 'Checking for VMCX file in the exported VM directory...' 'INFO'
try {
    $vmcxPath = Get-ChildItem -Path "$($config.TemplateVMPath)/$($TemplateVM)" -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
    if (-Not $vmcxPath) {
        Write-Host 'No VMCX file found in the export directory. Cannot proceed with import., Check the logs for more details.' -ForegroundColor Red
        Write-Log "No VMCX file found in the export directory. ($($config.TemplateVMPath)/$($TemplateVM)). Exiting script." 'ERROR'
        Write-Log "Ensure that the VM was exported correctly and the VMCX file is present." 'ERROR'
        exit
    }
    Write-Host "Found VMCX file at $vmcxPath"
    Write-Log "Found VMCX file at $vmcxPath" 'INFO'
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
        New-Item -ItemType Directory -Path $ImportPath | Out-Null
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


Write-Host 'Ensuring necessary subdirectories exist in the import path...'
Write-Log 'Ensuring necessary subdirectories exist in the import path...' 'INFO'
$subDirs = @('Virtual Machines', 'Snapshots', 'Virtual Hard Disks')
foreach ($dir in $subDirs) {
    $fullPath = Join-Path -Path $ImportPath -ChildPath $dir
    if (-Not (Test-Path -Path $fullPath)) {
        try {
            New-Item -ItemType Directory -Path $fullPath | Out-Null
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
    Start-Transaction
    Import-VM -Path $vmcxPath -Copy -GenerateNewId -VirtualMachinePath $ImportPath -SnapshotFilePath "$($ImportPath)/Snapshots" -VhdDestinationPath "$($ImportPath)/Virtual Hard Disks" | Rename-VM -NewName $CloneName
    Write-Host "Import completed. VM $($CloneName) has been created."
    Write-Log "Import of VM $($TemplateVM) completed successfully as $($CloneName)." 'INFO'
    Complete-Transaction
}
catch {
    Write-Host "An error occurred during import, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred during import of VM $($TemplateVM). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    Undo-Transaction
    exit
}

Write-Host 'Verifying the new VM exists...'
Write-Log 'Verifying the new VM exists...' 'INFO'
if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
    Write-Host "VM $($CloneName) has been successfully created and is available."
    Write-Log "VM $($CloneName) has been successfully created and is available." 'INFO'
}
else {
    Write-Host "Unknown error occurred during the import process."
    Write-Log "Unknown error occurred during the import process." 'ERROR'
    exit
}

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



try {
    Write-Host 'Setting the new VM to use the renamed disk files...'
    Write-Log 'Setting the new VM to use the renamed disk files...' 'INFO'
    Set-VMHardDiskDrive -VMName $CloneName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path "$($ImportPath)/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($TemplateVM), $CloneName)" 
    Write-Host 'Set the VM to use the new disk file successfully.' -ForegroundColor Green
    Write-Log "Set the VM '$CloneName' to use the new disk file." 'INFO'
}
catch {
    Write-Host 'An error occurred while setting the VM to use the new disk file, Check the logs for more details.' -ForegroundColor Red
    Write-Log "An error occurred while setting the VM to use the new disk file for VM '$CloneName'. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

try {
    Write-Host 'Setting CPU compatibility for the new VM...'
    Write-Log 'Setting CPU compatibility for the new VM...' 'INFO'
    Set-VMProcessor -VMName $CloneName -CompatibilityForMigrationEnabled $true
    Write-Host 'Set CPU compatibility successfully.' -ForegroundColor Green
    Write-Log "Set CPU compatibility for VM '$CloneName' successfully." 'INFO'
}
catch {
    Write-Host 'An error occurred while setting CPU compatibility, Check the logs for more details.' -ForegroundColor Red
    Write-Log "An error occurred while setting CPU compatibility for VM '$CloneName'. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

$clusterNodes = @()
if ($ImportPath -like '*ClusterStorage*') {
    # add the vm to the cluster
    Write-Host 'Configuring preferred host for the new VM in the cluster...'
    Write-Log 'Configuring preferred host for the new VM in the cluster...' 'INFO'
    try {
        Add-ClusterVirtualMachineRole -VirtualMachine $CloneName -ErrorAction Stop
        Write-Host "Added VM $($CloneName) to the cluster successfully."
        Write-Log "Added VM $($CloneName) to the cluster successfully." 'INFO'
    }
    catch {
        Write-Host 'An error occurred while adding the VM to the cluster, Check the logs for more details.' -ForegroundColor Red
        Write-Log "An error occurred while adding VM $($CloneName) to the cluster. Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

    try {
        $startupPriority = Get-Input -prompt 'Enter the startup priority for the new VM (1: Low, 2: Medium, 3: High, 4: NoAutoStart)' -defaultValue 2 -inputType 'int' -options @('Low', 'Medium', 'High', 'NoAutoStart')
        switch ($startupPriority) {
            'Low' { $startupPriority = 1000 }
            'Medium' { $startupPriority = 2000 }
            'High' { $startupPriority = 3000 }
            'NoAutoStart' { $startupPriority = 0 }
            default { $startupPriority = 2000 }
        }

        (Get-ClusterGroup $CloneName).Priority = $startupPriority
        
        Write-Host "Set startup priority of VM $($CloneName) to $($startupPriority)."
        Write-Log "Set startup priority of VM $($CloneName) to $($startupPriority)." 'INFO'
    }
    catch {
        Write-Host 'An error occurred while setting the startup priority, Check the logs for more details.' -ForegroundColor Red
        Write-Log "An error occurred while setting the startup priority for VM $($CloneName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }


    try {
        $cluster = Get-Cluster -ErrorAction Stop
        $clusterNodes = $cluster | Get-ClusterNode | Select-Object -ExpandProperty Name
        Write-Host "Cluster nodes retrieved successfully."
        Write-Log "Retrieved cluster nodes: $($clusterNodes -join ', ')" 'INFO'
    }
    catch {
        Write-Host 'An error occurred while retrieving cluster nodes, Check the logs for more details.' -ForegroundColor Red
        Write-Log 'An error occurred while retrieving cluster nodes. Exiting script.' 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

    if ($clusterNodes.Count -gt 0) {
        Write-Host 'Select the preferred host for the new VM:'
        $options = @()
        for ($i = 0; $i -lt $clusterNodes.Count; $i++) {
            $options += $clusterNodes[$i]
        }
        $hostSelection = Get-Input -prompt 'Enter the number corresponding to your choice' -defaultValue 1 -inputType 'int' -options $options
        $preferredHost = $hostSelection
        try {
            Get-ClusterGroup -Name "$CloneName" | Set-ClusterOwnerNode -Owners "$preferredHost"
            Write-Host "Set preferred host of VM $($CloneName) to $($preferredHost)."
            Write-Log "Set preferred host of VM $($CloneName) to $($preferredHost)." 'INFO'
        }
        catch {
            Write-Host "An error occurred while setting the preferred host, Check the logs for more details." -ForegroundColor Red
            Write-Log "An error occurred while setting the preferred host for VM $($CloneName). Exiting script." 'ERROR'
            Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        }
    }
    else {
        Write-Host 'No cluster nodes found. Skipping preferred host configuration.' -ForegroundColor Yellow
        Write-Log 'No cluster nodes found. Skipping preferred host configuration.' 'WARNING'
    }
}
#endregion

#
# Configure the new VM
#region
Write-Host 'Configuring the new VM settings...'
Write-Log 'Configuring the new VM settings...' 'INFO'

$startDelay = Get-Input -prompt "Enter the startup delay (in seconds) for the new VM $($CloneName)" -defaultValue 0 -inputType 'string'
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

$stopaction = Get-Input -prompt "Enter the automatic stop action for the new VM $($CloneName) (1: Save, 2: Turn Off, 3: Shut Down)" -defaultValue 3 -inputType 'int' -options @('Save', 'TurnOff', 'ShutDown')
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

$ramValue = Get-Input -prompt "Enter the amount of memory (in GB) to allocate to the new VM $($CloneName)" -defaultValue 4 -inputType 'string'
try {
    # convert string to int
    $ramValue = [int]$ramValue
    $ValueInMB = $ramValue * 1GB
    Write-Host "Setting memory to $($ValueInMB/1MB)MB"
    Set-VMMemory -VMName $CloneName -DynamicMemoryEnabled $false -StartupBytes $($ValueInMB)
    Write-Host "Set the memory of VM $($CloneName) to $($ramValue) GB."
    Write-Log "Set the memory of VM $($CloneName) to $($ramValue) GB." 'INFO'
}
catch {
    Write-Host "An error occurred while setting the memory for VM $($CloneName): $_"
    Write-Log "An error occurred while setting the memory for VM $($CloneName). Exiting script." 'ERROR'
}

$cpuAmount = Get-Input -prompt "Enter the number of virtual processors to allocate to the new VM $($CloneName)" -defaultValue 1 -inputType 'string'
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
# configure OOBE
#region
Write-Host 'Configuring Out-Of-Box Experience (OOBE) settings for the new VM...'
Write-Log 'Configuring Out-Of-Box Experience (OOBE) settings for the new VM...' 'INFO'


$oobConfigPath = 'Config\unattend.xml'
if (-Not (Test-Path -Path 'Config')) {
    try {
        New-Item -ItemType Directory -Path 'Config' | Out-Null
        Write-Host 'Created Config directory for OOBE configuration.'
        Write-Log 'Created Config directory for OOBE configuration.' 'INFO'
    }
    catch {
        Write-Host 'An error occurred while creating the Config directory for OOBE configuration, Check the logs for more details.' -ForegroundColor Red
        Write-Log 'An error occurred while creating the Config directory for OOBE configuration. Exiting script.' 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        exit
    }
}
else {
    Write-Host 'Config directory already exists, continuing...'
    Write-Log 'Config directory already exists, continuing...' 'INFO'
}

$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">

  <!-- ========================= -->
  <!-- 1. windowsPE Pass         -->
  <!-- ========================= -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <UILanguage>en-US</UILanguage>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

      <!-- Edition/Product Key (optional) -->
      <UserData>
        <ProductKey>
          <Key>00000-00000-00000-00000-00000</Key>
        </ProductKey>
        <AcceptEula>true</AcceptEula>
      </UserData>

      <ImageInstall>
        <OSImage>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>2</PartitionID>
          </InstallTo>
          <WillShowUI>OnError</WillShowUI>
        </OSImage>
      </ImageInstall>

      <ComputerName>{{COMPUTER_NAME}}</ComputerName>

    </component>
  </settings>

  <!-- ========================= -->
  <!-- 2. specialize Pass        -->
  <!-- ========================= -->
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

      <ComputerName>{{COMPUTER_NAME}}</ComputerName>
      <TimeZone>{{TIMEZONE}}</TimeZone>

    </component>

  </settings>

  <!-- ========================= -->
  <!-- 3. oobeSystem Pass        -->
  <!-- ========================= -->
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
        <InputLocale>0409:00000813</InputLocale>
        <SystemLocale>en-US</SystemLocale>
        <UILanguage>en-US</UILanguage>
        <UserLocale>en-US</UserLocale>    
    </component>

    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

      <!-- Skip first-boot OOBE -->
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>

      <!-- Create Local Admin -->
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>{{LOCAL_ADMIN}}</Name>
            <Group>Administrators</Group>
            <Password>
              <Value>{{LOCAL_ADMIN_PASSWORD}}</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

      <!-- Auto Logon (optional) -->
      <!-- Remove if not needed -->
      <AutoLogon>
        <Password>
          <Value>{{LOCAL_ADMIN_PASSWORD}}</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <Username>{{LOCAL_ADMIN}}</Username>
        <LogonCount>1</LogonCount>
      </AutoLogon>

    </component>
  </settings>

</unattend>
"@

# Replace placeholders in unattend.xml
$unattendXml = $unattendXml -replace '{{COMPUTER_NAME}}', $CloneName
$unattendXml = $unattendXml -replace '{{TIMEZONE}}', "Romance Standard Time"
$unattendXml = $unattendXml -replace '{{LOCAL_ADMIN}}', 'Administrator'
$unattendXml = $unattendXml -replace '{{LOCAL_ADMIN_PASSWORD}}', $Config.DefaultPassword



try {
    Write-Host "Creating unattend at $oobConfigPath..."
    Write-Log "Creating unattend at $oobConfigPath..." 'INFO'
    $unattendXml | Out-File -FilePath $oobConfigPath -Encoding UTF8 -Force
    Write-Host "Unattend created."
    Write-Log "Unattend created successfully at $oobConfigPath." 'INFO'
}
catch {
    Write-Host "An error occurred while creating unattend.xml, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while creating unattend.xml at $oobConfigPath. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    exit
}

$vmDiskPath = Join-Path -Path $ImportPath -ChildPath "Virtual Hard Disks\$($CloneName).vhdx"
$mounted = $false
try {
    Write-Host "Mounting $($vmDiskPath) ..."
    Write-Log "Mounting $($vmDiskPath) ..." 'INFO'
    
    Mount-DiskImage -ImagePath $vmDiskPath -Passthru | Out-Null
    $mounted = $true
    
    Write-Host "Mounted VHDX successfully."
    Write-Log "Mounted VHDX successfully." 'INFO'
    
    $disk = Get-DiskImage -ImagePath $vmDiskPath | Get-Disk | Get-Partition | Where-Object { $_.Type -eq 'Basic' } | Select-Object -First 1
    Set-Partition -DiskNumber $disk.DiskNumber -PartitionNumber $disk.PartitionNumber -NewDriveLetter "X" -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 2
    $osDrive = (Get-Partition -DiskNumber $disk.DiskNumber -PartitionNumber $disk.PartitionNumber).DriveLetter + ":"

    Write-Host "OS Drive Letter is $($osDrive)"
    Write-Log "OS Drive Letter is $($osDrive)" 'INFO'

    $dst = "$($osDrive)\Windows\Panther"

    Write-Host "Injecting unattend.xml into the VM disk..."
    Write-Log "Injecting unattend.xml into the VM disk..." 'INFO'
    Copy-Item -Path "$($oobConfigPath)" -Destination "$($dst)\unattend.xml" -Force

    Write-Host "Copied unattend.xml to Panther."
    Write-Log "Copied unattend.xml to Panther." 'INFO'

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

Start-Sleep -Seconds 3

#
# Start the VM
#region
try {
    Write-Host "Starting VM $($CloneName)..."
    Write-Log "Starting VM $($CloneName)..." 'INFO'
    Start-VM -Name $CloneName -ErrorAction Stop
    Wait-VMReady -VMName $CloneName
}
catch {
    Write-Host "An error occurred while starting VM $($CloneName), Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while starting VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}
Write-Log "VM $($CloneName) is running and ready." 'INFO'
#endregion

#
# Configure Static IP if needed
#region
if (-Not (Get-VMNetworkAdapter -VMName $CloneName -ErrorAction SilentlyContinue)) {
    Write-Host "No network adapter found for VM $($CloneName). Adding a new network adapter..."
    Write-Log "No network adapter found for VM $($CloneName). Adding a new network adapter..." 'INFO'
    
    try {
        $switches = Get-VMSwitch | Select-Object -ExpandProperty Name
        $switchOptions = @()
        for ($i = 0; $i -lt $switches.Count; $i++) {
            $switchOptions += $switches[$i]
        }
        $switchSelection = Get-Input -prompt 'Enter the number corresponding to the virtual switch to connect the new VM to' -defaultValue 1 -inputType 'int' -options $switchOptions
        $selectedSwitch = $switchSelection
        Write-Host "Selected Virtual Switch: $($selectedSwitch)"
        Write-Log "Selected Virtual Switch: $($selectedSwitch) for VM $($CloneName)" 'INFO'
    }
    catch {
        Write-Host "An error occurred while selecting the virtual switch, Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while selecting the virtual switch for VM $($CloneName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

    try {
        Add-VMNetworkAdapter -VMName $CloneName -SwitchName $selectedSwitch
        Write-Host "Added network adapter to VM $($CloneName)."
        Write-Log "Added network adapter to VM $($CloneName)." 'INFO'
    }
    catch {
        Write-Host "An error occurred while adding a network adapter to VM $($CloneName), Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while adding a network adapter to VM $($CloneName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

    try {
        $vlanChoice = Get-Input -prompt "Do you want to set a VLAN ID for the network adapter on VM $($CloneName)? (y/n)" `
            -defaultValue 'n' `
            -inputType 'string' `
            -options @('y', 'n')
        if ($vlanChoice -eq 'y') {
            $vlanId = Get-Input -prompt "Enter the VLAN ID to set for the network adapter on VM $($CloneName)" -defaultValue 10 -inputType 'int'
            Set-VMNetworkAdapterVlan -VMName $CloneName -Access -VlanId $vlanId
            Write-Host "Set VLAN ID $($vlanId) for network adapter on VM $($CloneName)."
            Write-Log "Set VLAN ID $($vlanId) for network adapter on VM $($CloneName)." 'INFO'
        }
    }
    catch {
        Write-Host "An error occurred while setting VLAN ID for VM $($CloneName), Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while setting VLAN ID for VM $($CloneName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

    try {
        $adapterName = Get-Input -prompt "Enter a name for the network adapter on VM $($CloneName)" -defaultValue 'Ethernet0' -inputType 'string'
        Rename-VMNetworkAdapter -VMName $CloneName -NewName $adapterName
        Write-Host "Renamed network adapter to $($adapterName) on VM $($CloneName)."
        Write-Log "Renamed network adapter to $($adapterName) on VM $($CloneName)." 'INFO'
    }
    catch {
        Write-Host "An error occurred while renaming the network adapter for VM $($CloneName), Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while renaming the network adapter for VM $($CloneName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }

}
else {
    Write-Host "Network adapter already exists for VM $($CloneName), continuing..."
    Write-Log "Network adapter already exists for VM $($CloneName), continuing..." 'INFO'
}

Write-Host "Configuring static IP address for VM $($CloneName) if needed..."
try {
    $NetadaptorConfigReply = Get-Input -prompt "The VM $($CloneName) has been started.`nDo you want to configure a static IP address now? (y/n)" `
        -defaultValue 'n' `
        -inputType 'string' `
        -options @('y', 'n')
    if ($NetadaptorConfigReply -eq 'y') {
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
            param ($ipAddress, $prefixLength, $gateway, $dnsServers, $adapterName)
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1

            Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled
            New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $dnsServers
            Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Enabled $false
            Rename-NetAdapter -Name $adapter.Name -NewName $adapterName
        }

        Write-Host "Applying network configuration to VM $($CloneName)..."
        Write-Log "Applying network configuration to VM $($CloneName)..." 'INFO'
        
        try {
            Invoke-Command -VMName $CloneName -ScriptBlock $scriptBlock -ArgumentList $ipAddress, $prefixLength, $gateway, $dnsServers, $adapterName -Credential $cred
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
if ($NetadaptorConfigReply -eq 'y') {
    $extendScriptBlock = {
        $drive_letter = "C"
        $size = (Get-PartitionSupportedSize -DriveLetter $drive_letter)
        Resize-Partition -DriveLetter $drive_letter -Size $size.SizeMax
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
}
else {
    Write-Host "Skipping disk extension as static IP configuration was not performed."
    Write-Log "Skipping disk extension as static IP configuration was not performed." 'INFO'
}
#endregion

# remove unattend file
try {
    $removeUnattendScriptBlock = {
        $unattendPath = "C:\Windows\Panther\unattend.xml"
        if (Test-Path -Path $unattendPath) {
            Remove-Item -Path $unattendPath -Force
        }
    }

    Write-Host "Removing unattend.xml from VM $($CloneName)..."
    Invoke-Command -VMName $CloneName -ScriptBlock $removeUnattendScriptBlock -Credential $cred
    Write-Host "Removed unattend.xml from VM $($CloneName)."
    Write-Log "Removed unattend.xml from VM $($CloneName)." 'INFO'
}
catch {
    Write-Host "An error occurred while removing unattend.xml from VM $($CloneName), Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while removing unattend.xml from VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

# ask the user for a password of the local admin account (secure)
try {
    $newPassword = Read-Host "Please enter a new password for the local administrator account on VM $($CloneName)" -AsSecureString
    $changePasswordScriptBlock = {
        param ([securestring]$newPassword)
        $adminUser = [ADSI]"WinNT://./Administrator,user"
        $adminUser.SetPassword([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPassword)))
    }

    Write-Host "Changing password for local administrator account on VM $($CloneName)..."
    Invoke-Command -VMName $CloneName -ScriptBlock $changePasswordScriptBlock -ArgumentList $newPassword -Credential $cred
    Write-Host "Changed password for local administrator account on VM $($CloneName)."
    Write-Log "Changed password for local administrator account on VM $($CloneName)." 'INFO'
}
catch {
    Write-Host "An error occurred while changing the password for local administrator account on VM $($CloneName), Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while changing the password for local administrator account on VM $($CloneName). Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

#Setting new credentials for further operations
$cred = New-Object System.Management.Automation.PSCredential ('Administrator', $newPassword)

#Domain joining
#ask the use if they want to join the vm to a domain
$userChoice = Get-Input -prompt "Do you want to join the VM $($CloneName) to a domain? (y/n)" `
    -defaultValue 'n' `
    -inputType 'string' `
    -options @('y', 'n')
if ($userChoice -eq 'n') {
    Write-Host "Skipping domain join for VM $($CloneName) as per user choice"
}
else {
    try {
        New-Variable Domcreds -Value (Get-Credential -Message "Enter domain credentials with permissions to join computers to the domain") -Force
        $joinDomainScriptBlock = {
            param ($domainName, $ouPath, $Domcreds)
            Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $Domcreds -Restart:$true
        }
        $domainName = Get-Input -prompt "Enter the domain name to join for VM $($CloneName)" -defaultValue 'contoso.com' -inputType 'string'
        $ouPath = Get-Input -prompt "Enter the OU path to join the computer to" -defaultValue 'OU=Computers,DC=contoso,DC=com' -inputType 'string'
        Write-Host "Joining VM $($CloneName) to domain $($domainName)..."
        Write-Log "Joining VM $($CloneName) to domain $($domainName)..." 'INFO'
        Invoke-Command -VMName $CloneName -ScriptBlock $joinDomainScriptBlock -ArgumentList $domainName, $ouPath, $Domcreds -Credential $cred
    }
    catch {
        Write-Host "An error occurred while joining VM $($CloneName) to domain $($domainName), Check the logs for more details." -ForegroundColor Red
        Write-Log "An error occurred while joining VM $($CloneName) to domain $($domainName). Exiting script." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
    }
    finally {
        Remove-Variable Domcreds -ErrorAction SilentlyContinue
    }
    Wait-VMReady -VMName $CloneName
}



# move the vm to its preferred host if set
try {
    #if preferred is current host skip
    $currentHost = (Get-VMHost).Name
    if ($preferredHost -ne $currentHost) {
        Move-VM -Name $CloneName -DestinationHost $preferredHost
        Write-Host "Moved VM $($CloneName) to its preferred host successfully."
        Write-Log "Moved VM $($CloneName) to its preferred host successfully." 'INFO'
    }
    else {
        Write-Host "VM $($CloneName) is already on its preferred host $($preferredHost). Skipping move."
        Write-Log "VM $($CloneName) is already on its preferred host $($preferredHost). Skipping move." 'INFO'
    }   
}
catch {
    Write-Host "An error occurred while moving the VM to its preferred host, Check the logs for more details." -ForegroundColor Red
    Write-Log "An error occurred while moving VM $($CloneName) to its preferred host. Exiting script." 'ERROR'
    Write-Log "Details: $($_.Exception.Message)" 'ERROR'
}

Write-Host 'VM cloning process completed successfully.'
Write-Log '--------Clone VM Script Completed--------' 'INFO'
exit 0
