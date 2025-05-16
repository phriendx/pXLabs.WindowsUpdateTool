function Update-JobTracker {
    $timerJobTracker.Stop()
    
    for ($index = 0; $index -lt $JobTrackerList.Count; $index++) {
        $psObject = $JobTrackerList[$index]
        
        if ($null -ne $psObject) {
            if ($psObject.Job.State -eq 'Blocked') {
                Receive-Job $psObject.Job | Out-Null
            } elseif ($psObject.Job.State -ne 'Running') {
                if ($null -ne $psObject.CompleteScript) {
                    If ($psObject.JobData) {
                        Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job, $psObject.JobData
                    } Else {
                        Invoke-Command -ScriptBlock $psObject.CompleteScript -ArgumentList $psObject.Job
                    }
                }
                $JobTrackerList.RemoveAt($index)
                Remove-Job -Job $psObject.Job
                $index--
            } elseif ($null -ne $psObject.UpdateScript) {
                Invoke-Command -ScriptBlock $psObject.UpdateScript -ArgumentList $psObject.Job
            }
        } else {
            $JobTrackerList.RemoveAt($index)
            $index--
        }
    }
    
    if ($JobTrackerList.Count -gt 0) {
        $timerJobTracker.Start()
    }
}