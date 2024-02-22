$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot scriptModules\AzureResources) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Initialization) -Force

# Get port number from Function App launch settings
$launchSettings = Get-Content (Join-Path $PSScriptRoot ..\src\AzureLocationTracking.Functions\Properties\launchSettings.json -Resolve) -Raw | ConvertFrom-Json
$cliArgs = $launchSettings.profiles.'AzureLocationTracking.Functions'.commandLineArgs
# Assuming value is just "--port 7090" etc.
$port = $cliArgs.Substring("--port ".Length)

# Run ngrok with that port
$argumentList = "http --host-header=localhost $port"

Start-Process -FilePath "ngrok" -ArgumentList $argumentList

# Wait for ngrok to start
do {
    Start-Sleep -Seconds 1
    $ngrokConnection = Get-NetTCPConnection | Where-Object Localport -eq 4040
} while (-not $ngrokConnection -or $ngrokConnection.State -ne "Listen")

Write-Host "Ngrok is running."

# Get ngrok URL
do {
    Start-Sleep -Seconds 1
    $tunnels = curl -s "http://localhost:4040/api/tunnels" | ConvertFrom-Json
    $ngrokUrl = ($tunnels.tunnels | Where-Object { $_.proto -eq 'https' }).public_url
} while (-not $ngrokUrl)

Write-Host "Got ngrok URL: $ngrokUrl"

# Update SignalR upstreams
$config = Get-Configuration -configPath config.json
Initialize-AzCli -config $config

$subscriptionId = $config.subscriptionId
$resourceGroup = $config.resourceGroup

$signalRName = az signalr list --subscription $subscriptionId -g $resourceGroup --query "[].name" -o tsv

$signalRUpstreamUrls = Get-SignalRUpstreamUrls -config $config
$prodSignalRUpstreamUrl = $signalRUpstreamUrls.prodUpstreamUrl
$devSignalRUpstreamUrl = "$ngrokUrl/runtime/webhooks/signalr"

$functionApp = az functionapp list --subscription "$subscriptionId" -g "$resourceGroup" | ConvertFrom-Json
$functionsAppName = $functionApp[0].name
$functionsAppHostName = $functionApp[0].defaultHostName

Set-SignalRUpstreamUrls -config $config `
    -signalRName $signalRName `
    -currentProdUpstreamUrl $prodSignalRUpstreamUrl `
    -currentDevUpstreamUrl $devSignalRUpstreamUrl `
    -functionsAppName $functionsAppName `
    -functionsAppHostName $functionsAppHostName

Write-Host "Ngrok is running and the upstream is setup. The Function App should be able to receive SignalR messages."
