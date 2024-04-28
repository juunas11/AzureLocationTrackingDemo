using Kusto.Data.Net.Client;
using Kusto.Data;
using AzureLocationTracking.Functions.Models;
using Microsoft.Extensions.Configuration;
using Azure.Core;

namespace AzureLocationTracking.Functions.Data;

public class DataExplorerRepository
{
    private readonly string _adxClusterUri;
    private readonly string _adxDbName;
    private readonly TokenCredential _tokenCredential;

    public DataExplorerRepository(
        IConfiguration configuration,
        TokenCredential tokenCredential)
    {
        _adxClusterUri = configuration["AdxClusterUri"];
        _adxDbName = configuration["AdxDbName"];
        _tokenCredential = tokenCredential;
    }

    public async Task<List<PastLocationDto>> GetVehicleRecentPastLocationsAsync(
        Guid vehicleId)
    {
        var connectionStringBuilder = new KustoConnectionStringBuilder(_adxClusterUri, _adxDbName)
            .WithAadAzureTokenCredentialsAuthentication(_tokenCredential);
        connectionStringBuilder.FederatedSecurity = true;
        using var client = KustoClientFactory.CreateCslQueryProvider(connectionStringBuilder);

        var adxQuery = $@"locations
| where DeviceId == '{vehicleId}'
| where Timestamp > ago(10m)
| order by Timestamp desc
| project Longitude, Latitude, Timestamp
| take 20";

        using var reader = await client.ExecuteQueryAsync(_adxDbName, adxQuery, new Kusto.Data.Common.ClientRequestProperties());

        var results = new List<PastLocationDto>();

        while (reader.Read())
        {
            var longitude = reader.GetDouble(0);
            var latitude = reader.GetDouble(1);
            var timestamp = reader.GetDateTime(2);

            results.Add(new PastLocationDto
            {
                Latitude = latitude,
                Longitude = longitude,
                Timestamp = timestamp.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'"),
            });
        }

        return results;
    }
}
