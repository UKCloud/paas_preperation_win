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

# Pre-Checks

$WinRMTest = Test-NetConnection -ComputerName $Computer -Port 5985

if ($WinRMTest.TcpTestSucceeded -ne $true) {
    Write-Host "Unable to establish WinRM connection to $Computer on port 5985"
    Break
} else {
    Write-Host "WinRM Connection test to $Computer on port 5985 successful"
}

# Test connections to target machine
Write-Host "Testing connections from local machine to $Computer before we change anything"
foreach($Port in $TestPorts)
{
    Test-NetConnection -ComputerName $Computer -Port $Port | select -Property RemotePort, TcpTestSucceeded
}


# -----------------------------------------------------------

# Remote Checks

Write-Host "Testing connections from $Computer to ISC Servers"
foreach($Server in $ISCservers)
{
    Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
        Test-NetConnection -ComputerName $Using:Server -Port 3121 | select -Property RemoteAddress, RemotePort, TcpTestSucceeded
    }
}

$FWRfpsStatus = Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
    $FWRfpsiStatus = Get-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" | select -Property Enabled
    Return $FWRfpsiStatus
}

$LanmanServerStatus = Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {

        $LanmanServeriStatus = Get-Service -Name LanmanServer
        if ($LanmanServeriStatus.Status -eq 'Running')
        {
            Return $true
        } else {
            Return $false
        }
}

$RemoteRegistryStatus = Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {

        $RemoteRegistryiStatus = Get-Service -Name RemoteRegistry
        if ($RemoteRegistryiStatus.Status -eq 'Running')
        {
            Return $true
        } else {
            Return $false
        }

}

# -----------------------------------------------------------

# Interactive

if ($Interactive -eq $true) {
    Write-Host "Running in interactive mode"

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


    if ($LanmanServerStatus -ne $true) {
        $LanmanServerTitle    = 'LanmanServer Service'
        $LanmanServerQuestion = "LanmanServer Service on $Computer is not running. Would you like to start it?"
        $LanmanServerChoices  = '&Yes', '&No'

        $LanmanServerDecision = $Host.UI.PromptForChoice($LanmanServerTitle, $LanmanServerQuestion, $LanmanServerChoices, 1)
        if ($LanmanServerDecision -eq 0) {

            Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {

                $arrService = Get-Service -Name LanmanServer
                Write-Host "Checking Service: LanmanServer"
                while ($arrService.Status -ne 'Running')
                {
                    Start-Service LanmanServer
                    Write-Host $arrService.status
                    Write-Host 'Service starting'
                    Start-Sleep -seconds 60
                    $arrService.Refresh()
                    if ($arrService.Status -ne 'Running') {
                        Write-Host "ERROR: Unable to start LanmanServer Service"
                    }
                }
            }
            Write-Host "LanmanServer Service on $Computer has been started."

        } else {
            Write-Host "LanmanServer Service on $Computer has not been started."
        }
     } else {
        Write-Host "LanmanServer Service on $Computer already running. No action required"
     }


 
    if ($RemoteRegistryStatus -ne $true) {
        $RemoteRegistryTitle    = 'RemoteRegistry Service'
        $RemoteRegistryQuestion = "RemoteRegistry Service on $Computer is not running. Would you like to start it?"
        $RemoteRegistryChoices  = '&Yes', '&No'

        $RemoteRegistryDecision = $Host.UI.PromptForChoice($RemoteRegistryTitle, $RemoteRegistryQuestion, $RemoteRegistryChoices, 1)
        if ($RemoteRegistryDecision -eq 0) {

            Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {

                $arrService = Get-Service -Name RemoteRegistry
                Write-Host "Checking Service: RemoteRegistry"
                while ($arrService.Status -ne 'Running')
                {
                    Start-Service RemoteRegistry
                    Write-Host $arrService.status
                    Write-Host 'Service starting'
                    Start-Sleep -seconds 60
                    $arrService.Refresh()
                    if ($arrService.Status -ne 'Running') {
                        Write-Host "ERROR: Unable to start RemoteRegistry Service"
                    }
                }
            }
            Write-Host "RemoteRegistry Service on $Computer has been started."

        } else {
            Write-Host "RemoteRegistry Service on $Computer has not been started."
        }
     } else {
        Write-Host "RemoteRegistry Service on $Computer already running. No action required"
     }

}
 # -----------------------------------------------------------

 # Non-Interactive

 if ($Interactive -eq $false) {
    Write-Host "Running in non-interactive mode"

    if ($FWRfpsStatus.Enabled -ne $true) {
        Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
            Enable-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)"
        }
        Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer not enabled."
    } else {
        Write-Host "Firewall rule for File and Printer Sharing (SMB-In) on $Computer already enabled. No action required"
    }

    if ($LanmanServerStatus -ne $true) {
        Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
            $arrService = Get-Service -Name LanmanServer
            while ($arrService.Status -ne 'Running')
            {
                Start-Service LanmanServer
                Write-Host $arrService.status
                Write-Host 'Service starting'
                Start-Sleep -seconds 60
                $arrService.Refresh()
                if ($arrService.Status -ne 'Running') {
                    Write-Host "ERROR: Unable to start LanmanServer Service"
                }
            }
        Write-Host "LanmanServer Service on $Computer has been started."
        }
    } else {
        Write-Host "LanmanServer Service on $Computer already running. No action required"
    }

    if ($RemoteRegistryStatus -ne $true) {
        Invoke-Command -ComputerName $Computer -Credential $cred -ScriptBlock {
            $arrService = Get-Service -Name RemoteRegistry
            Write-Host "Checking Service: RemoteRegistry"
            while ($arrService.Status -ne 'Running')
            {
                Start-Service RemoteRegistry
                Write-Host $arrService.status
                Write-Host 'Service starting'
                Start-Sleep -seconds 60
                $arrService.Refresh()
                if ($arrService.Status -ne 'Running') {
                    Write-Host "ERROR: Unable to start RemoteRegistry Service"
                }
            }
        Write-Host "RemoteRegistry Service on $Computer has been started."
        }
    } else {
        Write-Host "RemoteRegistry Service on $Computer already running. No action required"
    }

}

# -----------------------------------------------------------

# Test connections to target machine
Write-Host "Testing connections from local machine to $Computer now that all steps have been completed"
foreach($Port in $TestPorts)
{
    Test-NetConnection -ComputerName $Computer -Port $Port | select -Property RemotePort, TcpTestSucceeded
}
 
