function Write-OutputBox {
    [cmdletbinding()]
    param (
        [string]$Text,
        [switch]$ReplaceLastLine,
        [string]$LogFile = $LogFile
    )
    
    $doc = $controls["Output"].Document
    $paragraphs = $doc.Blocks | Where-Object { $_ -is [System.Windows.Documents.Paragraph] }
    
    if ($ReplaceLastLine -and $paragraphs.Count -gt 0) {
        # Remove the last paragraph
        $lastParagraph = $paragraphs[-1]
        $doc.Blocks.Remove($lastParagraph)
    }
    
    # Create new paragraph
    $newParagraph = New-Object System.Windows.Documents.Paragraph
    $newParagraph.LineHeight = 10
    $newParagraph.LineStackingStrategy = "BlockLineHeight"
    $newParagraph.Inlines.Add($Text)
    $doc.Blocks.Add($newParagraph)
    
    # Auto-scroll to bottom
    $controls["Output"].ScrollToEnd()
    
    If ($LogFile -ne "") {
        switch -Regex ($logLines) {
            '^ERROR' { $Level = "Error" }
            '^WARN' { $Level = "Warn" }
            default { $level = "Info" }
        }
        
        Write-Log -Level $level -Message $Text -NoConsoleOut -Path $LogFile
    }
}