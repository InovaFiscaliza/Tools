# Constansts that control the script
$CONDA_PATH = "C:\path\to\conda\Scripts\conda.exe" # Adjust this to your Conda installation path
$ENV_NAME = "fileCataloger"
$REPETITION_INTERVAL = 60 # Minutes between each run of the service
$TASK_NAME = "FileCatalogService"
$TASK_DESCRIPTION = "Regulatron file cataloging tool file_catalog.py."

# Define download URLs
$urls = @{
    "config.json" = "https://raw.githubusercontent.com/InovaFiscaliza/Tools/refs/heads/main/FileCataloger/src/config.json";
    "file_catalog.py" = "https://raw.githubusercontent.com/InovaFiscaliza/Tools/refs/heads/main/FileCataloger/src/file_catalog.py";
    "environment.yml" = "https://raw.githubusercontent.com/InovaFiscaliza/Tools/refs/heads/main/FileCataloger/environment.yml"
}

# Define download directory
$downloadDir = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("MyDocuments"), "Downloads", "FileCataloger")
if (!(Test-Path -Path $downloadDir)) {
    New-Item -ItemType Directory -Path $downloadDir
}

# Download files from GitHub
foreach ($fileName in $urls.Keys) {
    $url = $urls[$fileName]
    $filePath = Join-Path -Path $downloadDir -ChildPath $fileName
    Invoke-WebRequest -Uri $url -OutFile $filePath
    Write-Output "Downloaded $fileName to $filePath"
}

$installPath = [System.Environment]::GetFolderPath("ProgramFiles")
if (!(Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Create the Conda environment within the install directory
Write-Output "Creating Conda environment..."
& $CONDA_PATH create --prefix $installPath\$ENV_NAME --file $downloadDir\environment.yml -y

# Verify environment creation
if (!(Test-Path "$installPath\$ENV_NAME")) {
    Write-Output "Conda environment creation failed. Exiting script."
    exit 1
}
Write-Output "Conda environment '$ENV_NAME' created successfully."

# Create a batch file to run the Python script in the Conda environment
$batchFilePath = Join-Path -Path $installPath -ChildPath "run_file_catalog.bat"
$batchContent = @"
@echo off
call $condaPath activate $envName
python $installPath\file_catalog.py
"@
$batchContent | Out-File -FilePath $batchFilePath -Encoding UTF8

# Define trigger, action, and settings for the scheduled task
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.RepetitionInterval = (New-TimeSpan -Minutes $REPETITION_INTERVAL)
$trigger.RepetitionDuration = [TimeSpan]::MaxValue

$action = New-ScheduledTaskAction -Execute $batchFilePath

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `
    -RestartInterval (New-TimeSpan -Minutes $REPETITION_INTERVAL) `
    -RestartCount 3 `
    -MultipleInstances IgnoreNew

# Register the scheduled task
Register-ScheduledTask -TaskName $TASK_NAME `
    -Description $TASK_DESCRIPTION
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -RunLevel Highest `
    -User "SYSTEM"

Write-Output "Scheduled task '$TASK_NAME' created successfully."
