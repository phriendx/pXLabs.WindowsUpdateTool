function Set-Computername {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [string]$Domain = $Domain
    )

    if ($ComputerName -ne $env:COMPUTERNAME -and -not [string]::IsNullOrWhiteSpace($Domain)) {
        $fqdn = "$ComputerName.$Domain".ToUpper()
    } else {
        $fqdn = $ComputerName.ToUpper()
    }

    if ($PSCmdlet.ShouldProcess($fqdn, "Return formatted computer name")) {
        return $fqdn
    }
}
