#!powershell
# 
# Author: Grzegorz Ochlik <Grzegorz.Ochlik@mbank.pl>
# 
# Updates: 
# - 

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

$changed = $false;
$failed = $false;

$params = Parse-Args $args;
$action = Get-AnsibleParam -obj $params -name "action" -failifempty $true;
$cluster_name = Get-AnsibleParam -obj $params -name "cluster_name" -failifempty $true;
$cluster_group = Get-AnsibleParam -obj $params -name "cluster_group" -failifempty $true;
$waittime_seconds = Get-AnsibleParam -obj $params -name "waittime_seconds";

$msg = "Params: action = $action, cluster_name = $cluster_name; cluster_group = $cluster_group; waittime_seconds = $waittime_seconds; ";

try {
  Get-Cluster | Out-Null;
} 
catch [System.Management.Automation.CommandNotFoundException] {
  $msg += "There is no cluster feature on this machine!";
  FinishScript -failed $true -changed $false -msg $msg;
}

function GetCluster {
  param (
    [string]$name,
    [switch]$noMsg
  )
  $script:msg += "Starting GET action for cluster, ";
  $cluster = (Get-Cluster -Name $name);
  
  if ($cluster) {
    if (!$noMsg) {
      $script:msg += "Cluster name = $($cluster.Name); domain = $($cluster.Domain); id = $($cluster.Id); shared volumes root = $($cluster.SharedVolumesRoot)";
    }
    return $true;
  }

  return $false;
}

switch ($action) {
  "get" { 
    GetCluster -name $cluster_name; 
  }
  "suspend_node" {
    if (GetCluster -name $cluster_name -noMsg) {
      $owner = (Get-ClusterGroup -Name $cluster_group | Select-Object -ExpandProperty OwnerNode | Select-Object -ExpandProperty Name);

      if ($owner -eq $env:COMPUTERNAME) {
        #Moving cluster resources to second node only if current machine is an active node
        $msg += "Moving group $cluster_group to another node, ";
        try {
          Move-ClusterGroup -Name $cluster_group;
          $msg += "ClusterGroup $cluster_group moved to another node, "
        }
        catch {
          $msg += "Exception occured when moving cluster group. Exception was $($_.Exception.Message)";
          FinishScript -failed $true -changed $true -msg $msg;
        }
        #Stopping service, as moving resources does not do it
        $services = (Get-ClusterResource -Cluster $cluster_name | Where-Object ResourceType -eq "Generic Service" | Select-Object -ExpandProperty Name);
        foreach ($service in $services) {
          $msg += "Stopping service $service, ";
          try {
            Stop-Service $service -Force;
            $msg += "Service $service stopped, ";
          }
          catch {
            $msg += "Exception occured during stopping service $service. Exception was $($_.Exception.Message)";
            FinishScript -failed $true -changed $true -msg $msg;
          }
        }
      }
      else {
        $msg += "Moving is not required - resources are connected to another node, ";
      }

      #Suspending cluster node
      $msg += "Suspending cluster node, ";
      try {
        Suspend-ClusterNode -Name $env:COMPUTERNAME -Cluster $cluster_name -Drain -Wait;
        $changed = $true;
      }
      catch {
        $msg += "Exception occured when suspending cluster node. Exception was $($_.Exception.Message)";
        FinishScript -failed $true -changed $true -msg $msg;
      }
      $msg += "Cluster node suspended, ";
    }
  }
  "resume_node" {
    if (GetCluster -name $cluster_name -noMsg) {
      $msg += "Resuming cluster node, ";
      try {
        Resume-ClusterNode -Name $env:COMPUTERNAME -Cluster $cluster_name;
        $msg += "Moving cluster group $cluster_group to node on current machine; ";
        Move-ClusterGroup -Name $cluster_group -Node $env:COMPUTERNAME;

        $ownerNode = (Get-ClusterGroup -Name $cluster_group | Select-Object -ExpandProperty OwnerNode | Select-Object -Expand Name);
        $msg += "Owner node for cluster group $cluster_group is $ownerNode; ";

        if (![string]::IsNullOrEmpty($waittime_seconds)) {
          [int]$seconds = ($waittime_seconds -as [int]);
          if (!$seconds) {
            $seconds = 15;
          }

          $msg += "Waiting $seconds seconds for service to resume; "
          Start-Sleep -Seconds $seconds;
          $msg += "Waiting ended; "
        }
        $changed = $true;
      }
      catch {
        $msg += "Exception occured when resuming cluster node. Exception was $($_.Exception.Message)";
        FinishScript -failed $true -changed $true -msg $msg;
      }
      $msg += "Cluster node resumed to work, ";
    }
  }
  "start_node" {
    if (GetCluster -name $cluster_name -noMsg) {
      $msg += "Starting cluster node, ";
      try {
        Start-ClusterNode -Name $env:COMPUTERNAME -Cluster $cluster_name;
        $changed = $true;
      }
      catch {
        $msg += "Exception occured when starting cluster node. Exception was $($_.Exception.Message)";
        FinishScript -failed $true -changed $true -msg $msg;
      }
      $msg += "Cluster node started, ";
    }
  }
  default {
    $msg += "Wrong mode specified. Allowed (get, suspend_node, start_node); Passed = $action";
  }
}

FinishScript -changed $changed -failed $failed -msg $msg;
