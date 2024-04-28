using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace AzureLocationTracking.CosmosInitializer;

internal class Program
{
    static async Task Main(string[] args)
    {
        if (args.Length < 3)
        {
            Console.WriteLine("Usage:");
            Console.WriteLine("local <endpoint> <key> <dbname> <vehiclecontainer> <geofencecontainer> <vehiclesingeofencescontainer>");
            Console.WriteLine("or");
            Console.WriteLine("azure <endpoint> <tenantid> <dbname> <geofencecontainer>");
            return;
        }

        var mode = args[0];
        var endpoint = args[1];
        var key = mode == "local" ? args[2] : null;
        var tenantId = mode == "azure" ? args[2] : null;

        // TODO: Validation

        using var client = mode == "azure"
            ? new CosmosClient(endpoint, new AzureCliCredential(new AzureCliCredentialOptions
            {
                TenantId = tenantId
            }))
            : new CosmosClient(endpoint, key);

        string dbName;
        string geofenceContainer;
        if (mode == "local")
        {
            dbName = args[3];
            var vehicleContainer = args[4];
            geofenceContainer = args[5];
            var vehiclesInGeofencesContainer = args[6];
            var db = await client.CreateDatabaseIfNotExistsAsync(dbName);
            await db.Database.CreateContainerIfNotExistsAsync(vehicleContainer, "/id", 400);
            await db.Database.CreateContainerIfNotExistsAsync(geofenceContainer, "/gridSquare", 400);
            await db.Database.CreateContainerIfNotExistsAsync(vehiclesInGeofencesContainer, "/vehicleId", 400);
        }
        else if (mode == "azure")
        {
            dbName = args[3];
            geofenceContainer = args[4];
        }
        else
        {
            return;
        }

        await CreateGeofencesAsync(client, dbName, geofenceContainer);
    }

    private static async Task CreateGeofencesAsync(CosmosClient client, string dbName, string containerName)
    {
        var container = client.GetContainer(dbName, containerName);

        await container.UpsertItemAsync(new
        {
            id = "1e478872-57e9-4068-a4f6-f894d386659d",
            gridSquare = "24,60",
            name = "Helsinki Station",
            border = new
            {
                type = "Polygon",
                coordinates = new double[][][]
                {
                    [
                        [24.9385729618134, 60.1711592172123],
                        [24.9385729618134, 60.1700121134021],
                        [24.9445582854212, 60.1700121134021],
                        [24.9445582854212, 60.1711592172123],
                        [24.9385729618134, 60.1711592172123]
                    ]
                }
            }
        }, new PartitionKey("24,60"));
    }
}
