# Imports
Import-Module -Name ".\compress.psm1" -Verbose -ErrorAction Stop -Force

# .NET Framework classes
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

### Constants ###
$AllowedExtensions = @('.mp4', '.mkv')

$scriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$scriptPath     = Split-Path $script:MyInvocation.MyCommand.Path
$logPath        = "$($scriptPath)\logs\$($scriptName)"
$logFile        = "$($logPath)\$($scriptName)_$([DateTime]::Now.ToString('yyyyMMdd_HHmmss')).log"
$logFileError   = "$($logPath)\$($scriptName)_$([DateTime]::Now.ToString('yyyyMMdd_HHmmss'))_error.log"
if (-not(Test-Path $logPath -pathType Container)) { New-Item -ItemType Directory -Path $logPath | Out-Null }

# XAML 
$xamlFile = ".\$($scriptName).xaml"
[xml]$XAML = Get-Content $xamlFile
$XAML.Window.RemoveAttribute('x:Class')
$XAML.Window.RemoveAttribute('mc:Ignorable')
$XAMLReader = New-Object System.Xml.XmlNodeReader $XAML
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)

# UI Elements
try {
    $btnClearSelected = $MainWindow.FindName("btnClearSelected")
    $btnCompressAll = $MainWindow.FindName("btnCompressAll")
    $chkClearAfterwards = $MainWindow.FindName("chkClearAfterwards")
    $labelListBoxDesc = $MainWindow.FindName("labelListBoxDesc")
    $labelStatus = $MainWindow.FindName("labelStatus")
    $listBox = $MainWindow.FindName("listBox")
}
catch [Exception] {
    "An error occurred while loading for variables:"
    Write-Host $_.Exception.Message
}

### Write event handlers ###
$button_Click = {
    # Disable all buttons from being clicked during the job.
    $btnCompressAll.IsEnabled = $False
    foreach ($item in $listBox.Items) {
        $labelStatus.Content = ("Compressing ${item}...")
        Write-Host "Starting compression job for ${item}" -ForegroundColor Yellow
        Compress-VideoClip $item
    }
    if ($chkClearAfterwards.Checked -eq $True) {
        $listBox.Items.Clear()
    }

    $btnCompressAll.IsEnabled = $True
    $labelStatus.Content = ("List contains $($listBox.Items.Count) items. Ready")
}

$clearSelectedButton_Click = {
    while ($listBox.SelectedItems) {
        $CurrItem = $listBox.SelectedItems[0]
        Write-Host "Removing $CurrItem"
        $listBox.Items.Remove($CurrItem)
    }
}

$listBox_DragDrop = [System.Windows.DragEventHandler] {
    $deniedItems = New-Object -TypeName "System.Collections.ArrayList"
    foreach ($filename in $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) {
        # $_ = [System.Windows.Forms.DragEventArgs]
        # Write-Host (Split-Path $filename -Extension) # DEBUG
        # Check that the file extension is supported
        if ($AllowedExtensions -contains (Split-Path $filename -Extension)) {
            $listBox.Items.Add($filename)
        } 
        else {
            Write-Host $basename
            $deniedItems.Add($filename)
        }
    }
    if ($deniedItems.Count -eq 0) {
        $labelStatus.Content = ("List contains $($labelStatus.Items.Count) items. Ready")
    }
    else {
        # Write denied items to the console
        $deniedString = $deniedItems -join ", "
        $labelStatus.Content = ("The following items were denied: $($deniedString)")
    }
}

### Wire up events ###
$btnCompressAll.Add_Click($button_Click)
$btnClearSelected.Add_Click($clearSelectedButton_Click)
# $listBox.Add_PreviewDragOver($listBox_DragOver)
$listBox.Add_Drop($listBox_DragDrop)

# Show MainWindow
$MainWindow.ShowDialog() | Out-Null