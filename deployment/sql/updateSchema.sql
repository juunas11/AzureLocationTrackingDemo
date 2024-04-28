IF OBJECT_ID('[dbo].[Vehicles]', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Vehicles]
    (
        [Id] UNIQUEIDENTIFIER NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL,
        [LatestLocation] GEOGRAPHY NULL,
        CONSTRAINT PK_Vehicles PRIMARY KEY CLUSTERED ([Id])
    );

    CREATE SPATIAL INDEX [IDX_Vehicle_LatestLocation]
    ON [dbo].[Vehicles] ([LatestLocation]);
END

IF OBJECT_ID('[dbo].[Geofences]', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Geofences]
    (
        [Id] INT NOT NULL IDENTITY(1, 1),
        [Border] GEOGRAPHY NOT NULL,
        [Name] NVARCHAR(256) NOT NULL,
        CONSTRAINT PK_Geofences PRIMARY KEY CLUSTERED ([Id])
    );

    CREATE SPATIAL INDEX [IDX_Geofence_Border]
    ON [dbo].[Geofences] ([Border]);
END

IF OBJECT_ID('[dbo].[VehiclesInGeofences]', 'U') IS NULL
CREATE TABLE [dbo].[VehiclesInGeofences]
(
    [Id] INT NOT NULL IDENTITY(1, 1),
    [VehicleId] UNIQUEIDENTIFIER NOT NULL,
    [GeofenceId] INT NOT NULL,
    [EntryTimestamp] DATETIME2 NOT NULL,
    [ExitTimestamp] DATETIME2 NULL,
    CONSTRAINT PK_VehiclesInGeofences PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT FK_VehiclesInGeofences_Vehicle FOREIGN KEY ([VehicleId])
        REFERENCES [dbo].[Vehicles] ([Id])
        ON DELETE CASCADE
        ON UPDATE NO ACTION,
    CONSTRAINT FK_VehiclesInGeofences_Geofence FOREIGN KEY ([GeofenceId])
        REFERENCES [dbo].[Geofences] ([Id])
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
GO