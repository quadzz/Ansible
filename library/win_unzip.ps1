#!powershell
# 
# Author: Grzegorz Ochlik <Grzegorz.Ochlik@mbank.pl>
# 
# WANT_JSON
# POWERSHELL_COMMON

function FinishScript {
    param (
        [bool]$changed,
        [bool]$failed,
        [string]$msg
    )

    $result = New-Object PSObject @{
        changed = $changed
        failed = $failed
        msg = $msg
    }

    Exit-Json $result;
}

$params = Parse-Args $args;
$zip_file = Get-AnsibleParam -obj $params -name "zip_file" -failifempty $true;
$out_folder = Get-AnsibleParam -obj $params -name "out_folder" -failifempty $true;
$app_name = Get-AnsibleParam -obj $params -name "app_name";
$delete_archive = Get-AnsibleParam -obj $params -name "delete_archive";

$delete_archive_bool = try {
    [System.Convert]::ToBoolean($delete_archive);
} 
catch [FormatException] {
    $false;
}

$changed = $true;
$failed = $false;
$msg = "zip_file = $zip_file, out_folder = $out_folder, app_name = $app_name, delete_archive = $delete_archive, delete_archive_bool(parsed) = $delete_archive_bool; ";

trap {
    $msg += "Exception occured! $($_.Exception.Message)";
    $failed = $true;
    FinishScript -changed $changed -failed $failed -msg $msg;
}

if (Get-Command "Expand-Archive" -ErrorAction SilentlyContinue) {
    #Proper way
    Expand-Archive -Path $zip_file -DestinationPath $out_folder -Force;
    $msg += "Expanded archive with the expand-archive function, ";
}
else {
    $msg += "Using legacy ExtractToDirectory! ";
    #Legacy, but we gotta make sure that we can handle even older machines (PS < 5)
    Add-Type -AssemblyName System.IO.Compression.FileSystem;
    $msg += "About to expand archive $zip_file to folder $out_folder, ";
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip_file, $out_folder);
    $msg += "Expanded archive with the legacy function; ";
}
$changed = $true;

if (!([string]::IsNullOrEmpty($app_name))) {
    #Ommit the folder (move items from one level up)
    $notNeededPath = (Join-Path $out_folder $app_name);
    if (Test-Path $notNeededPath) {
        $msg += "Handling items one level below, will move items from $notNeededPath, ";
        Get-ChildItem $notNeededPath -Recurse | Move-Item -Destination $out_folder -Force;
        Remove-Item $notNeededPath;
        $msg += "items moved!; ";    
    }
    else {
        $msg += "Moving level up is not needed. There is no path $notNeededPath; ";
    }
}

if ($delete_archive_bool) {
    Remove-Item $zip_file -Force;
    $msg += "zip_file file removed!";
}

FinishScript -changed $changed -failed $failed -msg $msg;