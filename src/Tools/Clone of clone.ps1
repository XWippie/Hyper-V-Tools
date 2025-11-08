#
# Logging
#region
function Write-Log {
    <#
    .SYNOPSIS
        Write log entries to a log file.

    .DESCRIPTION
        This function writes log entries to a log file located in the logs directory.
        Each log entry is timestamped and categorized by type (e.g., INFO, ERROR).

    .PARAMETER Message
        The log message to be written to the log file.

    .PARAMETER LogType
        The type of log entry (DEBUG, INFO, WARN, ERROR). Default is INFO.

    .EXAMPLE
        Write-Log -Message 'This is an informational message.' -LogType 'INFO'
        example output:
        [12-09-2023 14:23:45] [INFO] This is an informational message.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$type = 'INFO'
    )

    


    if (-Not (Test-Path -Path "$($PSScriptRoot)\logs")) {
        New-Item -ItemType Directory -Path "$($PSScriptRoot)\logs" | Out-Null
    }

    # Create a timestamped log entry
    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'dd-MM-yyyy HH:mm:ss'), $type, $Message

    # Run the write in a background job so it doesn't block
    Start-Job -ScriptBlock {
        param($entry, $logFile)
        Add-Content -Path $logFile -Value $entry
    } -ArgumentList $entry, $LogFile | Out-Null
}
#endregion

#
# Configuration
#region
$config = @{
    'TemplateVM'        = 'TemplateVM'
    'TemplateVMPath'    = 'D:\\VMs\\Exports'
    'ImportPathOptions' = @(
        'C:\\ClusterStorage\\SharedStorage',
        'D:\\VMs\\'
    )
}

$LogFile = "$($PSScriptRoot)\logs\" + ((Get-Date).ToString('ddMMyyHHmmss')) + '_CloneVM.log'
#endregion

#
# IMport Modules
#region
try {
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

    while ($true) {
        Write-Log "Displaying prompt to user: $prompt" 'DEBUG'
        $userInput = Read-Host "$prompt [Default: $defaultValue]"
        $userInput = $userInput.Trim()

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
            Write-Log "Valid integer input provided: $parsedInput" 'INFO'
            return $parsedInput
        }
        else {
            Write-Log "Valid string input provided: $userInput" 'INFO'
            return $userInput
        }
    }
}
#endregion

#
# Start of Script
Write-Log '--------Starting Clone VM Script--------' 'INFO'

#
# Check Wif tempalte vm is valid and exists
#region
Write-Log 'Beginning Template Exoprt Check' 'INFO'

if ([string]::IsNullOrWhiteSpace($config.TemplateVM)) {
    Write-Host "Template VM is not set in the config file.`nPlease enter the name of the VM you want to in the config file under $($config.TemplateVM)" -ForegroundColor Red
    Write-Log 'Template VM is not set in the config file. Exiting script.' 'ERROR'
    exit 
}
Write-Log 'Template VM is set in the config file.' 'INFO'

if ( (Test-Path -Path "$($ExportPath)\$($config.TemplateVM)") ) {
    Write-Host 'An export for the template VM already exists. Skipping export step.'
}
else {
    try {
        Write-Host "Exporting VM $($config.TemplateVM)"
        Write-Log "Exporting VM $($config.TemplateVM) to path $ExportPath" 'INFO'
        Export-VM -Name $config.TemplateVM -Path $ExportPath -WhatIf
        Write-Host 'Export completed.'
        Write-Log "Export of VM $($config.TemplateVM) completed successfully." 'INFO'
    }
    catch {
        Write-Host "An error occurred during export of VM $($config.TemplateVM)"
        Write-Log "An error occurred during export of VM $($config.TemplateVM). Check the logs for more details." 'ERROR'
        Write-Log "Details: $($_.Exception.Message)" 'ERROR'
        exit
    }   
}
#endregion

#
# Variables and User Input
#region
$TargetHost = Get-Input -prompt 'Enter the target Hyper-V host name' -defaultValue $env:COMPUTERNAME -inputType 'string'
$CloneName = Get-Input -prompt 'Enter the name for the cloned VM' -defaultValue "$($config.TemplateVM)_Clone" -inputType 'string'
$ImportPath = Get-Input -prompt 'Select the import path for the cloned VM' -defaultValue '1' -inputType 'string' -options $config.ImportPathOptions
#endregion



function Get-ImportPathOption {
    while ($true) {
        $importOption = Read-Host 'Choose import path option (1 or 2):`n1. C:\ClusterStorage\SharedStorage\VMs\$CloneName`n2. D:\VMs\$CloneName`nEnter 1 or 2 (default is 1)'
        if ($importOption -eq '2') {
            return 'D:\VMs\$CloneName'
        }
        elseif ($importOption -eq '1' -or [string]::IsNullOrWhiteSpace($importOption)) {
            return 'C:\ClusterStorage\SharedStorage\VMs\$CloneName'
        }
        else {
            Write-Host 'Invalid option selected. Please enter 1 or 2.' -ForegroundColor Red
        }
    }
}

$ImportPath = Get-ImportPathOption




# check in a VMCX file iwith extension exists in the import path (i don't know the name of the file so i check for the extension) if exists get the path of the file
if (Get-ChildItem -Path '$ExportPath/$Config.TemplateVM' -Filter *.vmcx -Recurse -ErrorAction SilentlyContinue) {
    Write-Host 'A VMCX is present, continuing...'
    $vmcxPath = Get-ChildItem -Path '$ExportPath/$Config.TemplateVM' -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
}
else {
    # Get the path of the VMCX file in the exported VM folder
    $vmcxPath = Get-ChildItem -Path '$ExportPath/$Config.TemplateVM' -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
    if (-Not $vmcxPath) {
        Write-Host 'No VMCX file found in the export directory. Cannot proceed with import.'
        Write-Host 'Please delete the export directory and try again.'
        exit
    }
}

# Create import directory if it doesn't exist
if (-Not (Test-Path -Path $ImportPath)) {
    try {
        New-Item -ItemType Directory -Path $ImportPath
        Write-Host 'Created import directory at $ImportPath'
    }
    catch {
        Write-Host 'An error occurred while creating the import directory: $_'
        exit
    }
    
}
else {
    Write-Host 'Import directory already exists at $ImportPath'
}

# Create subdirectories for the import process
$subDirs = @('Virtual Machines', 'Snapshots', 'Virtual Hard Disks')
foreach ($dir in $subDirs) {
    $fullPath = Join-Path -Path $ImportPath -ChildPath $dir
    if (-Not (Test-Path -Path $fullPath)) {
        try {
            New-Item -ItemType Directory -Path $fullPath
            Write-Host 'Created subdirectory: $fullPath'
        }
        catch {
            Write-Host 'An error occurred while creating subdirectory $($dir): $_'
            exit
        }
    }
    else {
        Write-Host 'Subdirectory already exists: $fullPath'
    }
}

try {
    # Import as a new VM with a unique ID
    Write-Host 'Importing VM from $vmcxPath to $ImportPath with new name $CloneName'
    Import-VM -Path $vmcxPath -Copy -GenerateNewId -VirtualMachinePath '$ImportPath' -SnapshotFilePath '$ImportPath/Snapshots' -VhdDestinationPath '$ImportPath/Virtual Hard Disks' | Rename-VM -NewName $CloneName
    Write-Host 'Import completed. VM $CloneName has been created.'
}
catch {
    Write-Host 'An error occurred during import: $_'
    exit
}

# Verify the new VM
if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
    Write-Host 'VM $CloneName has been successfully created and is available.'
}
else {
    Write-Host 'Failed to create VM $CloneName.'
    Write-Host 'Unknown error occurred during the import process.'
    exit
}

# Rename the disk files to match the new VM name
$diskFiles = Get-ChildItem -Path '$ImportPath/Virtual Hard Disks'
foreach ($disk in $diskFiles) {
    $newDiskName = $disk.Name -replace [regex]::Escape($Config.TemplateVM), $CloneName
    try {
        Rename-Item -Path $disk.FullName -NewName $newDiskName
        Write-Host 'Renamed disk file $($disk.Name) to $newDiskName'
    }
    catch {
        Write-Host 'An error occurred while renaming disk file $($disk.Name): $_'
    }
}

# ask the startup deploy 
$starDelay = Get-Input -prompt "Enter the startup delay (in seconds) for the new VM '$CloneName'"`
    -defaultValue 0`
-inputType 'int'
# Set the startup delay for the new VM
try {
    Set-VM -Name $CloneName -AutomaticStartDelay $starDelay
    Write-Host "Set the startup delay of VM '$CloneName' to $starDelay seconds."
}
catch {
    Write-Host "An error occurred while setting the startup delay for VM '$CloneName': $_"
}

$stopaction = Get-Input -prompt "Enter the automatic stop action for the new VM '$CloneName' (0: Save, 1: Turn Off, 2: Shut Down)"`
    -defaultValue 2`
-inputType 'int'
# Set the automatic stop action for the new VM
try {
    Set-VM -Name $CloneName -AutomaticStopAction $stopaction
    Write-Host "Set the automatic stop action of VM '$CloneName' to $stopaction."
}
catch {
    Write-Host "An error occurred while setting the automatic stop action for VM '$CloneName': $_"
}


# Set the vm to use the new disk files
try {
    Set-VMHardDiskDrive -VMName $CloneName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path '$ImportPath/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($Config.TemplateVM), $CloneName)' 
    Write-Host 'Set the VM $CloneName to use the new disk file.'
}
catch {
    Write-Host 'An error occurred while setting the VM to use the new disk file: $_'
}

# rename hostname
try {
    Invoke-Command -VMName $CloneName -ScriptBlock {
        param ($newHostname)
        Rename-Computer -NewName $newHostname -Force -Restart
    } -ArgumentList $CloneName
    Write-Host 'Renamed the hostname of VM $CloneName to $CloneName and restarted the VM.'
}
catch {
    Write-Host 'An error occurred while renaming the hostname of VM $CloneName`n$_'
}

# Get total physical memory (in GB) on the host
try {
    $TotalMemoryBytes = (Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $TargetHost).TotalPhysicalMemory
}
catch {
    Write-Host "Failed to connect to host '$TargetHost'. Please check the name or permissions." -ForegroundColor Red
    exit
}
$TotalMemoryGB = [math]::Round($TotalMemoryBytes / 1GB)

# Get all available memory on the host
$AvailableMemoryGB = $TotalMemoryGB - (Get-VM | Measure-Object -Property Memory -Sum).Sum / 1GB

Write-Host "Host $TargetHost has $TotalMemoryGB GB total memory, with $AvailableMemoryGB GB available for new VMs.`n"

$ramValue = Get-Input -prompt "Enter the amount of memory (in GB) to allocate to the new VM '$CloneName'"`
    -defaultValue 4`
-inputType 'int'

# Set the memory for the new VM
try {
    Set-VMMemory -VMName $CloneName -StartupBytes ($ramValue * 1GB)
    Write-Host "Set the memory of VM '$CloneName' to $ramValue GB."
}
catch {
    Write-Host "An error occurred while setting the memory for VM '$CloneName': $_"
}

$cpuAmount = Get-Input -prompt "Enter the number of virtual processors to allocate to the new VM '$CloneName'"`
    -defaultValue 1`
-inputType 'int'
# Set the CPU count for the new VM
try {
    Set-VMProcessor -VMName $CloneName -Count $cpuAmount
    Write-Host "Set the CPU count of VM '$CloneName' to $cpuAmount."
}
catch {
    Write-Host "An error occurred while setting the CPU count for VM '$CloneName': $_"
}

$diskSizeGB = Get-Input -prompt "Enter the new disk size (in GB) for the VM '$CloneName'"`
    -defaultValue 50`
-inputType 'int'
# Resize the virtual hard disk if bigger than 50GB
if ($diskSizeGB -gt 50) {
    try {
        Resize-VHD -Path '$ImportPath/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($Config.TemplateVM), $CloneName)' -SizeBytes ($diskSizeGB * 1GB)
        Write-Host "Resized the virtual hard disk of VM '$CloneName' to $diskSizeGB GB."
    }
    catch {
        Write-Host "An error occurred while resizing the virtual hard disk for VM '$CloneName': $_"
    }
}

# configer OOB using xml file
#makethe file
$oobConfigPath = '$PSScriptRoot\..\Config\unattend.xml'
$oobXmlContent = @"
<Configuration>
    <ComputerName>$CloneName</ComputerName>
    <AdministratorPassword>
        <Value>Pa$$w0rd!</Value>
        <PlainText>true</PlainText>
    </AdministratorPassword>
    <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Username>Administrator</Username>
        <Password>
            <Value>Pa$$w0rd!</Value>
            <PlainText>true</PlainText>
        </Password>
    </AutoLogon>
    <FirstLogonCommands>
        <SynchronousCommand>
            <CommandLine>powershell -ExecutionPolicy Bypass -File C:\Setup\Scripts\PostOOBE.ps1</CommandLine>
            <Order>1</Order>
            <Description>Post OOBE Script</Description>
        </SynchronousCommand>
    </FirstLogonCommands>
</Configuration>
"@

# Create the OOB configuration file
try {
    Write-Host "Creating OOB configuration file at $oobConfigPath."
    Set-Content -Path $oobConfigPath -Value $oobXmlContent -Force
    Write-Host "OOB configuration file created successfully."
}
catch {
    Write-Host "An error occurred while creating the OOB configuration file: $_"
}

# Mount the vm disk to copy the file
try {
    $vmDiskPath = "$($ImportPath)/Virtual Hard Disks/$($CloneName).vhdx"
    $mountResult = Mount-DiskImage -ImagePath $vmDiskPath -PassThru
    $driveLetter = ($mountResult | Get-Volume).DriveLetter + ':'
    Write-Host "Mounted VM disk at drive letter $driveLetter"
}
catch {
    Write-Host "An error occurred while mounting the VM disk: $_"
    exit
}
finally {
    Dismount-DiskImage -ImagePath $vmDiskPath
}

# Copy the OOB configuration file to the VM's setup directory
try {
    $destinationPath = "$driveLetter\Windows\Panther"
    if (-Not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force
    }
    Copy-Item -Path $oobConfigPath -Destination "$destinationPath\unattend.xml" -Force
    Write-Host "Copied OOB configuration file to $destinationPath"
}
catch {
    Write-Host "An error occurred while copying the OOB configuration file: $_"
}
finally {
    # Dismount the disk image in case of error during copy
    Dismount-DiskImage -ImagePath $vmDiskPath
}

# start the VM
try {
    Start-VM -Name $CloneName
    Write-Host "Started VM '$CloneName'."
}
catch {
    Write-Host "An error occurred while starting VM '$CloneName': $_"
}

# Wait for the vm to boot up
while (-not (Get-VM -Name $CloneName | Where-Object { $_.State -eq 'Running' })) {
    Start-Sleep -Seconds 5 
}

# create scriptblock to run in the VM with no network
$scriptBlock = {
    param ($ipAddress, $prefixLength, $gateway, $dnsServers)
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1

    Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled
    Set-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway
    for ($i = 0; $i -lt $dnsServers.Count; $i++) {
        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $dnsServers[$i] -Append
    }
}

try {
    Get-Input -prompt "The VM '$CloneName' has been started.`nDo you want to configure a static IP address now? (y/n)" `
        -defaultValue 'n' `
        -inputType 'string' `
        -options @('y', 'n')
    if ($?) {
        $ipAddress = Get-Input -prompt "Enter the static IP address for VM '$CloneName'" `
            -defaultValue '192.168.1.100' `
            -inputType 'string'
        $prefixLength = Get-Input -prompt "Enter the subnet prefix length for VM '$CloneName' (e.g., 24)" `
            -defaultValue 24 `
            -inputType 'int'
        $gateway = Get-Input -prompt "Enter the default gateway for VM '$CloneName'" `
            -defaultValue '192.168.1.1' `
            -inputType 'string'
        $dnsServersInput = Get-Input -prompt "Enter the DNS server addresses for VM '$CloneName' separated by commas" `
            -defaultValue '8.8.8.8, 8.8.4.4' `
            -inputType 'string'
        $dnsServers = $dnsServersInput -split ',\s*'

        try {
            Invoke-Command -VMName $CloneName -ScriptBlock $scriptBlock -ArgumentList $ipAddress, $prefixLength, $gateway, $dnsServers
            Write-Host "Configured static IP address for VM '$CloneName'."
        }
        catch {
            Write-Host "An error occurred while configuring static IP address for VM '$CloneName': $_"
        }
    }
}
catch {
    Write-Host "An error occurred during static IP configuration prompt: $_"
}

# Send a command to the vm to extend the c drive to the maximum size available
$extendScriptBlock = {
    $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $partition = Get-WmiObject -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($disk.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
    $volume = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass=Win32_VolumeToPartition"
    $volume.Extend()
}

try {
    Invoke-Command -VMName $CloneName -ScriptBlock $extendScriptBlock
    Write-Host "Extended C: drive to maximum size on VM '$CloneName'."
}
catch {
    Write-Host "An error occurred while extending C: drive on VM '$CloneName': $_"
}

Write-Log '--------Clone VM Script Completed--------' 'INFO'
Write-Host 'VM cloning process completed successfully.'
# Clean up log jobs
Get-Job | Where-Object { $_.ScriptBlock.ToString().Contains('Add-Content') } | Remove-Job -Force
exit