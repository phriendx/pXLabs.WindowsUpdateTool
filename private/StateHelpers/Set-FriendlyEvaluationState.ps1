function Set-FriendlyEvaluationState {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [int]$State
    )
    
    switch ($State) {
        0	{ $label = "None" }
        1	{ $label = "Available" }
        2	{ $label = "Submitted" }
        3	{ $label = "Detecting" }
        4	{ $label = "PreDownload" }
        5	{ $label = "Downloading" }
        6	{ $label = "WaitInstall" }
        7	{ $label = "Installing" }
        8	{ $label = "PendingSoftReboot" }
        9	{ $label = "PendingHardReboot" }
        10	{ $label = "WaitReboot" }
        11	{ $label = "Verifying" }
        12	{ $label = "InstallComplete" }
        13	{ $label = "Error" }
        14	{ $label = "WaitServiceWindow" }
        15	{ $label = "WaitUserLogon" }
        16	{ $label = "WaitUserLogoff" }
        17	{ $label = "WaitJobUserLogon" }
        18	{ $label = "WaitUserReconnect" }
        19	{ $label = "PendingUserLogoff" }
        20	{ $label = "PendingUpdate" }
        21	{ $label = "WaitingRetry" }
        22	{ $label = "WaitPresModeOff" }
        23	{ $label = "WaitForOrchestration" }
    }
    
    $Label
}