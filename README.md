VCF9 Automated Creation of Host/VM Groups and Rules based on VM Tag Assignments


## Overview
This PowerShell script automates the creation of DRS Host Groups, VM Groups, and VM-to-Host affinity rules in a vSphere cluster based on input from CSV files.

---

## Prerequisites
- VMware PowerCLI installed.
- Access to vCenter with appropriate permissions.
- Existing tags assigned to VMs (by another automation process).
- Cluster must be configured for DRS.

---

## Files
- **VCF9Auto.ps1** – The main script.
- **Example-Hosts.csv** – Sample host mapping.
- **Example-VMs.csv** – Sample VM-to-host rule mapping.

---

## CSV Formats
### Example-Hosts.csv
```
HostName,HostRuleName
hostname1.fqdn,AZ1-Hosts
hostname2.fqdn,AZ1-Hosts
hostname3.fqdn,AZ1-Hosts
hostname4.fqdnm,AZ2-Hosts
hostname5.fqdn,AZ2-Hosts
hostname6.fqdn,AZ2-Hosts
```

### Example-VMs.csv
```
TagName,VMRuleName,HostGroupName
AZ1,AZ1-VMs,AZ1-Hosts
AZ2,AZ2-VMs,AZ2-Hosts
```

---

## Usage
1. Launch PowerShell and connect to vCenter:
   ```powershell
   Connect-VIServer -Server <vCenter_FQDN>
   ```
2. Run the script:
   ```powershell
   .\VCF9Auto.ps1
   ```
3. Provide inputs when prompted:
   - vCenter FQDN
   - Cluster Name
   - Path to Hosts.csv
   - Path to VMs.csv

---

## What the Script Does
1. Creates Host Groups from Hosts.csv.
2. Creates VM Groups based on tags from VMs.csv.
3. Creates VM-to-Host affinity rules linking VM groups to host groups.
4. Logs all actions to:
   ```
   C:\Staging\Stretch\AZPlacement-Log.csv
   ```

---

## Assumptions
- Tags referenced in VMs.csv already exist and are assigned to VMs.
- Hostnames in Hosts.csv match actual ESXi hosts in the cluster.

