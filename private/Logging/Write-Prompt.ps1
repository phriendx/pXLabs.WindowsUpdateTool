Function Write-Prompt {
    [cmdletbinding()]
    Param (
        [parameter()]
        [string]$PromptText,
        [parameter()]
        [int]$PromptWaitTime = 0,
        #Do not close message automatically
        [parameter()]
        [string]$PromptTitle = "Message from PowerShell Script",
        [parameter()]
        [int]$PromptType = 64 #Show "Information" icon
    )
    
    $promptShell = New-Object -ComObject WScript.Shell
    $promptShell.popup($promptText, $promptWaitTime, $promptTitle, $promptType)
}