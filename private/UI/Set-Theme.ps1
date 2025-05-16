function Set-Theme {
	[CmdletBinding()]
	param (
		[string]$themePath,
		[Parameter(Mandatory)]
		[System.Windows.Window]$Window
	)
	
	$reader = [System.Xml.XmlReader]::Create($themePath)
	$theme = [Windows.Markup.XamlReader]::Load($reader)
	
	# Apply resources directly to the Window
	$Window.Resources.MergedDictionaries.Clear()
	$Window.Resources.MergedDictionaries.Add($theme)
	
	# Set window background/foreground if defined
	if ($Window.Resources["WindowBackground"]) {
		$Window.Background = $Window.Resources["WindowBackground"]
	}
	if ($Window.Resources["ControlForeground"]) {
		$Window.Foreground = $Window.Resources["ControlForeground"]
	}
}

