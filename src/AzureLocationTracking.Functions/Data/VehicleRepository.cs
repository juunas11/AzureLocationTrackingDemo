using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.SqlServer.Types;
using System.Data.Common;

namespace AzureLocationTracking.Functions.Data;

public class VehicleRepository : RepositoryBase
{
    public VehicleRepository(IConfiguration configuration)
        : base(configuration)
    {
    }

    public async Task UpdateLatestLocationAsync(
        Guid vehicleId,
        SqlGeography location,
        DbTransaction transaction)
    {
        await SqlConnection.ExecuteAsync(
            @"UPDATE [dbo].[Vehicles]
              SET [LatestLocation] = @location
              WHERE [Id] = @id",
            new
            {
                id = vehicleId,
                location,
            },
            transaction);
    }

    public async Task<IEnumerable<GeofenceEventDto>> GetLatestGeofenceEvents(Guid vehicleId)
    {
        var geofenceEvents = await SqlConnection.QueryAsync<GeofenceEventDto>(
            @"SELECT TOP 5 [GeofenceId], [EntryTimestamp], [ExitTimestamp]
              FROM [dbo].[VehiclesInGeofences]
              WHERE [VehicleId] = @vehicleId
              ORDER BY [EntryTimestamp] DESC",
            new
            {
                vehicleId,
            });
        return geofenceEvents;
    }
}
