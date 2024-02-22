using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.SqlServer.Types;
using System.Data.Common;

namespace AzureLocationTracking.Functions.Data;
public class LocationTrackerRepository : RepositoryBase
{
    public LocationTrackerRepository(IConfiguration configuration)
        : base(configuration)
    {
    }

    public async Task UpdateLatestLocationAsync(
        Guid trackerId,
        SqlGeography location,
        DbTransaction transaction)
    {
        await SqlConnection.ExecuteAsync(
            @"UPDATE [dbo].[LocationTrackers]
              SET [LatestLocation] = @location
              WHERE [Id] = @id",
            new
            {
                id = trackerId,
                location,
            },
            transaction);
    }

    public async Task<IEnumerable<GeofenceEventDto>> GetLatestGeofenceEvents(Guid trackerId)
    {
        var geofenceEvents = await SqlConnection.QueryAsync<GeofenceEventDto>(
            @"SELECT TOP 5 [GeofenceId], [EntryTimestamp], [ExitTimestamp]
              FROM [dbo].[LocationTrackersInGeofences]
              WHERE [LocationTrackerId] = @trackerId
              ORDER BY [EntryTimestamp] DESC",
            new
            {
                trackerId,
            });
        return geofenceEvents;
    }
}
