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
        return SqlConnection.QueryAsync<Geofence>("SELECT [Id], [Border] FROM [dbo].[Geofences]");
    }

    public async Task<(int[] enteredGeofenceIds, int[] exitedGeofenceIds)> GetEnteredAndExitedGeofenceIdsAsync(
        Guid trackerId,
        SqlGeography location,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        var reader = await SqlConnection.QueryMultipleAsync(
            @"SELECT [GeofenceId]
              FROM [dbo].[LocationTrackersInGeofences]
              WHERE [LocationTrackerId] = @trackerId AND [EntryTimestamp] < @eventTimestamp AND [ExitTimestamp] IS NULL;

              SELECT [Id]
              FROM [dbo].[Geofences]
              WHERE [Border].STContains(@location) > 0",
            new
            {
                trackerId,
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

    public async Task AddLocationTrackerInGeofencesAsync(
        Guid trackerId,
        int[] enteredGeofenceIds,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        if (enteredGeofenceIds.Length > 0)
        {
            await SqlConnection.ExecuteAsync(
                @"INSERT INTO [dbo].[LocationTrackersInGeofences] ([LocationTrackerId], [GeofenceId], [EntryTimestamp])
                  VALUES (@trackerId, @geofenceId, @eventTimestamp)",
                enteredGeofenceIds
                    .Select(id => new
                    {
                        trackerId,
                        geofenceId = id,
                        eventTimestamp,
                    })
                    .ToArray(),
                transaction);
        }
    }

    public async Task SetLocationTrackerOutOfGeofencesAsync(
        Guid trackerId,
        int[] exitedGeofenceIds,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        if (exitedGeofenceIds.Length > 0)
        {
            await SqlConnection.ExecuteAsync(
                @"UPDATE [dbo].[LocationTrackersInGeofences]
                  SET [ExitTimestamp] = @eventTimestamp
                  WHERE [LocationTrackerId] = @trackerId AND [GeofenceId] IN @exitedGeofenceIds AND [ExitTimestamp] IS NULL",
                new
                {
                    eventTimestamp,
                    trackerId,
                    exitedGeofenceIds,
                },
                transaction);
        }
    }
}
