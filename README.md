# Azure Location Tracking Demo application

This sample application implements a data pipeline from IoT devices to a Vue front-end.
Azure services used:

- IoT Hub
- Device Provisioning Service
- Event Hub
- Azure Data Explorer
- Function App
- SignalR Service
- Azure Maps
- Cosmos DB
- Container App
- Container Registry
- Application Insights
- Log Analytics

## Deploying the demo

Prerequisites:

- Resource group in an Azure subscription, your user must have Owner role in the resource group
  - The script does create the resource group if it does not exist, but then you need Owner role on the subscription
- At least Application Developer role in Entra ID (Azure AD) tenant
  - This can be a different tenant from the one where resources are deployed to
- Docker (script uses docker CLI)
- Azure CLI
  - azure-iot extension
- PowerShell
  - Microsoft.Graph module
  - SqlServer module
- Node.js (tested with 20.11.1)

To deploy the application in your own Azure subscription, first rename _deployment/config.sample.json_ to _deployment/config.json_.
Then fill in at least these settings:

- tenantId
  - Entra ID (Azure AD) tenant ID where the Azure subscription is
- subscriptionId
  - Azure subscription where resources will be deployed to
- resourceGroup
  - Resource group where resources will be deployed to
- location
  - Azure region where resources will be deployed to (e.g. westeurope)
- developerUserId
  - Your user object ID in the Entra ID (Azure AD) tenant where resources are deployed to
  - Used to assign container registry push, Cosmos read/write, Maps reader, ADX admin, and IotHub Twin contributor rights
- adApplicationTenantId
  - Entra ID (Azure AD) tenant ID where an app registration is setup for the Function App
  - This app registration enables logging in to the front-end; logged in users can modify device parameters
  - This can be a different tenant from the one where resources are
- adApplicationUri
  - Identifier URI for the app registration, used to match to existing registration when running script again
  - Typically something like: `https://mytenant.onmicrosoft.com/AzureLocationTrackingDemo`

You can also change the default settings for the SignalR hub names and DPS enrolmment group names, but you can leave those at defaults.

Now that we have finished configuration, you can run the script:

```powershell
.\deployment\Deploy.ps1
```

Running the script for the first time can take at least 15 minutes.

**Note that you must run the script twice to get everything deployed.**
This only applies for the first run.
If you make changes and want to redeploy, just run the deployment script again.

## Running the demo

The deployment script will output the Function App URL.
Open the URL in a browser and you should see the map.
By default, the map will be centered on hard-coded coordinates.
The deployment script will also seed one or more geofences that you should be able to see on the map.

The Container App is setup with a 0-1 scale rule by default, which should mean it runs one replica for a while after creation and then scales to zero.
To run simulators and cause vehicles to appear on the map, scale up to at least 1 replica.

You can also log in, and this allows you to modify the speed and location update interval of a vehicle.

The deployment script also creates an Azure dashboard that you can check to see statistics for the demo.

## Running locally

Prerequisites:

- Run the deployment script
- Azurite
- Ngrok
- [Cosmos DB emulator](https://learn.microsoft.com/en-us/azure/cosmos-db/emulator)
- Ability to run .NET Azure Functions (.NET 8)
- Node.js (tested with 20.11.1)

From the deployment script outputs, you should get the necessary user secrets to configure and run both .NET applications:

- AzureLocationTracking.Functions
  - Function App that hosts the front-end and acts as its back-end, also processes Event Hub messages
- AzureLocationTracking.VehicleSimulator
  - Device simulator that sends events to IoT Hub, which then get forwarded to the Function App

The output uses the default URI and key for Cosmos DB emulator.
Change those if needed for your environment.

You will also need to run:

```powershell
.\deployment\SetupLocalFrontend.ps1
```

This sets up the Entra ID (Azure AD) identifiers as well as the Azure Maps client ID.

Then you can run scripts to start Azurite and Ngrok:

```powershell
.\deployment\RunAzurite.ps1
.\deployment\RunNgrok.ps1
```

You can of course run these tools separately as well, but note that the Ngrok script additionally sets up the necessary SignalR Service upstream URL so that SignalR messages from the front-end reach your back-end.

You can then run the front-end in `src\AzureLocationTracking.Frontend` with:

```powershell
npm install
npm run dev
```

There is an additional `AzureLocationTracking.SignalRReceiver` project that acts as a client,
you can use it to see the data that a front-end receives.

## How it works

In this demo application, the data flow starts from the Container App, which runs the vehicle simulator.
This simulator uses a set of predefined routes in `routes.json`, from which it selects one at random.
It starts "moving" from a random point on the route, at a speed of 50 km/h, reporting its latest location every 5 seconds.

In order to send data, the simulator first contacts Device Provisioning Service, from which it gets connection details to the IoT Hub.
It is also registered as a device in IoT Hub at this point.

The simulator subscribes to device twin updates from the IoT hub.
Through this, a logged in user is able to modify the speed and location update interval of a device.

The IoT Hub is setup to route all device messages to an Event Hub.
There are actually two Event Hubs, one for development and one for production.
The IoT Hub device twin for each device has an environment tag, that is used in routing rules.

The Event Hubs have three listeners: Azure Data Explorer, geofence update function, and location update function.
ADX writes all events to a table.
The geofence update function checks if the new location puts the vehicle inside a geofence it wasn't already in, and fires an event through SignalR for it.
The location update function updates the latest location for the vehicle in Cosmos DB and fires an event through SignalR.

The Vue front-end's files are deployed inside the Function App and it returns the index.html file when you hit the root of the Function App.
The front-end then connects to the Function App for a SignalR connection, which gets forwarded to SignalR Service.
Since we are running SignalR Service in Serverless mode, any messages from the front-end back to the Function App get sent through a Webhook (called an "upstream" in SignalR Service).

The front-end is not interested in location update events that happen in an area of the map the user is not looking at.
This is mostly a performance optimization.
To achieve this, when the app loads and whenever the map is moved, we figure out which "grid squares" are visible in the map.
Example grid square: `[24, 60]`.
This defines a "square" (area on a spheroid) that includes all coordinates where the full degrees are 24 (longitude), 60 (latitude).
A SignalR group is created for each grid square and the connection is added to them.
If the user moves the map and the visible squares change, the group memberships are also updated.

If the user zooms out the map to the point where more than 50 grid squares are visible, we remove all of their memberships and do not add them to any of them.
This is also a performance optimization so that the user would not receive too many updates.

Now when the Function App gets location updates, we only send SignalR events to the relevant grid square's group.
Conveniently we can just round down both the latitude and longitude to get the grid square.

## Cleaning up resources

To clean up Azure resources, delete the resource group.
In addition, you can remove the app registration from the Entra ID (Azure AD) tenant.
