function Update-ButtonState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [ValidateSet("Enabled", "Disabled")]
        [string]$State,
        [ValidateSet("Remote", "CMUpdate")]
        [string]$ButtonPurpose
    )
    
    # Define which buttons are affected by purpose
    switch ($ButtonPurpose) {
        "Remote" {
            $Buttons = @("Ping", "PSSessionHere")
        }
        "CMUpdate" {
            $Buttons = @("UpdateScan", "UpdateEvaluation", "RestartCMAgent", "RefreshCMPolicy")
        }
    }

    foreach ($btnName in $Buttons) {
        if ($controls.ContainsKey($btnName)) {
            $button = $controls[$btnName]

            if ($button -is [System.Windows.Controls.Control]) {
                if ($PSCmdlet.ShouldProcess("Button '$btnName'", "Set state to $State")) {
                    $button.IsEnabled = ($State -eq "Enabled")
                    $button.Opacity = if ($State -eq "Enabled") { 1.0 } else { 0.5 }
                    [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($button, $true)
                }
            } else {
                Write-Warning "Control '$btnName' is not a WPF Control"
            }
        } else {
            Write-Warning "Control '$btnName' not found in controls dictionary"
        }
    }
}
