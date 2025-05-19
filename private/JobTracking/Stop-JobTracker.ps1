function Stop-JobTracker {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ($PSCmdlet.ShouldProcess("Timer job tracker", "Stop")) {
        $timerJobTracker.Stop()
    }

    while ($JobTrackerList.Count -gt 0) {
        $job = $JobTrackerList[0].Job
        $JobTrackerList.RemoveAt(0)

        if ($PSCmdlet.ShouldProcess("Job ID $($job.Id)", "Stop and remove")) {
            Stop-Job $job
            Remove-Job $job
        }
    }
}
