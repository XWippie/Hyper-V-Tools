
<# 
    Lansweeper settings - PowerShell version
    - Enables DCOM and sets legacy authentication/impersonation levels
    - Removes default DCOM permissions to allow system defaults
    - Configures firewall for DCOM (TCP 135) and Remote Administration
    - Disables Simple File Sharing (ForceGuest=0)
    - Sets LocalAccountTokenFilterPolicy=1
    - Ensures WMI service is set to Automatic and started
#>
$scannerIP="x.x.x.x"

# Require elevation
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Error "Run this script from an elevated PowerShell session (Run as Administrator)."
    exit 1
}



$ErrorActionPreference = 'SilentlyContinue'

# --- Enable DCOM and legacy levels ---
$oleKey = 'HKLM:\SOFTWARE\Microsoft\Ole'
New-Item -Path $oleKey -Force | Out-Null

# EnableDCOM = "Y" (REG_SZ)
New-ItemProperty -Path $oleKey -Name 'EnableDCOM' -Value 'Y' -PropertyType String -Force | Out-Null

# LegacyAuthenticationLevel = 2 (REG_DWORD)
New-ItemProperty -Path $oleKey -Name 'LegacyAuthenticationLevel' -Value 2 -PropertyType DWord -Force | Out-Null

# LegacyImpersonationLevel = 3 (REG_DWORD)
New-ItemProperty -Path $oleKey -Name 'LegacyImpersonationLevel' -Value 3 -PropertyType DWord -Force | Out-Null

# --- Remove specific DCOM default permission values (if present) ---
foreach ($name in 'DefaultLaunchPermission','MachineAccessRestriction','MachineLaunchRestriction') {
    if (Get-ItemProperty -Path $oleKey -Name $name -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $oleKey -Name $name -ErrorAction SilentlyContinue
    }
}

# --- Firewall settings ---
# Prefer PowerShell NetSecurity module. Fallback to netsh advfirewall if needed.

# Allow DCOM/RPC endpoint mapper (TCP 135)
New-NetFirewallRule -DisplayName 'DCOM_TCP135' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 135 | Out-Null
Set-NetFirewallRule -DisplayName 'DCOM_TCP135' -RemoteAddress $scannerIP | Out-Null

Enable-NetFirewallRule -DisplayGroup 'Windows Management Instrumentation (WMI)' -ErrorAction SilentlyContinue
Set-NetFirewallRule -DisplayGroup 'Windows Management Instrumentation (WMI)' -RemoteAddress $scannerIP | Out-Null

Enable-NetFirewallRule -DisplayGroup 'Remote Service Management' -ErrorAction SilentlyContinue
Set-NetFirewallRule -DisplayGroup 'Remote Service Management' -RemoteAddress $scannerIP | Out-Null

Enable-NetFirewallRule -DisplayGroup 'Remote Administration' -ErrorAction SilentlyContinue
Set-NetFirewallRule -DisplayGroup 'Remote Administration' -RemoteAddress $scannerIP | Out-Null

# --- Disable Simple File Sharing (ForceGuest=0) ---
$lsaKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
New-Item -Path $lsaKey -Force | Out-Null
New-ItemProperty -Path $lsaKey -Name 'ForceGuest' -Value 0 -PropertyType DWord -Force | Out-Null

# --- LocalAccountTokenFilterPolicy = 1 ---
$sysPoliciesKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System'
New-Item -Path $sysPoliciesKey -Force | Out-Null
New-ItemProperty -Path $sysPoliciesKey -Name 'LocalAccountTokenFilterPolicy' -Value 1 -PropertyType DWord -Force | Out-Null

# --- Ensure WMI (winmgmt) starts automatically and start it ---
Set-Service -Name 'winmgmt' -StartupType Automatic
Start-Service -Name 'winmgmt' -ErrorAction SilentlyContinue

#set minmgmt allowed ip's


Write-Host "Configuration completed successfully." -ForegroundColor Green

