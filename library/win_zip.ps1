#!powershell
# 
# Author: Ochlik, Grzegorz, (mBank/DBI) <Grzegorz.Ochlik@mbank.pl>
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
$src = Get-AnsibleParam -obj $params -name "src" -failifempty $true;
$dest = Get-AnsibleParam -obj $params -name "dest" -failifempty $true;

$changed = $true;
$failed = $false;
$msg = "src = $src, dest = $dest; ";

trap {
    $msg += "Exception occured! $($_.Exception.Message)";
    $failed = $true;
    FinishScript -changed $changed -failed $failed -msg $msg;
}

if (Get-Command "Compress-Archive" -ErrorAction SilentlyContinue) {
    #Proper way
    if (Test-Path $src) {
        $msg += "About to compress path $src to destination $dest, "
        Compress-Archive -Path $src -DestinationPath $dest -Force; 
        $msg += "Compressed srv $src with Compress-Archive function, ";
    }
    else {
        $msg += "Path $src does not exist!";
        FinishScript -changed $false -failed $true -msg $msg;
    }
}
else {
    $msg += "Using legacy CreateFromDirecotry! ";
    #Legacy, but we gotta make sure that we can handle even older machines (PS < 5)
    if (Test-Path $src -PathType Container) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem;
        $msg += "About to compress folder $src to file $dest, ";
        [System.IO.Compression.ZipFile]::CreateFromDirectory($src, $dest);
        $msg += "Compressed archive with the legacy function; ";
        $changed = $true;
    }
    else {
        $msg += "Path $src does not exist or is not a folder!";
        FinishScript -changed $false -failed $true -msg $msg;
    }
}

FinishScript -changed $changed -failed $failed -msg $msg;