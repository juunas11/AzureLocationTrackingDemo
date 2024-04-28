using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Functions.GeoJson;
using GeoJSON.Net.Feature;
using GeoJSON.Net.Geometry;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Newtonsoft.Json;
using System.Net;

namespace AzureLocationTracking.Functions;

public class GeofenceApiFunctions
{
    private readonly GeofenceRepository _geofenceRepository;

    public GeofenceApiFunctions(
        GeofenceRepository geofenceRepository)
    {
        _geofenceRepository = geofenceRepository;
    }

    [Function(nameof(GetGeofences))]
    public async Task<HttpResponseData> GetGeofences(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "api/geofences")] HttpRequestData req)
    {
        await _geofenceRepository.OpenConnectionAsync();

        var geofences = await _geofenceRepository.GetGeofencesAsync();

        var featureCollection = new FeatureCollection();

        foreach (var geofence in geofences)
        {
            var polygon = geofence.Border.ToGeoJSONObject<Polygon>();
            var center = geofence.Border.EnvelopeCenter();
            var feature = new Feature(polygon, id: geofence.Id.ToString(), properties: new Dictionary<string, object>
            {
                // GeoJSON uses longitude, latitude order.
                ["center"] = new[] { center.Long.Value, center.Lat.Value },
                ["name"] = geofence.Name ?? ""
            });
            featureCollection.Features.Add(feature);
        }

        // The library used for GeoJSON does not support System.Text.Json,
        // so we use JSON.NET to serialize it and return the string.
        var featureCollectionJson = JsonConvert.SerializeObject(featureCollection);
        var res = req.CreateResponse(HttpStatusCode.OK);
        res.Headers.Add("Content-Type", "application/json; charset=utf-8");
        await res.WriteStringAsync(featureCollectionJson);
        return res;
    }
}
