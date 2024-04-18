<#
.DESCRIPTION
    This script will move files from a root folder to subfolders based on their names and key-value pairs in a hashtable.

.PARAMETER ROOTFOLDER
    The root folder path where the files are located.

.PARAMETER PATTERNS
    A hashtable containing key-value pairs of file name patterns and their corresponding folder names.
    

.EXAMPLE
    sort_files.ps1 -ROOTFOLDER "D:\map" -PATTERNS @{"*Height*" = "Height"; "*Clutter*" = "Clutter"; "*Vias*" = "Vias"; "*Mapas*" = "Mapas"}

    This example will move files from the "D:\map" folder to subfolders named "Height", "Clutter", "Vias", and "Mapas" based on the file name patterns.

.NOTES
    by E! Anatel SFI, FSL 2024
#>

$ROOTFOLDER = "D:\map"  # Replace this with your root folder path

# Define an array of file name PATTERNS and their corresponding folder names
$PATTERNS = @{
    "*Height*" = "Height"
    "*Clutter*" = "Clutter"
    "*Vias*" = "Vias"
    "*Mapas*" = "Mapas"
}

foreach ($pattern in $PATTERNS.GetEnumerator()) {
    $folderName = $pattern.Value
    $files = Get-ChildItem -Path $ROOTFOLDER -Recurse -File | Where-Object { $_.Name -like $pattern.Key }

    foreach ($file in $files) {
        $destinationFolder = Join-Path -Path $ROOTFOLDER -ChildPath $folderName
        if (-not (Test-Path -Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory | Out-Null
        }
        Move-Item -Path $file.FullName -Destination $destinationFolder -Force
    }
}