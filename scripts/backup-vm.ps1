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
    [string]$LINUX_SSH_HOST
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $true

Import-Module VMware.PowerCLI -Force
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$vcenter = Connect-VIServer -Server $env:VCENTER_HOST -User $env:VCENTER_USER -Password $env:VCENTER_PASS -Force


$vcenter = Connect-VIServer -Server $VCENTER_HOST -User $VCENTER_USER -Password $VCENTER_PASS
$global:DefaultVIServers[0].ExtensionData.Client.Timeout = 1200000

$vm = Get-VM -Name $SOURCE_VM_NAME

Write-Host "Creating snapshot..."
$snapshot = New-Snapshot -VM $vm -Name "BackupSnapshot" -Description "Snapshot for manual backup" -Quiesce -Memory:$false

Write-Host "Cloning VM to $CLONE_VM_NAME..."
$datastore = Get-Datastore -Name Ds3
$vmHost = (Get-VM -Name $SOURCE_VM_NAME).VMHost
New-VM -Name $CLONE_VM_NAME -VM $vm -Datastore $datastore -VMHost $vmHost -LinkedClone -ReferenceSnapshot $snapshot

Write-Host "Removing snapshot from original VM..."
# Uncomment the next line to remove snapshot immediately if needed
# Get-Snapshot -VM $vm -Name "BackupSnapshot" | Remove-Snapshot -Confirm:$false

$ovfCommand = "/usr/local/bin/ovftool/ovftool --noSSLVerify vi://${VCENTER_USER}:${VCENTER_PASS}@${VCENTER_HOST}/${VM_PATH} ${REMOTE_EXPORT_PATH}"

Write-Host "Remote ovftool command: $ovfCommand"

$plinkArgs = @(
    "-ssh",
    "-pw", $LINUX_SSH_PASSWORD,
    "$LINUX_SSH_USER@$LINUX_SSH_HOST",
    $ovfCommand
)
& "$PLINK_PATH" @plinkArgs

Write-Host "Deleting cloned VM..."
Get-VM -Name $CLONE_VM_NAME | Remove-VM -DeletePermanently -Confirm:$false
Get-Snapshot -VM $vm -Name "BackupSnapshot" | Remove-Snapshot -Confirm:$false
Disconnect-VIServer -Server $vcenter -Confirm:$false

Write-Host "Backup and export completed."
