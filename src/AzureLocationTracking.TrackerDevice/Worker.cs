using AzureLocationTracking.Messages;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.Azure.Devices.Client;
using Microsoft.Azure.Devices.Provisioning.Client.Transport;
using Microsoft.Azure.Devices.Provisioning.Client;
using Microsoft.Azure.Devices.Shared;
using Microsoft.Data.SqlClient;
using NetTopologySuite.Features;
using NetTopologySuite.Geometries;
using NetTopologySuite.IO.Converters;
using System.Text;
using System.Text.Json;
using Dapper;

namespace AzureLocationTracking.TrackerDevice;

public class Worker : BackgroundService
{
    private const int DefaultEventIntervalMillis = 10_000;
    private const int DefaultSpeedKilometersPerHour = 50;
    private readonly ILogger<Worker> _logger;
    private readonly TelemetryClient _telemetryClient;
    private readonly string _environment;
    private readonly string _sqlConnectionString;
    private readonly string _deviceProvisioningGlobalEndpoint;
    private readonly string _deviceProvisioningIdScope;
    private readonly string _deviceProvisioningPrimaryKey;
    private readonly string _iotHubHostName;
    private readonly int _simulatedDeviceCount;

    public Worker(
        ILogger<Worker> logger,
        TelemetryClient telemetryClient,
        IConfiguration configuration)
    {
        _logger = logger;
        _telemetryClient = telemetryClient;

        _environment = configuration["ENVIRONMENT"] ?? "prod";

        _sqlConnectionString = configuration["SQL_CONNECTION_STRING"]
            ?? throw new Exception("SQL_CONNECTION_STRING missing from config");

        _deviceProvisioningGlobalEndpoint = configuration["DEVICE_PROVISIONING_GLOBAL_ENDPOINT"]
            ?? throw new Exception("DEVICE_PROVISIONING_GLOBAL_ENDPOINT missing from config");
        _deviceProvisioningIdScope = configuration["DEVICE_PROVISIONING_ID_SCOPE"]
            ?? throw new Exception("DEVICE_PROVISIONING_ID_SCOPE missing from config");
        _deviceProvisioningPrimaryKey = configuration["DEVICE_PROVISIONING_PRIMARY_KEY"]
            ?? throw new Exception("DEVICE_PROVISIONING_PRIMARY_KEY missing from config");

        _iotHubHostName = configuration["IOT_HUB_HOST_NAME"]
            ?? throw new Exception("IOT_HUB_HOST_NAME missing from config");

        _simulatedDeviceCount = configuration.GetValue<int>("SIMULATED_DEVICE_COUNT");
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Worker starting");

        var devicesToRun = _simulatedDeviceCount;

        var tasks = new List<Task>();
        for (var i = 0; i < devicesToRun; i++)
        {
            tasks.Add(Task.Factory.StartNew(() => RunSimulatedDeviceAsync(stoppingToken), TaskCreationOptions.LongRunning));
        }

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch
        {
        }

        _logger.LogInformation("Worker stopping");
        await Task.WhenAll(tasks);
    }

    private async Task RunSimulatedDeviceAsync(CancellationToken stoppingToken)
    {
        var deviceId = Guid.NewGuid();
        var startDelay = Random.Shared.Next(1, 10);
        _logger.LogInformation("Device {DeviceId} starting, waiting {StartDelay} second(s) to start", deviceId, startDelay);

        await Task.Delay(TimeSpan.FromSeconds(startDelay), stoppingToken);

        var route = LoadRandomRoute();
        _logger.LogInformation("Route loaded with {PointCount} points", route.Length);

        /*
         * 1. Self-provision through DPS
         * 2. Register device in database
         * 3. Wait a random amount of time before starting
         * 4. Tick
         * 5. Send event
         * 6. Repeat 4-5
         */

        var device = new SimulatedDevice(route);

        var dpsDeviceKey = DeviceProvisioningKey.CreateFromEnrollmentGroupKey(
            _deviceProvisioningPrimaryKey,
            deviceId);
        await ProvisionAsync(dpsDeviceKey);
        await AddDeviceToDatabaseAsync(deviceId);

        using var deviceClient = DeviceClient.Create(
            _iotHubHostName,
            new DeviceAuthenticationWithRegistrySymmetricKey(
                deviceId.ToString(),
                dpsDeviceKey.GetPrimaryKey()));

        var twin = await deviceClient.GetTwinAsync(stoppingToken);
        int eventIntervalMillis = twin.Properties.Desired.Contains("eventIntervalMillis")
            ? (int)twin.Properties.Desired["eventIntervalMillis"]
            : DefaultEventIntervalMillis;
        int speedKilometersPerHour = twin.Properties.Desired.Contains("speedKilometersPerHour")
            ? (int)twin.Properties.Desired["speedKilometersPerHour"]
            : DefaultSpeedKilometersPerHour;
        device.SetSpeed(speedKilometersPerHour);

        await deviceClient.UpdateReportedPropertiesAsync(new TwinCollection(JsonSerializer.Serialize(new
        {
            eventIntervalMillis,
            speedKilometersPerHour,
        })), stoppingToken);

        await deviceClient.SetDesiredPropertyUpdateCallbackAsync(async (desiredProperties, _) =>
        {
            eventIntervalMillis = desiredProperties.Contains("eventIntervalMillis")
                ? (int)desiredProperties["eventIntervalMillis"]
                : DefaultEventIntervalMillis;
            int updatedSpeedKilometersPerHour = desiredProperties.Contains("speedKilometersPerHour")
                ? (int)desiredProperties["speedKilometersPerHour"]
                : DefaultSpeedKilometersPerHour;
            device.SetSpeed(updatedSpeedKilometersPerHour);

            await deviceClient.UpdateReportedPropertiesAsync(new TwinCollection(JsonSerializer.Serialize(new
            {
                eventIntervalMillis,
                speedKilometersPerHour = updatedSpeedKilometersPerHour,
            })), stoppingToken);
        }, null, stoppingToken);

        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                device.Tick();
                var longitude = device.Coordinate!.X;
                var latitude = device.Coordinate!.Y;

                var request = new RequestTelemetry
                {
                    Name = "Location update",
                    Properties =
                    {
                        { "DeviceId", deviceId.ToString() },
                        { "Environment", _environment },
                    },
                };

                using (var operation = _telemetryClient.StartOperation(request))
                {
                    await SendEventAsync(deviceClient, deviceId, longitude, latitude, stoppingToken);
                    operation.Telemetry.Success = true;
                }

                await Task.Delay(eventIntervalMillis, stoppingToken);
            }
        }
        finally
        {
            await deviceClient.SetDesiredPropertyUpdateCallbackAsync(null, null, CancellationToken.None);
            _logger.LogInformation("Device {DeviceId} stopping", deviceId);
        }

    }

    private async Task ProvisionAsync(SecurityProviderSymmetricKey dpsDeviceKey)
    {
        using var transport = new ProvisioningTransportHandlerAmqp();
        var deviceClient = ProvisioningDeviceClient.Create(
            _deviceProvisioningGlobalEndpoint,
            _deviceProvisioningIdScope,
            dpsDeviceKey,
            transport);
        await deviceClient.RegisterAsync();
    }

    private async Task AddDeviceToDatabaseAsync(Guid deviceId)
    {
        // TODO: We might be able to get an event in Functions for a device being
        // added. Could add the device to DB from there.
        _logger.LogInformation("Creating device {DeviceId}", deviceId);

        using var conn = new SqlConnection(_sqlConnectionString);
        await conn.ExecuteAsync(
            "INSERT INTO [dbo].[LocationTrackers] ([Id], [CreatedAt]) VALUES (@id, SYSUTCDATETIME())",
            new
            {
                id = deviceId
            });
    }

    private static Task SendEventAsync(
        DeviceClient deviceClient,
        Guid deviceId,
        double longitude,
        double latitude,
        CancellationToken cancellationToken)
    {
        return deviceClient.SendEventAsync(new Message(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new LocationUpdateEvent
        {
            Id = deviceId,
            Lng = longitude,
            Lat = latitude,
            Ts = DateTime.UtcNow,
        }))), cancellationToken);
    }

    private static Coordinate[] LoadRandomRoute()
    {
        var routesPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Data/routes.json");

        using var stream = File.OpenRead(routesPath);

        var serializerOptions = new JsonSerializerOptions();
        serializerOptions.Converters.Add(new GeoJsonConverterFactory());

        var featureCollection = JsonSerializer.Deserialize<FeatureCollection>(stream, serializerOptions);
        if (featureCollection == null)
        {
            throw new Exception("Failed to deserialize routes");
        }

        var routeIndex = Random.Shared.Next(featureCollection.Count);
        var route = (LineString)featureCollection[routeIndex].Geometry;
        return route.Coordinates;
    }
}
