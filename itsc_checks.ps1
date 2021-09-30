Param(
  [Parameter(Mandatory=$True,HelpMessage='Enter the computer name or IP')]
  [String]$Computer,

  [Parameter(Mandatory=$True,HelpMessage='Enter your Username')]
  [String]$Username,

  [Parameter(Mandatory=$True,HelpMessage='Enter your Password')]
  [SecureString]$Password,

  [Parameter(HelpMessage='Defines if we run in interactive mode or not')]
  [Bool]$Interactive = $true
)

# Define ISC Servers
[Array] $ISCservers = '172.31.255.17', '172.31.255.6'

# Define ports on remote server that should be open
[Array] $TestPorts = '139', '445'


# Assemble Credential for remote connection
$cred = New-Object System.Management.Automation.PSCredential ($Username, $Password)

# -----------------------------------------------------------

function StartEnable-Service
{ 
  param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [Parameter(HelpMessage='Defines if we run in interactive mode or not')]
    [Bool]$Interactive = $false  
  )

  $error.clear()
  $arrService = Get-Service -Name $ServiceName
  if ($error) {
      Write-Host "Error Occured"
      Return $error
  } 


  if ($Interactive -eq $true -And $arrService.Status -ne 'Running') {
    $AskStartServiceTitle    = 'Start Service'
    $AskStartServiceQuestion = "$ServiceName service is not running. Would you like to start it?"
    $AskStartServiceChoices  = '&Yes', '&No'
    $AskStartServiceDecision = $Host.UI.PromptForChoice($AskStartServiceTitle, $AskStartServiceQuestion, $AskStartServiceChoices, 1)

    if ($AskStartServiceDecision -eq 0) {
      $AnswerStartService = $true
    }

    else {
      $AnswerStartService = $false
    }
  }
  elseif ($Interactive -eq $true -And $arrService.Status -eq 'Running') {
      Write-Host "$ServiceName service is already running"
    }


  if ($Interactive -eq $true -And $arrService.StartType -ne 'Automatic') {
    $AskEnableServiceTitle    = 'Load service on Startup'
    $AskEnableServiceQuestion = "$ServiceName service is not set to run on Startup. Would you like to enable it?"
    $AskEnableServiceChoices  = '&Yes', '&No'
    $AskEnableServiceDecision = $Host.UI.PromptForChoice($AskEnableServiceTitle, $AskEnableServiceQuestion, $AskEnableServiceChoices, 1)

    if ($AskEnableServiceDecision -eq 0) {
      $AnswerEnableService = $true
    }

    else {
      $AnswerEnableService = $false
    }
  }
  elseif ($Interactive -eq $true -And $arrService.StartType -ne 'Automatic') {
    Write-Host "$ServiceName service is already set to automatically start"
  }



  if ($Interactive -eq $false -Or $AnswerStartService -eq $true ) {

    Write-Host "Checking Service: $ServiceName"
    while ($arrService.Status -ne 'Running')
    {
        Start-Service $ServiceName
        Write-Host $arrService.status
        Write-Host 'Service starting'
        Start-Sleep -seconds 60
        $arrService.Refresh()
        if ($arrService.Status -ne 'Running') {
            Write-Host "ERROR: Unable to start $ServiceName Service"
        }
    }

  }

  if ($Interactive -eq $false -Or $AnswerEnableService -eq $true ) {

    if ($arrService.StartType -ne 'Automatic') {
      Set-Service -Name $ServiceName -StartupType Automatic
      Write-Host "$ServiceName has been set to Automatic startup"
    }
    else
    {
      Write-Host "$ServiceName is already set to Automatic startup - no action required"
    }

  }

}

# -----------------------------------------------------------

Write-Host ''
Write-Host "Connection Test - Pre-checks"
Write-Host "-------------------------------------------------------"

# Pre-Checks

$WinRMTest = Test-NetConnection -ComputerName $Computer -Port 5985 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

Write-Host "Testing WinRM connection (port 5985) from local machine to target $Computer"


if ($WinRMTest.TcpTestSucceeded -ne $true) {
    Write-Host "WARNING: WinRM Connection to $Computer is unavailable"
    Break
}
else {
    Write-Host "SUCCESS: WinRM Connection to $Computer on port 5985 available"
}
Write-Host ''

# Test connections to target machine
Write-Host "Testing ports on $Computer from local machine"
foreach($Port in $TestPorts) {
    Test-NetConnection -ComputerName $Computer -Port $Port -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | select -Property RemotePort, TcpTestSucceeded
}

Write-Host ''

# -----------------------------------------------------------

# Remote Checks

Write-Host "Testing connections from $Computer to ISC Servers"

# Reinitalise all variables
$CheckISCServer = $null
$CheckISCSuccess = $false
$CheckISCTarget = $null

foreach($Server in $ISCservers) {

  $CheckISCServer = Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
    $CheckISCServer = Test-NetConnection -ComputerName $Using:Server -Port 3121 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue  | select -Property RemoteAddress, RemotePort, TcpTestSucceeded
    Return $CheckISCServer
  }

  if ($CheckISCServer.TcpTestSucceeded -eq $true) {
    $CheckISCSuccess = $true
    $CheckISCTarget = $CheckISCServer.RemoteAddress
  }

}

if ($CheckISCSuccess -eq $false) {
  Write-Host "WARNING: No connection available to any UKCloud ISC Server"
  Break
}
else {
  Write-Host "SUCCESS: Connection to UKCloud ISC server available: $CheckISCTarget"
}
Write-Host ''

$FWRfpsStatus = Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
    $FWRfpsiStatus = Get-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" | select -Property Enabled
    Return $FWRfpsiStatus
}

# -----------------------------------------------------------

# Interactive

if ($Interactive -eq $true) {
    Write-Host "Running in interactive mode"

    Write-Host ''
    Write-Host 'Checking Firewall'
    Write-Host "-------------------------------------------------------"
  
    if ($FWRfpsStatus.Enabled -ne $true) {
        $FWRfpsTitle    = 'Firewall Rule'
        $FWRfpsQuestion = "Firewall rule on $Computer is not enabled. Would you like to enable it?"
        $FWRfpsChoices  = '&Yes', '&No'

        $FWRfpsDecision = $Host.UI.PromptForChoice($FWRfpsTitle, $FWRfpsQuestion, $FWRfpsChoices, 1)
        if ($FWRfpsDecision -eq 0) {

            Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
                Enable-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)"
            }
            Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer has been enabled."

        } else {
            Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer not enabled."
        }
     } else {
        Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer already enabled. No action required"
     }

}

# Non-Interactive

if ($Interactive -eq $false) {
  Write-Host "Running in non-interactive mode"

  Write-Host ''
  Write-Host 'Checking Firewall'
  Write-Host "-------------------------------------------------------"


  if ($FWRfpsStatus.Enabled -ne $true) {
      Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
          Enable-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)"
      }
      Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer not enabled."
  } else {
      Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer already enabled. No action required"
  }
}

# -----------------------------------------------------------

Write-Host ''
Write-Host 'Checking Services'
Write-Host "-------------------------------------------------------"

Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock ${Function:StartEnable-Service} -ArgumentList 'LanmanServer', $Interactive
Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock ${Function:StartEnable-Service} -ArgumentList 'RemoteRegistry', $Interactive

# -----------------------------------------------------------

Write-Host ''

# Test connections to target machine
Write-Host ''
Write-Host "Connection Test - Post-Checks"
Write-Host "-------------------------------------------------------"
Write-Host ''
Write-Host "RemotePort TcpTestSucceeded"
Write-Host "---------- ---------------- "

foreach($Port in $TestPorts)
{
    Test-NetConnection -ComputerName $Computer -Port $Port -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | select -Property RemotePort, TcpTestSucceeded
}
