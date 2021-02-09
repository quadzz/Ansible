#!powershell
#
#Author: Grzegorz Ochlik (grzegorz.ochlik@mbank.pl)
#Descr: Sends mail through EWS 
#Changes:
#
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

trap {
    $failed = $true;
    $msg += "`nException occured: $($_.Exception.Message)";
    FinishScript -changed $changed -failed $failed -msg $msg;
}

$params = Parse-Args $args;
$to = Get-Attr $params "to";
$subject = Get-Attr $params "subject";
$body = Get-Attr $params "body";
$ews_url = Get-Attr $params "ews_url";
$impersonating_user = Get-Attr $params "impersonating_user";

$msg = "Params: to = $to, body = $body, subject = $subject, ews_url = $ews_url, impersonating_user = $impersonating_user; ";
@($to, $subject, $body) | ForEach-Object {
    if ([string]::IsNullOrEmpty($_)) {
        FinishScript -changed $false -failed $true -msg "$msg ## Parameter $_ is null or empty. Finishing scritp!";
    }
}

try {
    $msg += "About to look for an EWS dll; ";
    $ewsDll = (
        (
            $(
                Get-ItemProperty -ErrorAction SilentlyContinue -Path Registry::$(
                    Get-ChildItem -ErrorAction SilentlyContinue -Path 'HKLM:\SOFTWARE\Microsoft\Exchange\Web Services' | 
                    Sort-Object Name -Descending | 
                    Select-Object -First 1 -ExpandProperty Name
                )
            ).'Install Directory'
        ) + "Microsoft.Exchange.WebServices.dll"
    );
    if (Test-Path $ewsDll) {
        $msg += "Found EWS dll in path $ewsDll. Importing it; ";
        Import-Module $ewsDll;
    }
}
catch {
    $msg += "Error during finding and importing EWS dll. Error was:`n $($_.Exception.Message)";
    exit 1;
}

$msg += "Creating EWS object; ";
$ews = (New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1));

#Configure ImpersonatedUserId
$msg += "Setting up ImpersonatedUserId; ";
$ews.ImpersonatedUserId = (New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $impersonating_user));
$ews.UseDefaultCredentials = $true;
$ews.Url = $ews_url;

$message = (New-Object Microsoft.Exchange.WebServices.Data.EmailMessage -ArgumentList $ews);
$message.Subject = "$subject";
#Insert HTML here, or leave it blank. The ${body} token will be replaced by body parameter
$fullBody = '${body}';

$message.Body = $fullBody.Replace("`${body}", $body);
$message.Body.BodyType = "HTML";

$msg += "Parsing recipients; ";
$to.Split(";") | Foreach-Object {
    $message.ToRecipients.Add($_);
};

#$message.ToRecipients.Add();
#$message.CcRecipients.Add();
#$message.BccRecipients.Add();

$msg += "Saving message! ";
$message.SendAndSaveCopy() | Out-Null;
$changed = $true;

$msg += "Script finished";
FinishScript -changed $changed -failed $failed -msg $msg;
