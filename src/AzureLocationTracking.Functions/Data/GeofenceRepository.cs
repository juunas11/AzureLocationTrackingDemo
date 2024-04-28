using AzureLocationTracking.Functions.Models;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.SqlServer.Types;
using System.Data.Common;

namespace AzureLocationTracking.Functions.Data;

public class GeofenceRepository : RepositoryBase
{
    public GeofenceRepository(IConfiguration configuration)
        : base(configuration)
    {
    }

    public Task<IEnumerable<Geofence>> GetGeofencesAsync()
    {
        return SqlConnection.QueryAsync<Geofence>("SELECT [Id], [Border], [Name] FROM [dbo].[Geofences]");
    }

    public async Task<(int[] enteredGeofenceIds, int[] exitedGeofenceIds)> GetEnteredAndExitedGeofenceIdsAsync(
        Guid vehicleId,
        SqlGeography location,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        var reader = await SqlConnection.QueryMultipleAsync(
            @"SELECT [GeofenceId]
              FROM [dbo].[VehiclesInGeofences]
              WHERE [VehicleId] = @vehicleId AND [EntryTimestamp] < @eventTimestamp AND [ExitTimestamp] IS NULL;

              SELECT [Id]
              FROM [dbo].[Geofences]
              WHERE [Border].STContains(@location) = 1",
            new
            {
                vehicleId,
                eventTimestamp,
                location,
            },
            transaction);
        var currentGeofenceIdRows = await reader.ReadAsync();
        var currentGeofenceIds = currentGeofenceIdRows.Select(r => (int)r.GeofenceId).ToList();

        var collidingGeofenceIdRows = await reader.ReadAsync();
        var collidingGeofenceIds = collidingGeofenceIdRows.Select(r => (int)r.Id).ToList();

        var enteredGeofenceIds = collidingGeofenceIds.Except(currentGeofenceIds).ToArray();
        var exitedGeofenceIds = currentGeofenceIds.Except(collidingGeofenceIds).ToArray();

        return (enteredGeofenceIds, exitedGeofenceIds);
    }

    public async Task AddVehicleInGeofencesAsync(
        Guid vehicleId,
        int[] enteredGeofenceIds,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        if (enteredGeofenceIds.Length > 0)
        {
            await SqlConnection.ExecuteAsync(
                @"INSERT INTO [dbo].[VehiclesInGeofences] ([VehicleId], [GeofenceId], [EntryTimestamp])
                  VALUES (@vehicleId, @geofenceId, @eventTimestamp)",
                enteredGeofenceIds
                    .Select(id => new
                    {
                        vehicleId,
                        geofenceId = id,
                        eventTimestamp,
                    })
                    .ToArray(),
                transaction);
        }
    }

    public async Task SetVehicleOutOfGeofencesAsync(
        Guid vehicleId,
        int[] exitedGeofenceIds,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        if (exitedGeofenceIds.Length > 0)
        {
            await SqlConnection.ExecuteAsync(
                @"UPDATE [dbo].[VehiclesInGeofences]
                  SET [ExitTimestamp] = @eventTimestamp
                  WHERE [VehicleId] = @vehicleId AND [GeofenceId] IN @exitedGeofenceIds AND [ExitTimestamp] IS NULL",
                new
                {
                    eventTimestamp,
                    vehicleId,
                    exitedGeofenceIds,
                },
                transaction);
        }
    }
}
