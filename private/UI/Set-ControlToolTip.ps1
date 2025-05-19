function Set-ControlToolTip {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$ControlName,
        [string]$Message
    )

    if ($controls.ContainsKey($ControlName) -and $controls[$ControlName] -ne $null) {
        if ($PSCmdlet.ShouldProcess("Control '$ControlName'", "Set tooltip message")) {
            $control = $controls[$ControlName]

            $tooltip = New-Object System.Windows.Controls.ToolTip
            $tooltip.Content = $Message

            [System.Windows.Controls.ToolTipService]::SetToolTip($control, $tooltip)
            [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($control, $true)
        }
    }
    else {
        Write-Warning "Control '$ControlName' not found in controls hashtable."
    }
}
