function Stop-JobTracker {
    $timerJobTracker.Stop()
    while ($JobTrackerList.Count -gt 0) {
        $job = $JobTrackerList[0].Job
        $JobTrackerList.RemoveAt(0)
        Stop-Job $job
        Remove-Job $job
    }
}