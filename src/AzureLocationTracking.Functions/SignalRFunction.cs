using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace AzureLocationTracking.Functions;
public class SignalRFunction
{
    private const int MaxGridNumbersPerConnection = 50;

    [Function("SignalRNegotiate")]
    public string Negotiate(
        [HttpTrigger(AuthorizationLevel.Anonymous, Route = "api/signalr/negotiate")] HttpRequestData req,
        [SignalRConnectionInfoInput(HubName = "%AzureSignalRHubName%", ConnectionStringSetting = "AzureSignalRConnectionString")] string connectionInfo)
    {
        return connectionInfo;
    }

    [Function(nameof(UpdateMapGridGroups))]
    [SignalROutput(HubName = "%AzureSignalRHubName%", ConnectionStringSetting = "AzureSignalRConnectionString")]
    public List<SignalRGroupAction> UpdateMapGridGroups(
        [SignalRTrigger("%AzureSignalRHubName%", "messages", "updateMapGridGroups", "newGridNumbers", "previousGridNumbers", ConnectionStringSetting = "AzureSignalRConnectionString")] SignalRInvocationContext invocationContext,
        int[][] newGridNumbers,
        int[][] previousGridNumbers,
        FunctionContext functionContext)
    {
        var logger = functionContext.GetLogger<SignalRFunction>();
        if (newGridNumbers.Length > MaxGridNumbersPerConnection)
        {
            logger.LogInformation(
                "Too many grid numbers, removing all groups from connection ID: {ConnectionId}",
                invocationContext.ConnectionId);
            return new List<SignalRGroupAction>
            {
                new SignalRGroupAction(SignalRGroupActionType.RemoveAll)
                {
                    ConnectionId = invocationContext.ConnectionId,
                },
            };
        }

        var groupActions = new List<SignalRGroupAction>();
        var previousGroups = previousGridNumbers.Select(GetGroupName).ToHashSet();
        var newGroups = newGridNumbers.Select(GetGroupName).ToHashSet();

        var groupsToRemove = previousGroups.Where(g => !newGroups.Contains(g)).ToList();
        foreach (var groupName in groupsToRemove)
        {
            logger.LogDebug(
                "Removing connection ID {ConnectionId} from group {GroupName}",
                invocationContext.ConnectionId, groupName);
            groupActions.Add(new SignalRGroupAction(SignalRGroupActionType.Remove)
            {
                ConnectionId = invocationContext.ConnectionId,
                GroupName = groupName,
            });
        }

        var groupsToAdd = newGroups.Where(g => !previousGroups.Contains(g)).ToList();
        foreach (var groupName in groupsToAdd)
        {
            logger.LogDebug(
                "Assigning connection ID {ConnectionId} to group {GroupName}",
                invocationContext.ConnectionId, groupName);
            groupActions.Add(new SignalRGroupAction(SignalRGroupActionType.Add)
            {
                ConnectionId = invocationContext.ConnectionId,
                GroupName = groupName,
            });
        }

        return groupActions;
    }

    private static string GetGroupName(int[] gridNumber)
    {
        var longitudeNumber = NormalizeLongitude(gridNumber[0]);
        var latitudeNumber = NormalizeLatitude(gridNumber[1]);

        var groupName = $"grid:{longitudeNumber}:{latitudeNumber}";
        return groupName;
    }

    private static int NormalizeLongitude(int longitude)
    {
        while (longitude < -180)
        {
            longitude += 360;
        }

        while (longitude > 180)
        {
            longitude -= 360;
        }

        return longitude;
    }

    private static int NormalizeLatitude(int latitude)
    {
        while (latitude < -90)
        {
            latitude += 180;
        }

        while (latitude > 90)
        {
            latitude -= 180;
        }

        return latitude;
    }
}
