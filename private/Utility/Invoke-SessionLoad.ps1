function Invoke-SessionLoad {
    [cmdletbinding()]
    param (
        [scriptblock]$SessionLoad
    )

    Clear-WpfDataGrid -DataGrid $controls["UpdateList"]
    $controls["Output"].Document.Blocks.Clear()
    Write-OutputBox $SectionBreak
    Invoke-Command -ScriptBlock $SessionLoad
}