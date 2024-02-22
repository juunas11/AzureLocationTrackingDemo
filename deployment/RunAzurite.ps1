$location = Join-Path $Env:TEMP "Azurite"
$debugLog = Join-Path $location "debug.log"

Start-Process -FilePath "azurite.cmd" -ArgumentList "--location $location --debug $debugLog --skipApiVersionCheck"