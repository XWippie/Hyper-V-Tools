<#
.SYNOPSIS
    Indpendent hardening of windows systems based on cis benchmarks. 

.DESCRIPTION
    This script applies various security hardening measures to Windows systems based on CIS benchmarks.
    It is designed to be run independently and can be customized to fit specific security requirements.
    The script checks the operating system version and applies relevant hardening measures accordingly.
    Custom settings can be defined in the 'CustomSettings' section.
.NOTES
    Not tested yet.
#>

# Requirements
#Requires -Version 5.1
#Requires -RunAsAdministrator

$errorActionPreference = "Stop"
Clear-Host

$banner = @"
==========================================
         Windows Hardening Tool
==========================================

Version : 0.0.0
Author  : XWippie
GitHub  : https://github.com/XWippie/HyperV-Tools
Date    : 22/12/2025

==========================================
"@

Write-Host $banner -ForegroundColor Cyan
Start-Sleep -Seconds 1

try {
    Write-Host "Setting Execution Policy to Bypass for this session..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "Execution Policy set to Bypass." -ForegroundColor Green
}
catch {
    Write-Host "Failed to set Execution Policy. Please run this script with appropriate permissions." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    exit 1
}

#
# Helper Functions
#region
$LGPO = ".\Tools\LGPO.exe"

function Invoke-LGPOText {
    param(
        [string]$LGPOTextPath
    )

    Write-Host "Applying LGPO text: $LGPOTextPath" -ForegroundColor Yellow
    & $LGPO /t $LGPOTextPath /v
}

function Invoke-LGPOBackup {
    param(
        [string]$BackupPath
    )

    Write-Host "Applying GPO backup from: $BackupPath" -ForegroundColor Yellow
    & $LGPO /g $BackupPath /v
}

function Invoke-LGPOPolicyRules {
    param(
        [string]$PolicyRulesPath
    )

    Write-Host "Applying PolicyRules: $PolicyRulesPath" -ForegroundColor Yellow
    & $LGPO /p $PolicyRulesPath /v
}
#endregion


#
#region Account Policies
#region Password Policies
#region 1.1.1 Ensure 'Enforce password history' is set to '24 or more passwords remembered'

$TempInf = @"
[Unicode]
Unicode=yes

[Version]
Revision=1

[System Access]
PasswordHistorySize = 24
"@

$TempInfPath = ".\Temp\PasswordHistorySize.inf"
$TempInf | Out-File -FilePath $TempInfPath -Encoding ASCII

& $LGPO /s $TempInfPath /v

#endregion
#endregion
#endregion
