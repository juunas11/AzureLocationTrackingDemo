using AzureLocationTracking.Functions.Data;
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
        static Polygon ToGeoJson(Microsoft.Azure.Cosmos.Spatial.Polygon polygon)
        {
            // All our geofences have a single ring.
            var ring = polygon.Rings.Single();
            var positions = ring.Positions.Select(p => new Position(latitude: p.Latitude, longitude: p.Longitude)).ToList();
            return new Polygon(new List<LineString> { new(positions) });
        }

        static Position GetCenter(Polygon polygon)
        {
            var coords = polygon.Coordinates.Single().Coordinates;
            var minLat = coords.Min(p => p.Latitude);
            var minLng = coords.Min(p => p.Longitude);
            var maxLat = coords.Max(p => p.Latitude);
            var maxLng = coords.Max(p => p.Longitude);
            return new Position(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2);
        }

        var geofences = await _geofenceRepository.GetGeofencesAsync();

        var featureCollection = new FeatureCollection();

        foreach (var geofence in geofences)
        {
            var polygon = ToGeoJson(geofence.Border);
            var center = GetCenter(polygon);
            var feature = new Feature(polygon, id: geofence.Id, properties: new Dictionary<string, object>
            {
                // GeoJSON uses longitude, latitude order.
                ["center"] = new[] { center.Longitude, center.Latitude },
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
