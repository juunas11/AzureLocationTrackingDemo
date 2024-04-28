using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace AzureLocationTracking.VehicleSimulator;

public class RoleNameInitializer : ITelemetryInitializer
{
    private readonly Guid _deviceId;

    public RoleNameInitializer(DeviceIdProvider deviceIdProvider)
    {
        _deviceId = deviceIdProvider.DeviceId;
    }

    public void Initialize(ITelemetry telemetry)
    {
        telemetry.Context.Cloud.RoleName = "Vehicle simulator";
        telemetry.Context.Cloud.RoleInstance = _deviceId.ToString();
    }
}
