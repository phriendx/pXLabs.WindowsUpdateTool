function Update-JobTracker {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess("Timer job tracker", "Stop timer")) {
        $timerJobTracker.Stop()
    }

    for ($index = 0; $index -lt $JobTrackerList.Count; $index++) {
        $psObject = $JobTrackerList[$index]

        if ($null -ne $psObject) {
            if ($psObject.Job.State -eq 'Blocked') {
                # Receiving job output does not modify state, no ShouldProcess needed
                Receive-Job $psObject.Job | Out-Null
            }
            elseif ($psObject.Job.State -ne 'Running') {
                if ($null -ne $psObject.CompleteScript) {
                    if ($psObject.JobData) {
                        Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job, $psObject.JobData
                    }
                    else {
                        Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job
                    }
                }

                if ($PSCmdlet.ShouldProcess("Job ID $($psObject.Job.Id)", "Remove job and remove from tracker")) {
                    $JobTrackerList.RemoveAt($index)
                    Remove-Job -Job $psObject.Job
                    $index--
                }
            }
            elseif ($null -ne $psObject.UpdateScript) {
                Invoke-Command -ScriptBlock $psObject.UpdateScript -ArgumentList $psObject.Job
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess("Job tracker list", "Remove null tracker at index $index")) {
                $JobTrackerList.RemoveAt($index)
                $index--
            }
        }
    }

    if ($JobTrackerList.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess("Timer job tracker", "Start timer")) {
            $timerJobTracker.Start()
        }
    }
}