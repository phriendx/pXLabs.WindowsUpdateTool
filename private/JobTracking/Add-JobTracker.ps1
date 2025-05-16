function Add-JobTracker {
    [CmdletBinding()]
    Param (
        [ValidateNotNull()]
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [ValidateNotNull()]
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$JobScript,
        $ArgumentList = $null,
        [hashtable]$JobData,
        [ScriptBlock]$CompletedScript,
        [ScriptBlock]$UpdateScript
    )
    
    # Start the job
    $job = Start-Job -Name $Name -ScriptBlock $JobScript -ArgumentList $ArgumentList
    
    if ($null -ne $job) {
        # Track the job
        $psObject = [PSCustomObject]@{
            Job		       = $job
            CompleteScript = $CompletedScript
            UpdateScript   = $UpdateScript
        }
        
        If ($JobData) {
            $psObject | Add-Member -MemberType NoteProperty -Name "JobData" -Value $jobData
        }
        
        $psObject | Add-Member -MemberType NoteProperty -Name "Error" -Value $null
        
        [void]$JobTrackerList.Add($psObject)
        
        # Prevent UI/resource overload by limiting tracker list size
        $MaxTrackers = 100
        while ($JobTrackerList.Count -gt $MaxTrackers) {
            $JobTrackerList.RemoveAt(0) # Remove the oldest tracker
        }
        
        # Start the timer if it's not already running
        if (-not $timerJobTracker.Enabled) {
            $timerJobTracker.Start()
        }
    } elseif ($null -ne $CompletedScript) {
        Invoke-Command -ScriptBlock $CompletedScript -ArgumentList $null
    }
}