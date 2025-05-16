function Set-Computername {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ComputerName,
        [string]$Domain = $Domain
    )
    
    If (($ComputerName -ne $env:computername) -and ("" -ne $Domain)) {
        $Computername = "$($Computername).$Domain"
    }
    
    $Computername.ToUpper()
}