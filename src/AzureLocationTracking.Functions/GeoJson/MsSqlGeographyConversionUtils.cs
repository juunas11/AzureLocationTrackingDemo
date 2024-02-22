using GeoJSON.Net;
using GeoJSON.Net.Geometry;
using Microsoft.SqlServer.Types;

namespace AzureLocationTracking.Functions.GeoJson;

// Borrowed from: https://github.com/GeoJSON-Net/GeoJSON.Net.Contrib/tree/master/src/GeoJSON.Net.Contrib.MsSqlSpatial
// This Nuget is only available for .NET Framework

/// <summary>
/// Sink converting a SqlGeography to a GeoJSON geometry
/// Usage : <code>SqlGeographyGeoJsonSink sink = new SqlGeographyGeoJsonSink();
/// sqlgeography.Populate(sink);
/// // sink.BoundingBox returns a GeoJSON compliant double[] bbox
/// return sink.ConstructedGeography; // returns an IGeometryObject
/// </code>
/// </summary>
internal class SqlGeographyGeoJsonSink : IGeographySink110
{
    SinkGeometryCollection<OpenGisGeographyType> _geomCollection;
    bool _isGeometryCollection = false;
    int _nestLevel = 0;
    SinkGeometry<OpenGisGeographyType> _currentGeometry;
    SinkLineRing _currentRing;
    double _lonMin = 180;
    double _latMin = 90;
    double _lonMax = -180;
    double _latMax = -90;

    private readonly bool _withBoundingBox;

    public SqlGeographyGeoJsonSink(bool withBoundingBox = true)
    {
        this._withBoundingBox = withBoundingBox;
    }

    #region Sink implementation

    public void BeginGeography(OpenGisGeographyType type)
    {
        if (_geomCollection == null)
        {
            _geomCollection = new SinkGeometryCollection<OpenGisGeographyType>(type);
            if (type == OpenGisGeographyType.GeometryCollection)
            {
                _isGeometryCollection = true;
            }
        }

        _currentGeometry = new SinkGeometry<OpenGisGeographyType>(type);
        if (_isGeometryCollection && _nestLevel > 0)
        {
            if (_nestLevel == 1)
            {
                _geomCollection.SubItems.Add(new SinkGeometryCollection<OpenGisGeographyType>(type));
            }
            _geomCollection.SubItems.Last().Add(_currentGeometry);
        }
        else
        {
            _geomCollection.Add(_currentGeometry);
        }

        _nestLevel++;
    }

    public void BeginFigure(double lat, double lon, double? z, double? m)
    {
        _currentRing = new SinkLineRing();
        _currentRing.Add(new Position(latitude: lat
                                    , longitude: lon
                                    , altitude: z));

        UpdateBoundingBox(lon, lat);
    }

    public void AddLine(double lat, double lon, double? z, double? m)
    {
        _currentRing.Add(new Position(latitude: lat
                                    , longitude: lon
                                    , altitude: z));

        UpdateBoundingBox(lon, lat);
    }

    public void EndFigure()
    {
        if (_currentRing == null)
            return;

        _currentGeometry.Add(_currentRing);
        _currentRing = null;
    }

    public void EndGeography()
    {
        _nestLevel--;
        _currentGeometry = null;
    }

    public void SetSrid(int srid) { }

    // Not implemented
    // This one is tough ! Implementation should use SqlGeometry.CurveToLineWithTolerance
    public void AddCircularArc(double x1, double y1, double? z1, double? m1, double x2, double y2, double? z2, double? m2)
    {
        throw new NotImplementedException();
    }

    private void UpdateBoundingBox(double lon, double lat)
    {
        _lonMin = Math.Min(lon, _lonMin);
        _latMin = Math.Min(lat, _latMin);
        _lonMax = Math.Max(lon, _lonMax);
        _latMax = Math.Max(lat, _latMax);
    }

    #endregion

    public IGeometryObject ConstructedGeography
    {
        get
        {
            IGeometryObject _geometry = null;

            switch (_geomCollection.GeometryType)
            {
                case OpenGisGeographyType.Point:
                case OpenGisGeographyType.MultiPoint:
                case OpenGisGeographyType.LineString:
                case OpenGisGeographyType.MultiLineString:
                case OpenGisGeographyType.Polygon:
                case OpenGisGeographyType.MultiPolygon:

                    _geometry = GeometryFromSinkGeometryCollection(_geomCollection);

                    break;
                case OpenGisGeographyType.GeometryCollection:

                    List<IGeometryObject> subGeometries = _geomCollection.SubItems.Select(subItem => GeometryFromSinkGeometryCollection(subItem)).ToList();
                    _geometry = new GeometryCollection(subGeometries);

                    ((GeometryCollection)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                    break;
                default:
                    throw new NotSupportedException("Geometry type " + _geomCollection.GeometryType.ToString() + " is not supported yet.");
            }

            return _geometry;
        }
    }

    private IGeometryObject GeometryFromSinkGeometryCollection(SinkGeometryCollection<OpenGisGeographyType> sinkCollection)
    {

        IGeometryObject _geometry = null;

        switch (sinkCollection.GeometryType)
        {
            case OpenGisGeographyType.Point:
                _geometry = ConstructGeometryPart(sinkCollection[0]);
                ((Point)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            case OpenGisGeographyType.MultiPoint:
                _geometry = new MultiPoint(sinkCollection.Skip(1)
                                                         .Select(g => (Point)ConstructGeometryPart(g))
                                                         .ToList());
                ((MultiPoint)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            case OpenGisGeographyType.LineString:
                _geometry = ConstructGeometryPart(sinkCollection[0]);
                ((LineString)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            case OpenGisGeographyType.MultiLineString:
                _geometry = new MultiLineString(sinkCollection.Skip(1)
                                                              .Select(g => (LineString)ConstructGeometryPart(g))
                                                              .ToList());
                ((MultiLineString)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            case OpenGisGeographyType.Polygon:
                _geometry = ConstructGeometryPart(sinkCollection.First());
                ((Polygon)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            case OpenGisGeographyType.MultiPolygon:
                _geometry = new MultiPolygon(sinkCollection.Skip(1)
                                                           .Select(g => (Polygon)ConstructGeometryPart(g))
                                                           .ToList());
                ((MultiPolygon)_geometry).BoundingBoxes = this._withBoundingBox ? this.BoundingBox : null;
                break;
            default:
                throw new NotSupportedException("Geometry type " + sinkCollection.GeometryType.ToString() + " is not possible in GetConstructedGeometry.");
        }

        return _geometry;

    }

    public double[] BoundingBox
    {
        get { return this._withBoundingBox ? new double[] { _lonMin, _latMin, _lonMax, _latMax } : null; }
    }

    private IGeometryObject ConstructGeometryPart(SinkGeometry<OpenGisGeographyType> geomPart)
    {

        IGeometryObject geometry = null;

        switch (geomPart.GeometryType)
        {
            case OpenGisGeographyType.Point:
                geometry = new Point(geomPart[0][0]);
                break;
            case OpenGisGeographyType.MultiPoint:
                MultiPoint mp = new MultiPoint(geomPart.Select(g => new Point(g[0])).ToList());
                geometry = mp;
                break;
            case OpenGisGeographyType.LineString:
                geometry = new LineString(geomPart[0]);
                break;
            case OpenGisGeographyType.MultiLineString:
                geometry = new MultiLineString(geomPart.Select(line => new LineString(line)).ToList());
                break;
            case OpenGisGeographyType.Polygon:
                geometry = new Polygon(geomPart.Select(line => new LineString(line)).ToList());
                break;

            default:
                throw new NotSupportedException("Geometry type " + geomPart.GeometryType.ToString() + " is not supported yet.");
        }

        return geometry;
    }
}

/*
        MsSqlSpatialConvert
        Partial class. Only methods from Sql spatial types to GeoJSON are here
        For Sql spatial types to GeoJSON, see MsSqlSpatialConvertToGeoJson.cs file
        For GeoJSON to Sql Server geometry, see MsSqlSpatialConvertToSqlGeometry.cs file
        For GeoJSON to Sql Server geography, see MsSqlSpatialConvertToSqlGeography.cs file
    */
/// <summary>
/// GeoJSON.Net / MS Sql Server Spatial data types converter.
/// All methods here are static and extensions to GeoJSON.Net types and Sql Server types.
/// </summary>
public static partial class MsSqlSpatialConvert
{
    #region SqlGeography to GeoJSON

    /// <summary>
    /// Converts a native Sql Server geography to GeoJSON geometry
    /// </summary>
    /// <param name="sqlGeography">SQL Server geography to convert</param>
    /// <returns>GeoJSON geometry</returns>
    public static IGeometryObject ToGeoJSONGeometry(this SqlGeography sqlGeography)
    {
        if (sqlGeography == null || sqlGeography.IsNull)
        {
            return null;
        }

        // Make valid if necessary
        sqlGeography = sqlGeography.MakeValidIfInvalid();
        if (sqlGeography.STIsValid().IsFalse)
        {
            throw new Exception("Invalid geometry : " + sqlGeography.IsValidDetailed());
        }

        // Conversion using geography sink
        SqlGeographyGeoJsonSink sink = new SqlGeographyGeoJsonSink();
        sqlGeography.Populate(sink);
        return sink.ConstructedGeography;
    }

    /// <summary>
    /// Converts a native Sql Server geography to GeoJSON geometry
    /// </summary>
    /// <param name="sqlGeography">SQL Server geography to convert</param>
    /// <param name="withBoundingBox">Value indicating whether the feature's BoundingBox should be set.</param>
    /// <returns>GeoJSON geometry</returns>
    public static T ToGeoJSONObject<T>(this SqlGeography sqlGeography, bool withBoundingBox = true) where T : GeoJSONObject
    {
        if (sqlGeography == null || sqlGeography.IsNull)
        {
            return null;
        }

        // Make valid if necessary
        sqlGeography = sqlGeography.MakeValidIfInvalid();
        if (sqlGeography.STIsValid().IsFalse)
        {
            throw new Exception("Invalid geometry : " + sqlGeography.IsValidDetailed());
        }

        // Conversion using geography sink
        T geoJSONobj = null;
        SqlGeographyGeoJsonSink sink = new SqlGeographyGeoJsonSink();
        sqlGeography.Populate(sink);
        geoJSONobj = sink.ConstructedGeography as T;
        geoJSONobj.BoundingBoxes = withBoundingBox ? sink.BoundingBox : null;

        return geoJSONobj;
    }

    #endregion
}

internal class SinkGeometry<T> : List<SinkLineRing>
{
    public T GeometryType { get; set; }

    public SinkGeometry(T geomType)
    {
        GeometryType = geomType;
    }
}

internal class SinkGeometryCollection<T> : List<SinkGeometry<T>>
{
    public T GeometryType { get; set; }

    // For GEOMETRYCOLLECTION
    public List<SinkGeometryCollection<T>> SubItems { get; set; }

    public SinkGeometryCollection(T geomType)
    {
        GeometryType = geomType;
        SubItems = new List<SinkGeometryCollection<T>>();

    }
}

internal class SinkLineRing : List<IPosition> { }

public static class SqlSpatialExtensions
{
    // Sql geometry extensions

    /// <summary>
    /// Computes bounding box of a geometry instance
    /// </summary>
    /// <param name="geom"></param>
    /// <returns>Array of doubles in this order: xmin, ymin, xmax, ymax</returns>
    public static double[] BoundingBox(this SqlGeometry geom)
    {
        double xmin = Double.MaxValue, ymin = Double.MaxValue, xmax = Double.MinValue, ymax = double.MinValue;
        foreach (SqlGeometry point in geom.Points())
        {
            xmin = Math.Min(point.STX.Value, xmin);
            ymin = Math.Min(point.STY.Value, ymin);
            xmax = Math.Max(point.STX.Value, xmax);
            ymax = Math.Max(point.STY.Value, ymax);
        }
        return new double[] { xmin, ymin, xmax, ymax };
    }

    /// <summary>
    /// Easier to use geometry enumerator than STGeometryN()
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static IEnumerable<SqlGeometry> Geometries(this SqlGeometry geom)
    {
        for (int i = 1; i <= geom.STNumGeometries().Value; i++)
        {
            yield return geom.STGeometryN(i);
        }
    }

    /// <summary>
    /// Easier to use points enumerator on SqlGeometry
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static IEnumerable<SqlGeometry> Points(this SqlGeometry geom)
    {
        for (int i = 1; i <= geom.STNumPoints().Value; i++)
        {
            yield return geom.STPointN(i);
        }
    }

    /// <summary>
    /// Easier to use interior geometry enumerator on SqlGeometry polygons
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static IEnumerable<SqlGeometry> InteriorRings(this SqlGeometry geom)
    {
        for (int i = 1; i <= geom.STNumInteriorRing().Value; i++)
        {
            yield return geom.STInteriorRingN(i);
        }
    }

    /// <summary>
    /// Easier to use MakeValid() that validates only if required
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static SqlGeometry MakeValidIfInvalid(this SqlGeometry geom)
    {
        if (geom == null || geom.IsNull)
        {
            return geom;
        }

        // Make valid if necessary
        if (geom.STIsValid().IsFalse)
        {
            return geom.MakeValid();
        }

        return geom;
    }

    // Sql geography extensions
    /// <summary>
    /// Computes bounding box of a geography instance
    /// </summary>
    /// <param name="geom"></param>
    /// <returns>Array of doubles in this order: xmin, ymin, xmax, ymax</returns>
    public static double[] BoundingBox(this SqlGeography geom)
    {
        double xmin = 180, ymin = 90, xmax = -180, ymax = -90;
        foreach (SqlGeography point in geom.Points())
        {
            xmin = Math.Min(point.Long.Value, xmin);
            ymin = Math.Min(point.Lat.Value, ymin);
            xmax = Math.Max(point.Long.Value, xmax);
            ymax = Math.Max(point.Lat.Value, ymax);
        }
        return new double[] { xmin, ymin, xmax, ymax };
    }

    /// <summary>
    /// Easier to use geometry enumerator than STGeometryN()
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static IEnumerable<SqlGeography> Geometries(this SqlGeography geom)
    {
        for (int i = 1; i <= geom.STNumGeometries().Value; i++)
        {
            yield return geom.STGeometryN(i);
        }
    }

    /// <summary>
    /// Easier to use points enumerator on SqlGeography
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static IEnumerable<SqlGeography> Points(this SqlGeography geom)
    {
        for (int i = 1; i <= geom.STNumPoints().Value; i++)
        {
            yield return geom.STPointN(i);
        }
    }

    /// <summary>
    /// Easier to use MakeValid() that validates only if required
    /// </summary>
    /// <param name="geom"></param>
    /// <returns></returns>
    public static SqlGeography MakeValidIfInvalid(this SqlGeography geom)
    {
        if (geom == null || geom.IsNull)
        {
            return geom;
        }

        // Make valid if necessary
        if (geom.STIsValid().IsFalse)
        {
            return geom.MakeValid();
        }

        return geom;
    }
}