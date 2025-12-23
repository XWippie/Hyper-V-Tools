' Lansweeper settings script

' Enable dcom
Set Myshell = WScript.CreateObject("WScript.Shell")

On Error Resume Next
Err.Clear

Myshell.RegWrite "HKLM\SOFTWARE\Microsoft\Ole\EnableDCOM","Y","REG_SZ"

if  Err.Number <> 0  then
  msgbox  "Error: " & Err.Number & vbCrLf & Err.Description & vbCrLf & vbCrLf & "--> Make sure you are running this script elevated with administrative credentials!!",16,"Script error"
end if

Myshell.RegWrite "HKLM\SOFTWARE\Microsoft\Ole\LegacyAuthenticationLevel",2,"REG_DWORD"
Myshell.RegWrite "HKLM\SOFTWARE\Microsoft\Ole\LegacyImpersonationLevel",3,"REG_DWORD"

' Set dcom default permissions
Myshell.regdelete "HKLM\SOFTWARE\Microsoft\Ole\DefaultLaunchPermission"
Myshell.regdelete "HKLM\SOFTWARE\Microsoft\Ole\MachineAccessRestriction"
Myshell.regdelete "HKLM\SOFTWARE\Microsoft\Ole\MachineLaunchRestriction"

' Set windows firewall
Myshell.run "netsh firewall set service RemoteAdmin enable"
Myshell.run "netsh firewall add portopening protocol=tcp port=135 name=DCOM_TCP135"

' Disable simple file sharing
Myshell.RegWrite "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ForceGuest","0","REG_DWORD"

' Set LocalAccountTokenFilterPolicy
Myshell.RegWrite "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\LocalAccountTokenFilterPolicy","1","REG_DWORD"

' Enable WMI Service and start it
Myshell.run "sc config winmgmt start= auto"
Myshell.run "net start winmgmt"