# Load private functions (non-exported)
# Load all private function files
$privateScripts = Get-ChildItem -Path "$PSScriptRoot\private" -Recurse -Filter *.ps1

foreach ($script in $privateScripts) {
    try {
        . $script.FullName
    } catch {
        Write-Warning "Failed to load private function file: $($script.FullName). Error: $_"
    }
}


# Load and export public functions
$publicScripts = Get-ChildItem -Path "$PSScriptRoot\public" -Filter *.ps1

foreach ($script in $publicScripts) {
    try {
        . $script.FullName
        Export-ModuleMember -Function $script.BaseName
    } catch {
        Write-Warning "Failed to load public function file: $($script.FullName). Error: $_"
    }
}

