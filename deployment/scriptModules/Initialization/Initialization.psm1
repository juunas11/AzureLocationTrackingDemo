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
}

Export-ModuleMember -Function Get-Configuration, Initialize-AzCli
