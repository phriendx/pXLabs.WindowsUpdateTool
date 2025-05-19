function Restart-CMAgent {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    if ($PSCmdlet.ShouldProcess("SMS Agent Host on $ComputerName", "Restart")) {
        $paramAddJobTracker = @{
            Name = 'RestartCMAgent'
            JobScript = {
                Param (
                    [string]$ComputerName
                )

                Try {
                    Write-OutputBox "Waiting for service 'SMS Agent Host (ccmexec)' to stop..."
                    Get-Service -ComputerName "$ComputerName" -Name "ccmexec" | Restart-Service -Force
                } catch {
                    Write-Output @{
                        Success = $false
                        Error   = $_.Exception.Message
                    }
                }
            }

            ArgumentList = $ComputerName

            CompletedScript = {
                Param ([System.Management.Automation.Job]$Job)

                try {
                    $results = Receive-Job -Job $Job -ErrorAction Stop | Select-Object -Last 1

                    if ($results -is [hashtable] -and $results.ContainsKey("Success") -and -not $results.Success) {
                        Write-OutputBox "  Result: Failed - $($results.Error)"
                    } else {
                        try {
                            if ((Get-Service -ComputerName "$ComputerName" -Name "CcmExec").Status -eq "Running") {
                                Write-OutputBox "  Result: Successful"
                            } else {
                                Write-OutputBox "  Result: Failed - Service not running"
                            }
                        } catch {
                            Write-OutputBox "  Result: Failed to query service - $($_.Exception.Message)"
                        }
                    }
                } catch {
                    Write-OutputBox "  Error retrieving job result: $($_.Exception.Message)"
                }

                $buttonRestartSMSAgent.ImageIndex = -1
                $buttonRestartSMSAgent.Enabled = $true

                $statusstrip1.Items.Clear()
                $statusstrip1.Items.Add("CM Agent restart completed")
            }

            UpdateScript = {
                Param ([System.Management.Automation.Job]$Job)

                $results = Receive-Job -Job $Job -Keep | Select-Object -Last 1

                $statusstrip1.Items.Clear()
                $statusstrip1.Items.Add("$results")

                if ($null -ne $buttonRestartSMSAgent.ImageList) {
                    if ($buttonRestartSMSAgent.ImageIndex -lt $buttonRestartSMSAgent.ImageList.Images.Count - 1) {
                        $buttonRestartSMSAgent.ImageIndex += 1
                    } else {
                        $buttonRestartSMSAgent.ImageIndex = 0
                    }
                }
            }
        }

        Add-JobTracker @paramAddJobTracker
    }
}
