function Get-AdxAccessToken {
    return az account get-access-token --resource "https://api.kusto.windows.net" --query "accessToken" | ConvertFrom-Json | ConvertTo-SecureString -AsPlainText -Force
}

function Get-SetupQueries {
    param(
        [Parameter(Mandatory = $true)]
        [string] $setupScriptPath
    )

    $rawSetupQueries = (Get-Content $setupScriptPath -Raw).Split(".")
    $setupQueries = @()
    foreach ($query in $rawSetupQueries) {
        if ($query.Length -eq 0) {
            continue
        }

        $setupQueries += "." + $query.Trim()
    }

    return $setupQueries
}

function Invoke-AdxSetupScript {
    param(
        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $setupScriptPath
    )

    # Create tables and JSON mappings in Data Explorer
    $adxClusterUri = $mainBicepOutputs.adxClusterUri.value
    $prodAdxDbName = $mainBicepOutputs.prodAdxDbName.value
    $devAdxDbName = $mainBicepOutputs.devAdxDbName.value

    Write-Host "Creating/updating tables and JSON mappings in Data Explorer..."
    $adxToken = Get-AdxAccessToken

    $adxDatabases = @($prodAdxDbName, $devAdxDbName)
    $setupQueries = Get-SetupQueries -setupScriptPath $setupScriptPath

    foreach ($database in $adxDatabases) {
        foreach ($query in $setupQueries) {
            $body = @{
                db  = $database
                csl = $query
            } | ConvertTo-Json
            $headers = @{
                'Accept'       = 'application/json'
                'Content-Type' = 'application/json; charset=utf-8'
            }
            Invoke-RestMethod -Method Post -Uri "$adxClusterUri/v1/rest/mgmt" -Authentication Bearer -Token $adxToken -Body $body -Headers $headers | Out-Null
        }
    }
}

Export-ModuleMember -Function Invoke-AdxSetupScript