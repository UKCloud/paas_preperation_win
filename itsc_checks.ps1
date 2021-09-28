Param(
  [Parameter(Mandatory=$True,HelpMessage='Enter the computer name or IP')]
  [String]$Computer,
  [Parameter(Mandatory=$True,HelpMessage='Enter your Username')]
  [String]$Username,
  [Parameter(Mandatory=$True,HelpMessage='Enter your Password')]
  [SecureString]$Password
  )

# Assemble Credential for remote connection
$cred = New-Object System.Management.Automation.PSCredential ($Username, $Password)

# Create Remote Code block for execution on remote host
$rc = {

  # start the following Windows services in the specified order:
  [Array] $Services = 'LanmanServer','RemoteRegistry';

  # loop through each service, if its not running, start it
  foreach($ServiceName in $Services)
  {
      $arrService = Get-Service -Name $ServiceName
      Write-Host "Checking Service: $ServiceName"
      while ($arrService.Status -ne 'Running')
      {
          Start-Service $ServiceName
          Write-Host $arrService.status
          Write-Host 'Service starting'
          Start-Sleep -seconds 60
          $arrService.Refresh()
          if ($arrService.Status -eq 'Running')
          {
            Write-Host "$ServiceName is now Running"
          }
      }
  }
  # Turn on File and Printer Sharing
  Enable-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)"

  # Test connection from target machine to bubbles
  Write-Host 'Testing connections from remote machine to ISC Servers'
  [Array] $ISCservers = '172.31.255.17', '172.31.255.6'
  foreach($Server in $ISCservers)
  {
    Test-NetConnection -ComputerName $Server -Port 3121 | select -Property RemoteAddress, RemotePort, TcpTestSucceeded
  }
}

# --------------------

# Connect to the target machine and execute the remote code block
Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock $rc

# Test connections to target machine
Write-Host 'Testing connections from local machine to remote machine'
[Array] $TestPorts = '139', '445', '3121'
foreach($Port in $TestPorts)
{
    Test-NetConnection -ComputerName $Computer -Port $Port | select -Property RemotePort, TcpTestSucceeded
}
 
