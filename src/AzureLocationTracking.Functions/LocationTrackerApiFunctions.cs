using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Functions.Models;
using AzureLocationTracking.Functions.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using System.Net;

namespace AzureLocationTracking.Functions;

public class LocationTrackerApiFunctions
{
    private readonly LocationTrackerRepository _locationTrackerRepository;
    private readonly IotHubDeviceTwinService _iotHubDeviceTwinService;
    private readonly DataExplorerRepository _dataExplorerRepository;
    private readonly RequestAuthorizer _requestAuthorizer;

    public LocationTrackerApiFunctions(
        LocationTrackerRepository locationTrackerRepository,
        IotHubDeviceTwinService iotHubDeviceTwinService,
        DataExplorerRepository dataExplorerRepository,
        RequestAuthorizer requestAuthorizer)
    {
        _locationTrackerRepository = locationTrackerRepository;
        _iotHubDeviceTwinService = iotHubDeviceTwinService;
        _dataExplorerRepository = dataExplorerRepository;
        _requestAuthorizer = requestAuthorizer;
    }

    [Function(nameof(GetGeofenceEvents))]
    public async Task<HttpResponseData> GetGeofenceEvents(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/trackers/{trackerId}/geofenceEvents")] HttpRequestData req,
        Guid trackerId)
    {
        await _locationTrackerRepository.OpenConnectionAsync();

        var geofenceEvents = await _locationTrackerRepository.GetLatestGeofenceEvents(trackerId);

        var res = req.CreateResponse(HttpStatusCode.OK);
        await res.WriteAsJsonAsync(geofenceEvents.Select(x =>
            new Models.GeofenceEvent(x.GeofenceId, x.EntryTimestamp, x.ExitTimestamp)));
        return res;
    }

    [Function(nameof(UpdateParameters))]
    public async Task<HttpResponseData> UpdateParameters(
        [HttpTrigger(AuthorizationLevel.Anonymous, "put", Route = "api/trackers/{trackerId}/parameters")] HttpRequestData req,
        Guid trackerId)
    {
        if (!await _requestAuthorizer.AuthorizeRequestAsync(req))
        {
            return req.CreateResponse(HttpStatusCode.Unauthorized);
        }

        var parametersDto = await req.ReadFromJsonAsync<TrackerParametersDto>();

        await _iotHubDeviceTwinService.UpdateTwinPropertiesAsync(
            trackerId, parametersDto.SpeedKilometersPerHour, parametersDto.EventIntervalMillis);

        return req.CreateResponse(HttpStatusCode.NoContent);
    }

    [Function(nameof(GetPastLocations))]
    public async Task<HttpResponseData> GetPastLocations(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/trackers/{trackerId}/pastLocations")] HttpRequestData req,
        Guid trackerId)
    {
        var results = await _dataExplorerRepository.GetTrackerRecentPastLocationsAsync(trackerId);

        var res = req.CreateResponse(HttpStatusCode.OK);
        await res.WriteAsJsonAsync(results);
        return res;
    }
}
