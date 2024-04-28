using NetTopologySuite.Geometries;

namespace AzureLocationTracking.VehicleSimulator;
internal class SimulatedDevice
{
    private readonly Coordinate[] _coordinates;
    private readonly double[] _distances;
    private int _currentPointIndex;
    private double _distanceTraveledFromCurrentPoint;
    private DateTime _lastTickTime;
    private double _speedMetersPerSecond;

    public SimulatedDevice(Coordinate[] coordinates)
    {
        _coordinates = coordinates;
        _distances = GetDistancesBetweenCoordinates(coordinates);
        // Start at random point on the line
        _currentPointIndex = Random.Shared.Next(coordinates.Length);
        _distanceTraveledFromCurrentPoint = 0;
        _lastTickTime = DateTime.UtcNow;
        _speedMetersPerSecond = 0;
    }

    public Coordinate? Coordinate { get; private set; }

    public void SetSpeed(int kilometersPerHour)
    {
        // Convert to meters per second
        _speedMetersPerSecond = kilometersPerHour / 3.6;
    }

    public void Tick()
    {
        var now = DateTime.UtcNow;
        var deltaSeconds = (now - _lastTickTime).TotalSeconds;

        var deltaDistance = _speedMetersPerSecond * deltaSeconds;

        var (newCoordinateIndex, distanceFromCoordinate) = GetNewCoordinate(deltaDistance);
        _currentPointIndex = newCoordinateIndex;
        _distanceTraveledFromCurrentPoint = distanceFromCoordinate;
        _lastTickTime = now;

        var newCoordinate = _coordinates[newCoordinateIndex];
        var nextCoordinate = _coordinates[(newCoordinateIndex + 1) % _coordinates.Length];
        var distanceFromCoordinateRatio = distanceFromCoordinate / _distances[_currentPointIndex];

        Coordinate = GetIntermediateCoordinate(newCoordinate, nextCoordinate, distanceFromCoordinateRatio);
    }

    private (int newCoordinateIndex, double distanceFromCoordinate) GetNewCoordinate(double deltaDistance)
    {
        var pointIndex = _currentPointIndex;
        var distanceFromCurrentPoint = _distanceTraveledFromCurrentPoint + deltaDistance;

        while (_distances[pointIndex] < distanceFromCurrentPoint)
        {
            distanceFromCurrentPoint -= _distances[pointIndex];
            pointIndex = (pointIndex + 1) % _coordinates.Length;
        }

        return (pointIndex, distanceFromCurrentPoint);
    }

    /// <summary>
    /// Interpolate a point between two coordinates based on the distance traveled.
    /// </summary>
    private static Coordinate GetIntermediateCoordinate(Coordinate pointA, Coordinate pointB, double distanceTraveledRatio)
    {
        var latitude1 = pointA.Y;
        var longitude1 = pointA.X;
        var latitude2 = pointB.Y;
        var longitude2 = pointB.X;

        var latitude = latitude1 + ((latitude2 - latitude1) * distanceTraveledRatio);
        var longitude = longitude1 + ((longitude2 - longitude1) * distanceTraveledRatio);
        return new Coordinate(longitude, latitude);
    }

    /// <summary>
    /// Create array of distances between each point in the coordinates array.
    /// Value at index 0 will be the distance between coordinates[0] and coordinates[1],
    /// and so forth.
    /// The final value will be the distance between coordinates[coordinates.Length - 1]
    /// and coordinates[0].
    /// </summary>
    private static double[] GetDistancesBetweenCoordinates(Coordinate[] coordinates)
    {
        var distances = new double[coordinates.Length];

        for (var i = 0; i < coordinates.Length - 1; i++)
        {
            var pointA = coordinates[i];
            var pointB = coordinates[i + 1];

            distances[i] = CalculateDistance(pointA, pointB);
        }

        distances[coordinates.Length - 1] = CalculateDistance(
            coordinates[coordinates.Length - 1],
            coordinates[0]);

        return distances;
    }

    /// <summary>
    /// Calculate the distance between two points on the earth's surface.
    /// </summary>
    private static double CalculateDistance(Coordinate pointA, Coordinate pointB)
    {
        // Haversine formula

        const double r = 6371_000; // Average radius of the earth in meters

        var latitude1 = pointA.Y;
        var longitude1 = pointA.X;
        var latitude2 = pointB.Y;
        var longitude2 = pointB.X;

        var phi1 = latitude1.ToRadians();
        var phi2 = latitude2.ToRadians();

        var deltaPhi = (latitude2 - latitude1).ToRadians();
        var deltaLambda = (longitude2 - longitude1).ToRadians();

        var a = Math.Pow(Math.Sin(deltaPhi / 2), 2) +
                Math.Cos(phi1) * Math.Cos(phi2) *
                Math.Pow(Math.Sin(deltaLambda / 2), 2);

        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return r * c; // returns distance in meters
    }
}

public static class TrigUtils
{
    private const double RadiansPerDegree = Math.PI / 180;
    private const double DegreesPerRadian = 180 / Math.PI;

    public static double ToRadians(this double degrees)
    {
        return degrees * RadiansPerDegree;
    }

    public static double ToDegrees(this double radians)
    {
        return radians * DegreesPerRadian;
    }
}
