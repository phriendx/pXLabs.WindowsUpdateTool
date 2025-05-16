function Clear-WpfDataGrid {
<#
.SYNOPSIS
    Clears the contents of a WPF DataGrid.
.DESCRIPTION
    Safely resets the ItemsSource of a WPF DataGrid, removing all displayed rows.
.PARAMETER DataGrid
    The WPF DataGrid control to clear.
#>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [System.Windows.Controls.DataGrid]$DataGrid
    )
    
    # Option 1: Unbind data
    $DataGrid.ItemsSource = $null
    
    # Option 2: If bound to a collection we control, clear it directly (optional)
    # if ($DataGrid.ItemsSource -is [System.Collections.IList]) {
    #     $DataGrid.ItemsSource.Clear()
    # }
}