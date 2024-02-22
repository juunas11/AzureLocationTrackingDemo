function Set-DpsEnrollmentGroups {
    param (
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs
    )

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup
    $devEnrollmentGroupName = $config.devEnrollmentGroupName
    $prodEnrollmentGroupName = $config.prodEnrollmentGroupName

    # Create/update enrollment groups in Device Provisioning Service
    $dpsName = $mainBicepOutputs.deviceProvisioningServiceName.value
    $iotHubHostName = $mainBicepOutputs.iotHubHostName.value

    $initialTwinProperties = "{'eventIntervalMillis':10000,'speedKilometersPerHour':50}"

    Write-Host "Getting DPS enrollment groups..."
    $enrollmentGroups = az iot dps enrollment-group list --subscription "$subscriptionId" -g "$resourceGroup" `
        --dps-name $dpsName --query "[?enrollmentGroupId=='$devEnrollmentGroupName']" | ConvertFrom-Json
    if ($enrollmentGroups.Length -eq 0) {
        $devEnrollmentGroup = az iot dps enrollment-group create --subscription "$subscriptionId" -g "$resourceGroup" `
            --dps-name $dpsName --enrollment-id $devEnrollmentGroupName --allocation-policy "hashed" `
            --provisioning-status "enabled" --iot-hubs $iotHubHostName --reprovision-policy "reprovisionandmigratedata" `
            --initial-twin-properties "$initialTwinProperties" `
            --initial-twin-tags "{'environment':'dev'}" | ConvertFrom-Json
        Write-Host "Created new DPS development enrollment group"
    }
    else {
        $devEnrollmentGroup = az iot dps enrollment-group update --subscription "$subscriptionId" -g "$resourceGroup" `
            --dps-name $dpsName --enrollment-id $devEnrollmentGroupName --allocation-policy "hashed" `
            --provisioning-status "enabled" --iot-hubs $iotHubHostName --reprovision-policy "reprovisionandmigratedata" `
            --initial-twin-properties "$initialTwinProperties" `
            --initial-twin-tags "{'environment':'dev'}" | ConvertFrom-Json
        Write-Host "Updated DPS development enrollment group"
    }

    $enrollmentGroups = az iot dps enrollment-group list --subscription "$subscriptionId" -g "$resourceGroup" `
        --dps-name $dpsName --query "[?enrollmentGroupId=='$prodEnrollmentGroupName']" | ConvertFrom-Json
    if ($enrollmentGroups.Length -eq 0) {
        $prodEnrollmentGroup = az iot dps enrollment-group create --subscription "$subscriptionId" -g "$resourceGroup" `
            --dps-name $dpsName --enrollment-id $prodEnrollmentGroupName --allocation-policy "hashed" `
            --provisioning-status "enabled" --iot-hubs $iotHubHostName --reprovision-policy "reprovisionandmigratedata" `
            --initial-twin-properties "$initialTwinProperties" `
            --initial-twin-tags "{'environment':'prod'}" | ConvertFrom-Json
        Write-Host "Created new DPS production enrollment group"
    }
    else {
        $prodEnrollmentGroup = az iot dps enrollment-group update --subscription "$subscriptionId" -g "$resourceGroup" `
            --dps-name $dpsName --enrollment-id $prodEnrollmentGroupName --allocation-policy "hashed" `
            --provisioning-status "enabled" --iot-hubs $iotHubHostName --reprovision-policy "reprovisionandmigratedata" `
            --initial-twin-properties "$initialTwinProperties" `
            --initial-twin-tags "{'environment':'prod'}" | ConvertFrom-Json
        Write-Host "Updated DPS production enrollment group"
    }

    return @{   
        prodEnrollmentGroupPrimaryKey = $prodEnrollmentGroup.attestation.symmetricKey.primaryKey
        devEnrollmentGroupPrimaryKey  = $devEnrollmentGroup.attestation.symmetricKey.primaryKey
    }
}

Export-ModuleMember -Function Set-DpsEnrollmentGroups
