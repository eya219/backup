param (
    [string]$VCENTER_HOST,
    [string]$VCENTER_USER,
    [string]$VCENTER_PASS,
    [string]$SOURCE_VM_NAME,
    [string]$CLONE_VM_NAME,
    [string]$VM_PATH,
    [string]$REMOTE_EXPORT_PATH,
    [string]$PLINK_PATH,
    [string]$LINUX_SSH_USER,
    [string]$LINUX_SSH_PASSWORD,
    [string]$LINUX_SSH_HOST,
    [string]$DATASTORE_NAME = "DatastoreTest2"  # optional parameter to avoid hardcoding
)

# Enforce TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $true

Import-Module VMware.PowerCLI -Force

# PowerCLI Configurations
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
Set-PowerCLIConfiguration -WebOperationTimeoutSeconds 1200 -Scope Session -Confirm:$false

# Connect to vCenter
$vcenter = Connect-VIServer -Server $VCENTER_HOST -User $VCENTER_USER -Password $VCENTER_PASS

# Get the VM object
$vm = Get-VM -Name $SOURCE_VM_NAME -ErrorAction Stop

Write-Host "Creating snapshot for $SOURCE_VM_NAME..."
$snapshot = New-Snapshot -VM $vm -Name "BackupSnapshot" -Description "Snapshot for backup" -Quiesce -Memory:$false

Write-Host "Cloning VM to $CLONE_VM_NAME..."
$datastore = Get-Datastore -Name $DATASTORE_NAME -ErrorAction Stop
$vmHost = $vm.VMHost
$cloneVM = New-VM -Name $CLONE_VM_NAME -VM $vm -Datastore $datastore -VMHost $vmHost -LinkedClone -ReferenceSnapshot $snapshot

# Construct the ovftool command dynamically
$vmPathNormalized = $VM_PATH
if (-not $vmPathNormalized.StartsWith("/")) {
    $vmPathNormalized = "/" + $vmPathNormalized
}

$ovfCommand = "${OVFTOOL_PATH} --noSSLVerify vi://${VCENTER_USER}:${VCENTER_PASS}@${VCENTER_HOST}${vmPathNormalized} ${REMOTE_EXPORT_PATH}"
Write-Host "Remote ovftool command: $ovfCommand"

# Run the command via plink on remote Linux host
$plinkArgs = @(
    "-ssh",
    "-pw", $LINUX_SSH_PASSWORD,
    "$LINUX_SSH_USER@$LINUX_SSH_HOST",
    $ovfCommand
)

Write-Host "Starting remote export with plink..."
& "$PLINK_PATH" @plinkArgs

Write-Host "Deleting cloned VM $CLONE_VM_NAME..."
Get-VM -Name $CLONE_VM_NAME | Remove-VM -DeletePermanently -Confirm:$false

Write-Host "Removing snapshot from original VM..."
Get-Snapshot -VM $vm -Name "BackupSnapshot" | Remove-Snapshot -Confirm:$false

Disconnect-VIServer -Server $vcenter -Confirm:$false

Write-Host "Backup and export completed."
