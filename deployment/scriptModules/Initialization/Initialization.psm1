function Get-Configuration {
    param(
        [Parameter(Mandatory = $true)]
        [string] $configPath
    )
    
    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    return $config
}

function Initialize-AzCli {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config
    )

    $tenantId = $config.tenantId
    $subscriptionId = $config.subscriptionId

    # Check subscription is available
    az account show -s "$subscriptionId" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        az login -t "$tenantId"
    }

    # Check azure-iot extension is installed, throw error if not
    $iotExtensionName = az extension list -o tsv --query "[?name == ``azure-iot``].name"
    if (-not $iotExtensionName) {
        throw "Azure CLI IoT extension is not installed. Please install it by running 'az extension add --name azure-iot'"
    }
}

Export-ModuleMember -Function Get-Configuration, Initialize-AzCli
