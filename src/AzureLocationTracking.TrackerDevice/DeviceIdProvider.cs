namespace AzureLocationTracking.TrackerDevice;

public class DeviceIdProvider
{
    public DeviceIdProvider(Guid deviceId)
    {
        DeviceId = deviceId;
    }

    public Guid DeviceId { get; }
}