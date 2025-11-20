# ===========================
# VCF9Auto.ps1
# Automates AZ Host/VM Groups and VM-to-Host Rules from CSV
# ===========================

# Prompt for inputs
$vCenter = Read-Host "Enter vCenter FQDN"
Connect-VIServer -Server $vCenter

$clusterName = Read-Host "Enter Cluster Name"
$cluster = Get-Cluster -Name $clusterName
$clusterView = $cluster.ExtensionData

$hostsCsv = Read-Host "Enter path to Hosts.csv"
$vmsCsv = Read-Host "Enter path to VMs.csv"

# Log file
$logFile = "C:\Staging\Stretch\AZPlacement-Log.csv"
"Action,Status,Message" | Out-File $logFile

function LogAction($action, $status, $message) {
    "$action,$status,$message" | Out-File $logFile -Append
}

# ===========================
# Step 1: Create Host Groups from Hosts.csv
# ===========================
$hostsData = Import-Csv $hostsCsv
$hostGroups = $hostsData | Group-Object HostRuleName

foreach ($group in $hostGroups) {
    $groupName = $group.Name
    $hostNames = $group.Group.HostName

    if (-not (Get-DrsClusterGroup -Cluster $cluster -Name $groupName -ErrorAction SilentlyContinue)) {
        try {
            $vmHosts = Get-VMHost -Name $hostNames
            if ($vmHosts.Count -eq 0) {
                LogAction "Create $groupName" "Warning" "No matching hosts found"
            } else {
                New-DrsClusterGroup -Cluster $cluster -Name $groupName -VMHost $vmHosts
                LogAction "Create $groupName" "Success" "Host group created with $($vmHosts.Count) hosts"
            }
        } catch {
            LogAction "Create $groupName" "Error" $_.Exception.Message
        }
    } else {
        LogAction "Create $groupName" "Skipped" "Already exists"
    }
}

# ===========================
# Step 2: Create VM Groups from VMs.csv (Tag-based)
# ===========================
$vmsData = Import-Csv $vmsCsv

foreach ($row in $vmsData) {
    $tagName = $row.TagName
    $vmGroupName = $row.VMRuleName

    $vms = Get-VM | Where-Object { ($_ | Get-TagAssignment).Tag.Name -eq $tagName }

    if ($vms.Count -eq 0) {
        LogAction "Tag Check $tagName" "Warning" "No VMs found with tag $tagName"
    }

    if (-not (Get-DrsClusterGroup -Cluster $cluster -Name $vmGroupName -ErrorAction SilentlyContinue)) {
        try {
            New-DrsClusterGroup -Cluster $cluster -Name $vmGroupName -VM $vms
            LogAction "Create $vmGroupName" "Success" "VM group created with $($vms.Count) VMs"
        } catch {
            LogAction "Create $vmGroupName" "Error" $_.Exception.Message
        }
    } else {
        LogAction "Create $vmGroupName" "Skipped" "Already exists"
    }
}

# ===========================
# Step 3: Create VM-to-Host Rules via API
# ===========================
try {
    $spec = New-Object VMware.Vim.ClusterConfigSpecEx
    $spec.RulesSpec = @()

    foreach ($row in $vmsData) {
        $ruleName = $row.VMRuleName + "-to-Host"
        $vmGroupName = $row.VMRuleName
        $hostGroupName = $row.HostGroupName

        if (-not (Get-DrsRule -Cluster $cluster -Name $ruleName -ErrorAction SilentlyContinue)) {
            $ruleSpec = New-Object VMware.Vim.ClusterRuleSpec
            $ruleSpec.Info = New-Object VMware.Vim.ClusterVmHostRuleInfo
            $ruleSpec.Info.Name = $ruleName
            $ruleSpec.Info.Enabled = $true
            $ruleSpec.Info.VmGroupName = $vmGroupName
            $ruleSpec.Info.AffineHostGroupName = $hostGroupName
            $ruleSpec.Info.Mandatory = $false
            $ruleSpec.Operation = "add"
            $spec.RulesSpec += $ruleSpec
        } else {
            LogAction "Create $ruleName" "Skipped" "Rule already exists"
        }
    }

    if ($spec.RulesSpec.Count -gt 0) {
        $task = $clusterView.ReconfigureComputeResource_Task($spec, $true)
        LogAction "Create VM/Host Rules" "Success" "Task started: $task"
    } else {
        LogAction "Create VM/Host Rules" "Skipped" "All rules already exist"
    }
} catch {
    LogAction "Create VM/Host Rules" "Error" $_.Exception.Message
}

# ===========================
# Verification
# ===========================
LogAction "Verification" "Info" "Completed listing of groups and rules"
Write-Host "`nAutomation complete. Log saved to $logFile"