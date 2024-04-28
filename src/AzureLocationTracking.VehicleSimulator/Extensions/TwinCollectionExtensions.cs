using Microsoft.Azure.Devices.Shared;

namespace AzureLocationTracking.VehicleSimulator.Extensions;
internal static class TwinCollectionExtensions
{
    internal static int GetIntegerOrDefault(this TwinCollection collection, string key, int defaultValue)
    {
        return collection.Contains(key) ? (int)collection[key] : defaultValue;
    }
}
