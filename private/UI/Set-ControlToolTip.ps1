function Set-ControlToolTip {
    [cmdletbinding()]
    param (
        [string]$ControlName,
        [string]$Message
    )
    
    if ($controls.ContainsKey($ControlName) -and $controls[$ControlName] -ne $null) {
        $control = $controls[$ControlName]
        
        $tooltip = New-Object System.Windows.Controls.ToolTip
        $tooltip.Content = $Message
        
        [System.Windows.Controls.ToolTipService]::SetToolTip($control, $tooltip)
        [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($control, $true)
    } else {
        Write-Warning "Control '$ControlName' not found in controls hashtable."
    }
}