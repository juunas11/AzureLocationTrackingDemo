using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Functions.Models;
using AzureLocationTracking.Functions.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net;

namespace AzureLocationTracking.Functions;

public class VehicleApiFunctions
{
    private readonly VehicleRepository _vehicleRepository;
    private readonly IotHubDeviceTwinService _iotHubDeviceTwinService;
    private readonly DataExplorerRepository _dataExplorerRepository;
    private readonly RequestAuthorizer _requestAuthorizer;

    public VehicleApiFunctions(
        VehicleRepository vehicleRepository,
        IotHubDeviceTwinService iotHubDeviceTwinService,
        DataExplorerRepository dataExplorerRepository,
        RequestAuthorizer requestAuthorizer)
    {
        _vehicleRepository = vehicleRepository;
        _iotHubDeviceTwinService = iotHubDeviceTwinService;
        _dataExplorerRepository = dataExplorerRepository;
        _requestAuthorizer = requestAuthorizer;
    }

    [Function(nameof(GetGeofenceEvents))]
    public async Task<HttpResponseData> GetGeofenceEvents(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/vehicles/{vehicleId}/geofenceEvents")] HttpRequestData req,
        Guid vehicleId)
    {
        await _vehicleRepository.OpenConnectionAsync();

        var geofenceEvents = await _vehicleRepository.GetLatestGeofenceEvents(vehicleId);

        var res = req.CreateResponse(HttpStatusCode.OK);
        await res.WriteAsJsonAsync(geofenceEvents.Select(x =>
            new Models.GeofenceEvent(x.GeofenceId, x.EntryTimestamp, x.ExitTimestamp)));
        return res;
    }

    [Function(nameof(UpdateParameters))]
    public async Task<HttpResponseData> UpdateParameters(
        [HttpTrigger(AuthorizationLevel.Anonymous, "put", Route = "api/vehicles/{vehicleId}/parameters")] HttpRequestData req,
        Guid vehicleId)
    {
        if (!await _requestAuthorizer.AuthorizeRequestAsync(req))
        {
            return req.CreateResponse(HttpStatusCode.Unauthorized);
        }

        var parametersDto = await req.ReadFromJsonAsync<VehicleParametersDto>();

        await _iotHubDeviceTwinService.UpdateTwinPropertiesAsync(
            vehicleId, parametersDto.SpeedKilometersPerHour, parametersDto.EventIntervalMillis);

        return req.CreateResponse(HttpStatusCode.NoContent);
    }

    [Function(nameof(GetPastLocations))]
    public async Task<HttpResponseData> GetPastLocations(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/vehicles/{vehicleId}/pastLocations")] HttpRequestData req,
        Guid vehicleId)
    {
        var results = await _dataExplorerRepository.GetVehicleRecentPastLocationsAsync(vehicleId);

        var res = req.CreateResponse(HttpStatusCode.OK);
        await res.WriteAsJsonAsync(results);
        return res;
    }
}
