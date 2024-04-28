using Microsoft.Azure.Devices.Shared;
using Microsoft.Azure.Devices;
using Azure.Core;
using Microsoft.Extensions.Configuration;

namespace AzureLocationTracking.Functions.Services;

public class IotHubDeviceTwinService
{
    private readonly string _iotHubHostName;
    private readonly TokenCredential _tokenCredential;

    public IotHubDeviceTwinService(
        IConfiguration configuration,
        TokenCredential tokenCredential)
    {
        _iotHubHostName = configuration["IotHubHostName"];
        _tokenCredential = tokenCredential;
    }

    public async Task UpdateTwinPropertiesAsync(
        Guid vehicleId,
        int speedKilometersPerHour,
        int eventIntervalMillis)
    {
        using var registryManager = RegistryManager.Create(_iotHubHostName, _tokenCredential);
        var twin = await registryManager.GetTwinAsync(vehicleId.ToString());
        var twinPatch = new Twin();
        twinPatch.Properties.Desired["speedKilometersPerHour"] = speedKilometersPerHour;
        twinPatch.Properties.Desired["eventIntervalMillis"] = eventIntervalMillis;
        await registryManager.UpdateTwinAsync(vehicleId.ToString(), twinPatch, twin.ETag);
    }
}
