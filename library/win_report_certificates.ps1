#!powershell

#Author: Grzegorz Ochlik (grzegorz.ochlik@mbank.pl)
#Descr: Reports existing certificates

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

$failed = $false;
$changed = $false;
$msg = "";

$params = Parse-Args $args;
$reportPath = Get-Attr $params "report_path";
$arti_uri = Get-Attr $params "arti_uri";
$arti_user = Get-Attr $params "arti_user";
$arti_password = Get-Attr $params "arti_password";
$env = Get-Attr $params "env";

$msg = "Params: reportPath = $reportPath, arti_uri = $arti_uri, arti_user = $arti_user, env = $env; ";

trap {
    $msg += "`nException occured: $($_.Exception.Message)";
    $failed = $true;
    FinishScript -changed $changed -failed $failed -msg $msg;
}

$stores = @("My", "TrustedPeople");
$msg += "Getting certificates from LocalMachine; ";
[System.Collections.ArrayList]$list = @();

foreach ($store in $stores) {
    $msg += "Getting certificates from store $store; ";
    $certificates = Get-ChildItem Cert:\LocalMachine\$store | 
                    Select-Object Subject, Thumbprint, NotBefore, NotAfter, Issuer, EnhancedKeyUsageList, DnsNameList;

    $json = "";

    foreach ($cert in $certificates) {
        if ($cert.EnhancedKeyUsageList) {
            $usage = [string]::Join(",", ($cert.EnhancedKeyUsageList | Select-Object -Expand $_ | Select-Object -Expand FriendlyName -Unique));
        }
        else {
            $usage = "";
        }
    
        if ($cert.DnsNameList) {
            $altNames = [string]::Join(",", ($cert.DnsNameList | Select-Object -Expand $_ | Select-Object -Expand Unicode));
        }
    
        $certObject = [PSCustomObject]@{
            Store = $store
            Thumbprint = $cert.Thumbprint
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            ValidUntil = $cert.NotAfter.ToString("yyyy-MM-dd")
            Usage = $usage
            AltNames = $altNames
            Environment = $env
        };
        
        $list.Add($certObject) | Out-Null;
    }
}

$obj = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    CertsList = $list
};

$json = $obj | ConvertTo-Json;
if (([string]::IsNullOrEmpty($artifactory_user) -or [string]::IsNullOrEmpty($artifactory_password)) -and (![string]::IsNullOrEmpty($reportPath))) {
    $msg += "Writing report to $reportPath; "; 
    [IO.File]::WriteAllLines((Join-Path $reportPath "$env:COMPUTERNAME.json"), $json);
}
else {
    $msg += "Will send report to artifactory; "
    $tempPath = "C:\Temp";
    if (!(Test-Path $tempPath)) {
        New-Item $tempPath -ItemType Directory;
    }
    $file = (Join-Path $tempPath "$env:COMPUTERNAME.json");
    $msg += "Writing to path $file; ";
    [IO.File]::WriteAllLines($file, $json);
    
    $fileName = (Split-Path $file -Leaf);
    $msg += "Filename is $fileName; ";
    $pass = ($arti_password | ConvertTo-SecureString -AsPlainText -Force);

    $cred = (New-Object pscredential -ArgumentList $arti_user, $pass);
    $msg += "Created credentials for $arti_user; ";
    $dest = "$arti_uri/$env/$fileName";

    if (Test-Path $file) {
        $msg += "File $file exists; Sending report to $dest; ";
        Invoke-WebRequest -Uri $dest -InFile $file -Method PUT -Credential $cred -UseBasicParsing;
        $msg += "File $filename was sent! ";
        $changed = $true;
    }
    else {
        FinishScript -changed $true -failed $true -msg "File $file does not exist!"
    }
}

$msg += "Finishing script"
FinishScript -changed $true -failed $false -msg $msg;