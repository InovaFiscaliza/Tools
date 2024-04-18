<#
.DESCRIPTION
    This script will rename files in a root folder and its subfolders to include the folder name as a prefix.

.PARAMETER ROOTFOLDER
    The root folder path where the files are located.

.EXAMPLE
    name_path.ps1 -ROOTFOLDER "D:\Mapas"

    This example will rename files in the "D:\Mapas" folder and its subfolders to include the folder name as a prefix.
    
.NOTES
    by E! Anatel SFI, FSL 2024
#>

$ROOTFOLDER = "D:\Mapas"

# Get all files in the root folder and its subfolders
$files = Get-ChildItem -Path $ROOTFOLDER -File -Recurse

foreach ($file in $files) {
    $folderName = $file.Directory.Name

    # Check if the file name starts with the folder name
    if (-not $file.Name.StartsWith($folderName)) {
        # Rename the file to include the folder name as a prefix
        $newFileName = "$folderName" + "_" + $file.Name
        $newFilePath = Join-Path -Path $file.Directory.FullName -ChildPath $newFileName
        Rename-Item -Path $file.FullName -NewName $newFileName -Force
    }
}
