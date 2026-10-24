param([Parameter(Mandatory=$true)][string]$DocumentPath,[Parameter(Mandatory=$true)][string]$PdfPath)
$ErrorActionPreference='Stop'
$taskWriter=$null
$taskDocument=$null
$taskOwned=$false
try {
    $taskWriter=New-Object -ComObject 'kwps.Application'
    if ($taskWriter.Documents.Count -ne 0) { throw 'A WPS document session is already active; refusing to change it.' }
    $taskOwned=$true
    $taskWriter.Visible=$false
    $taskWriter.DisplayAlerts=0
    $taskDocument=$taskWriter.Documents.Open([IO.Path]::GetFullPath($DocumentPath),$false,$true)
    $taskDocument.ExportAsFixedFormat([IO.Path]::GetFullPath($PdfPath),17)
    if (!(Test-Path -LiteralPath $PdfPath)) { throw 'WPS did not export the PDF.' }
    Write-Output 'PDF_EXPORT: PASS'
} finally {
    if ($null -ne $taskDocument) { $taskDocument.Close(0); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($taskDocument) }
    if ($taskOwned -and $null -ne $taskWriter) { $taskWriter.Quit(0) }
    if ($null -ne $taskWriter) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($taskWriter) }
}
