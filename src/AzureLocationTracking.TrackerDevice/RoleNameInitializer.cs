using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace AzureLocationTracking.TrackerDevice;

public class RoleNameInitializer : ITelemetryInitializer
{
    private readonly Guid _deviceId;

    public RoleNameInitializer(DeviceIdProvider deviceIdProvider)
    {
        _deviceId = deviceIdProvider.DeviceId;
    }

    public void Initialize(ITelemetry telemetry)
    {
        telemetry.Context.Cloud.RoleName = "Tracker device";
        telemetry.Context.Cloud.RoleInstance = _deviceId.ToString();
    }
}
