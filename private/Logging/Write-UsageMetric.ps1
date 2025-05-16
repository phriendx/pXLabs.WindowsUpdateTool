function Write-UsageMetric {
    [cmdletbinding()]
    param (
        [string]$Action,
        [string]$Result = "Success",
        [string]$Details = ""
    )
    
    $logPath = "$env:ProgramData\pXLabs-MSUpdateTool\usage.log"
    $logEntry = @{
        Timestamp = (Get-Date).ToString("s")
        User	  = $env:USERNAME
        Host	  = $env:COMPUTERNAME
        Action    = $Action
        Result    = $Result
        Details   = $Details
    }
    
    Add-Content -Path $logPath -Value (ConvertTo-Json $logEntry -Compress)
}