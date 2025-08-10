# Run ovftool remotely and capture ALL output (stderr included)
$remoteCmd = "/usr/local/bin/ovftool/ovftool --acceptAllEulas --noSSLVerify --X:logLevel=verbose $env:REMOTE_OVA_PATH 2>&1"

$plinkArgsSize = @(
    "-ssh",
    "-pw", $env:LINUX_SSH_PASSWORD,
    "$env:LINUX_SSH_USER@$env:LINUX_SSH_HOST",
    "sh -c '$remoteCmd'"
)

$fullOutput = (& "$env:PLINK_PATH" @plinkArgsSize).Trim()

Write-Host "Full ovftool output:"
Write-Host $fullOutput

# Now filter for "Capacity" locally in PowerShell
$ovaCapacityOutput = $fullOutput | Select-String -Pattern "Capacity" -SimpleMatch


if (-not $ovaCapacityOutput) {
    Write-Error "ERROR: No output from remote ovftool command."
    exit 1
}

# Extract just the matched lines as strings (there can be multiple matches)
$ovaCapacityOutput = $ovaCapacityOutput | ForEach-Object { $_.Line }

# If multiple lines, join into one string (optional, based on your needs)
if ($ovaCapacityOutput -is [System.Array]) {
    $ovaCapacityOutput = $ovaCapacityOutput -join "`n"
}

# Now you can safely trim
$ovaCapacityOutput = $ovaCapacityOutput.Trim()

if ($ovaCapacityOutput -match "Capacity:\s+([\d\.]+)\s+GB") {
    $ovaSizeGB = [math]::Ceiling([double]$matches[1])
    Write-Host "Provisioned OVA disk size: $ovaSizeGB GB"
} else {
    Write-Error "ERROR: Could not detect provisioned disk size from OVA."
    exit 1
}

Write-Host "Connecting to vCenter..."
Connect-VIServer -Server $env:VCENTER_HOST -User $env:VCENTER_USER -Password $env:VCENTER_PASS

$datastores = Get-Datastore | Select-Object Name, @{Name="FreeGB"; Expression={[math]::Round($_.FreeSpaceMB / 1024, 2)}}

Write-Host "Available datastores:"
$datastores | Format-Table -AutoSize

$selectedDatastore = $null
foreach ($ds in $datastores) {
    Write-Host "Checking datastore '$($ds.Name)' with free space $($ds.FreeGB) GB"
    if ($ds.FreeGB -gt ($ovaSizeGB * 1.2)) {
        Write-Host "Datastore '$($ds.Name)' is suitable."
        $selectedDatastore = $ds.Name
        break
    }
}

if (-not $selectedDatastore) {
    Write-Error "ERROR: No datastore has enough space for OVA ($ovaSizeGB GB)."
    Disconnect-VIServer -Confirm:$false
    exit 1
}

Write-Host "Selected datastore: $selectedDatastore"

# Add date suffix to VM name
$DateSuffix = Get-Date -Format "yyyyMMdd"
$VMNameWithDate = "$env:TARGET_VM_NAME-$DateSuffix"
Write-Host "VM will be restored as: $VMNameWithDate"

$ovfImportCommand = "/usr/local/bin/ovftool/ovftool --acceptAllEulas --noSSLVerify --overwrite --datastore=$selectedDatastore --name=$VMNameWithDate $env:REMOTE_OVA_PATH vi://$env:VCENTER_USER`:$env:VCENTER_PASS@$env:VCENTER_HOST/$env:TARGET_VM_FOLDER"

Write-Host "Remote OVFTOOL import command:"
Write-Host $ovfImportCommand

$plinkArgsRestore = @(
    "-ssh",
    "-pw", $env:LINUX_SSH_PASSWORD,
    "$env:LINUX_SSH_USER@$env:LINUX_SSH_HOST",
    $ovfImportCommand
)

& "$env:PLINK_PATH" @plinkArgsRestore

Write-Host "OVA restore completed."

Disconnect-VIServer -Confirm:$false
