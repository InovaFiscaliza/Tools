<#
.DESCRIPTION
    This script will remove all empty directories in a root folder and its subfolders.

.PARAMETER ROOTFOLDER
    The root folder path where the empty directories are located.

.EXAMPLE
    remove_empty_folders.ps1 -ROOTFOLDER "D:\map"

    This example will remove all empty directories in the "D:\map" folder and its subfolders.
    
.NOTES
    by E! Anatel SFI, FSL 2024
#>
$ROOTFOLDER = "D:\map"  # Replace this with your root folder path

# Get all empty directories in the root folder and its subfolders
$emptyFolders = Get-ChildItem -Path $ROOTFOLDER -Recurse -Directory | Where-Object { $_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0 }

# Remove each empty folder
foreach ($folder in $emptyFolders) {
    Remove-Item -Path $folder.FullName -Force
}