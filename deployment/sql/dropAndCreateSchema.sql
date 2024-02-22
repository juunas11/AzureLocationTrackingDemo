IF OBJECT_ID('[dbo].[LocationTrackersInGeofences]', 'U') IS NOT NULL
DROP TABLE [dbo].[LocationTrackersInGeofences]
GO

IF OBJECT_ID('[dbo].[LocationTrackers]', 'U') IS NOT NULL
DROP TABLE [dbo].[LocationTrackers]
GO

IF OBJECT_ID('[dbo].[Geofences]', 'U') IS NOT NULL
DROP TABLE [dbo].[Geofences]
GO

CREATE TABLE [dbo].[LocationTrackers]
(
    [Id] UNIQUEIDENTIFIER NOT NULL,
    [CreatedAt] DATETIME2 NOT NULL,
    [LatestLocation] GEOGRAPHY NULL,
    CONSTRAINT PK_LocationTrackers PRIMARY KEY CLUSTERED ([Id])
);
GO

CREATE SPATIAL INDEX [IDX_LocationTracker_LatestLocation]
   ON [dbo].[LocationTrackers] ([LatestLocation]);
GO

CREATE TABLE [dbo].[Geofences]
(
    [Id] INT NOT NULL IDENTITY(1, 1),
    [Border] GEOGRAPHY NOT NULL,
    CONSTRAINT PK_Geofences PRIMARY KEY CLUSTERED ([Id])
);
GO

CREATE SPATIAL INDEX [IDX_Geofence_Border]
   ON [dbo].[Geofences] ([Border]);
GO

CREATE TABLE [dbo].[LocationTrackersInGeofences]
(
    [Id] INT NOT NULL IDENTITY(1, 1),
    [LocationTrackerId] UNIQUEIDENTIFIER NOT NULL,
    [GeofenceId] INT NOT NULL,
    [EntryTimestamp] DATETIME2 NOT NULL,
    [ExitTimestamp] DATETIME2 NULL,
    CONSTRAINT PK_LocationTrackersInGeofences PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT FK_LocationTrackersInGeofences_LocationTracker FOREIGN KEY ([LocationTrackerId])
        REFERENCES [dbo].[LocationTrackers] ([Id])
        ON DELETE CASCADE
        ON UPDATE NO ACTION,
    CONSTRAINT FK_LocationTrackersInGeofences_Geofence FOREIGN KEY ([GeofenceId])
        REFERENCES [dbo].[Geofences] ([Id])
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
GO