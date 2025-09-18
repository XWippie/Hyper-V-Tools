$ExportPath = "C:\ClusterStorage\SharedStorage\Export"

$SourceVM = "LYBATemplate2025"
$SourceVM = Read-Host "Source VM to clone is (default: $SourceVM)"
if ([string]::IsNullOrWhiteSpace($SourceVM)) {
    $SourceVM = "LYBATemplate2025"
}
#check if an export with the same name exists
if ( (Test-Path -Path "$ExportPath\$SourceVM") ) {
    Write-Host "A export already exists"
    # Skipping the cloning process
    Write-Host "Skipping the cloning process."
} else {
    try {
        # Export the source VM
        Write-Host "Exporting VM $SourceVM to $ExportPath"
        Export-VM -Name $SourceVM -Path $ExportPath
        Write-Host "Export completed."
    }
    catch {
        Write-Host "An error occurred during export: $_"
        exit
    }   
}

$CloneName = ""
While ([string]::IsNullOrWhiteSpace($CloneName)) {
    $CloneName = Read-Host "Please enter a valid name for the new VM"
    if ([string]::IsNullOrWhiteSpace($CloneName)) {
        Write-Host "The VM name cannot be empty. Please try again." -ForegroundColor Red
        continue
    }
    if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
        Write-Host "A VM with the name $CloneName already exists. Please choose a different name." -ForegroundColor Red
        $CloneName = ""
    }
}

function Get-ImportPathOption {
    while ($true) {
        $importOption = Read-Host "Choose import path option (1 or 2):`n1. C:\ClusterStorage\SharedStorage\VMs\$CloneName`n2. D:\VMs\$CloneName`nEnter 1 or 2 (default is 1)"
        if ($importOption -eq "2") {
            return "D:\VMs\$CloneName"
        } elseif ($importOption -eq "1" -or [string]::IsNullOrWhiteSpace($importOption)) {
            return "C:\ClusterStorage\SharedStorage\VMs\$CloneName"
        } else {
            Write-Host "Invalid option selected. Please enter 1 or 2." -ForegroundColor Red
        }
    }
}

$ImportPath = Get-ImportPathOption




# check in a VMCX file iwith extension exists in the import path (i don't know the name of the file so i check for the extension) if exists get the path of the file
if (Get-ChildItem -Path "$ExportPath/$SourceVM" -Filter *.vmcx -Recurse -ErrorAction SilentlyContinue) {
    Write-Host "A VMCX is present, continuing..."
    $vmcxPath = Get-ChildItem -Path "$ExportPath/$SourceVM" -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
} else {
    # Get the path of the VMCX file in the exported VM folder
    $vmcxPath = Get-ChildItem -Path "$ExportPath/$SourceVM" -Filter *.vmcx -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
    if (-Not $vmcxPath) {
        Write-Host "No VMCX file found in the export directory. Cannot proceed with import."
        Write-Host "Please delete the export directory and try again."
        exit
    }
}

# Create import directory if it doesn't exist
if (-Not (Test-Path -Path $ImportPath)) {
    try {
        New-Item -ItemType Directory -Path $ImportPath
        Write-Host "Created import directory at $ImportPath"
    }
    catch {
        Write-Host "An error occurred while creating the import directory: $_"
        exit
    }
    
} else {
    Write-Host "Import directory already exists at $ImportPath"
}

# Create subdirectories for the import process
$subDirs = @("Virtual Machines", "Snapshots", "Virtual Hard Disks")
foreach ($dir in $subDirs) {
    $fullPath = Join-Path -Path $ImportPath -ChildPath $dir
    if (-Not (Test-Path -Path $fullPath)) {
        try {
            New-Item -ItemType Directory -Path $fullPath
            Write-Host "Created subdirectory: $fullPath"
        }
        catch {
            Write-Host "An error occurred while creating subdirectory $($dir): $_"
            exit
        }
    } else {
        Write-Host "Subdirectory already exists: $fullPath"
    }
}

try {
    # Import as a new VM with a unique ID
    Write-Host "Importing VM from $vmcxPath to $ImportPath with new name $CloneName"
    Import-VM -Path $vmcxPath -Copy -GenerateNewId -VirtualMachinePath "$ImportPath" -SnapshotFilePath "$ImportPath/Snapshots" -VhdDestinationPath "$ImportPath/Virtual Hard Disks" | Rename-VM -NewName $CloneName
    Write-Host "Import completed. VM $CloneName has been created."
}
catch {
    Write-Host "An error occurred during import: $_"
    exit
}

# Verify the new VM
if (Get-VM -Name $CloneName -ErrorAction SilentlyContinue) {
    Write-Host "VM $CloneName has been successfully created and is available."
} else {
    Write-Host "Failed to create VM $CloneName."
    Write-Host "Unknown error occurred during the import process."
    exit
}

# Rename the disk files to match the new VM name
$diskFiles = Get-ChildItem -Path "$ImportPath/Virtual Hard Disks"
foreach ($disk in $diskFiles) {
    $newDiskName = $disk.Name -replace [regex]::Escape($SourceVM), $CloneName
    try {
        Rename-Item -Path $disk.FullName -NewName $newDiskName
        Write-Host "Renamed disk file $($disk.Name) to $newDiskName"
    }
    catch {
        Write-Host "An error occurred while renaming disk file $($disk.Name): $_"
    }
}
# Set the vm to use the new disk files
Set-VMHardDiskDrive -VMName $CloneName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path "$ImportPath/Virtual Hard Disks/$($diskFiles[0].Name -replace [regex]::Escape($SourceVM), $CloneName)" 
