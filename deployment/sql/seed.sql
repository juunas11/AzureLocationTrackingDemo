IF NOT EXISTS (SELECT * FROM [dbo].[Geofences] WHERE [Name] = 'Techorama')
BEGIN
    INSERT INTO [dbo].[Geofences] ([Name], [Border])
    VALUES ('Techorama', geography::STPolyFromText('POLYGON ((4.4144759285703685 51.2465446750891,4.4144759285703685 51.244309103643985,4.419906638197489 51.244309103643985,4.419906638197489 51.2465446750891,4.4144759285703685 51.2465446750891))', 4326));
END

IF NOT EXISTS (SELECT * FROM [dbo].[Geofences] WHERE [Name] = 'Antwerp Central Station')
BEGIN
    INSERT INTO [dbo].[Geofences] ([Name], [Border])
    VALUES ('Antwerp Central Station', geography::STPolyFromText('POLYGON ((4.42040140348243 51.219294236719776,4.42040140348243 51.21781878418412,4.422073359769854 51.21781878418412,4.422073359769854 51.219294236719776,4.42040140348243 51.219294236719776))', 4326));
END