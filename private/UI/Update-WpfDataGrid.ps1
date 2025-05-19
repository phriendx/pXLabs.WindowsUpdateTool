function Update-WpfDataGrid {
    <#
    .SYNOPSIS
        Loads items into a WPF DataGrid.

    .DESCRIPTION
        Supports loading data collections (including DataTables) into a WPF DataGrid.

    .PARAMETER DataGrid
        The WPF DataGrid control.

    .PARAMETER Item
        The object or objects to load.

    .PARAMETER AutoSizeColumns
        Auto-sizes columns if set to $true.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [System.Windows.Controls.DataGrid]$DataGrid,

        [Parameter(Mandatory)]
        $Item,

        [bool]$AutoSizeColumns = $true
    )

    if ($PSCmdlet.ShouldProcess("DataGrid", "Update ItemsSource and resize columns")) {
        # Clear existing data
        $DataGrid.ItemsSource = $null

        if ($null -eq $Item) {
            return
        }

        # If it's a DataTable, bind to DefaultView
        if ($Item -is [System.Data.DataTable]) {
            $DataGrid.ItemsSource = $Item.DefaultView
        }
        # If it's a DataSet, bind to first table's DefaultView
        elseif ($Item -is [System.Data.DataSet] -and $Item.Tables.Count -gt 0) {
            $DataGrid.ItemsSource = $Item.Tables[0].DefaultView
        }
        # Otherwise, bind directly to collection
        else {
            $DataGrid.ItemsSource = @($Item)
        }

        if ($AutoSizeColumns) {
            $DataGrid.Columns | ForEach-Object {
                $_.Width = 'Auto'
            }
        }
    }
}
