import { connection } from "@/services/signalr";
import * as atlas from "azure-maps-control";

interface MapBounds {
  east: number;
  west: number;
  north: number;
  south: number;
}

let previousMapBounds: {
  east: number | null;
  west: number | null;
  north: number | null;
  south: number | null;
} = {
  east: null,
  west: null,
  north: null,
  south: null,
};
let previousGridSquares: number[][] = [];

function getMapBounds(map: atlas.Map) {
  const bounds = map.getCamera().bounds as atlas.data.BoundingBox;

  // Bounds are an array of 4 numbers: [west, south, east, north]
  // West and East values can cross over 180/-180 longitude if the map is scrolled.
  const east = Math.ceil(bounds[2]);
  const west = Math.floor(bounds[0]);
  const north = Math.ceil(bounds[3]);
  const south = Math.floor(bounds[1]);
  return {
    east,
    west,
    north,
    south,
  };
}

function areMapBoundsDifferent(newBounds: MapBounds) {
  return (
    previousMapBounds.east !== newBounds.east ||
    previousMapBounds.west !== newBounds.west ||
    previousMapBounds.north !== newBounds.north ||
    previousMapBounds.south !== newBounds.south
  );
}

function getGridSquares(bounds: MapBounds) {
  const gridSquares = [];

  for (var lng = bounds.west; lng < bounds.east; lng++) {
    for (var lat = bounds.south; lat < bounds.north; lat++) {
      const gridSquare = [lng, lat];
      gridSquares.push(gridSquare);
    }
  }

  return gridSquares;
}

export function updateGridBoundsAsync(map: atlas.Map) {
  if (!map) {
    return Promise.resolve();
  }

  if (connection.state !== "Connected") {
    return Promise.resolve();
  }

  const newBounds = getMapBounds(map);
  if (!areMapBoundsDifferent(newBounds)) {
    return Promise.resolve();
  }

  let newGridSquares = getGridSquares(newBounds);
  if (newGridSquares.length > 50) {
    newGridSquares = [];
  }

  return connection
    .invoke("updateMapGridGroups", newGridSquares, previousGridSquares)
    .then(function () {
      previousMapBounds = newBounds;
      previousGridSquares = newGridSquares;
    });
}
