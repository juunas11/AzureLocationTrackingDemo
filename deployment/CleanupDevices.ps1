param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'prod')]
    [string]$environment
)

$ErrorActionPreference = 'Stop'

$config = Get-Content (Join-Path $PSScriptRoot config.json) -Raw | ConvertFrom-Json

$tenantId = $config.tenantId
$subscriptionId = $config.subscriptionId
$resourceGroup = $config.resourceGroup

if ($environment -eq 'dev') {
    $enrollmentGroupName = $config.devEnrollmentGroupName
}
elseif ($environment -eq 'prod') {
    $enrollmentGroupName = $config.prodEnrollmentGroupName
}
else {
    Write-Error "Invalid environment '$environment'"
    Exit
}

# Check subscription is available
az account show -s "$subscriptionId" | Out-Null
if ($LASTEXITCODE -ne 0) {
    az login -t "$tenantId"
}

$dpsResources = az iot dps list --subscription $subscriptionId -g $resourceGroup | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Exit
}

$dpsName = $dpsResources[0].name
$enrollments = az iot dps enrollment-group registration list --subscription $subscriptionId -g $resourceGroup -n $dpsName --group-id $enrollmentGroupName | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Exit
}

$enrollmentCount = $enrollments.Count
Write-Host "Found $enrollmentCount enrollment(s)"

$iotHubs = az iot hub list --subscription $subscriptionId -g $resourceGroup | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Exit
}

$iotHubName = $iotHubs[0].name

foreach ($enrollment in $enrollments) {
    Write-Host "Deleting device $($enrollment.deviceId) from DPS and IoT Hub..."
    az iot dps enrollment-group registration delete --registration-id $enrollment.registrationId -g $resourceGroup -n $dpsName --subscription $subscriptionId
    if ($LASTEXITCODE -ne 0) {
        Exit
    }

    az iot hub device-identity delete --device-id $enrollment.deviceId -g $resourceGroup -n $iotHubName --subscription $subscriptionId
    if ($LASTEXITCODE -ne 0) {
        Exit
    }
}

Write-Host "Cleanup done"