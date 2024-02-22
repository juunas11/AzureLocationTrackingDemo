<script setup lang="ts">
import { updateGridBoundsAsync } from "@/services/mapGrid";
import { getMapsAccessToken } from "@/api/mapsToken";
import { getPastLocations } from "@/api/pastLocations";
import { useSidebarStore } from "@/stores/sidebar";
import * as atlas from "azure-maps-control";
import { onMounted, onUnmounted, watch } from 'vue';
import { emitter, type Events } from "@/services/eventBus";

const sidebarStore = useSidebarStore();

let map: atlas.Map | null = null;
const geofenceDataSource = new atlas.source.DataSource();
let geofencePopup: atlas.Popup | null = null;
const pastLocationsLineDataSource = new atlas.source.DataSource();
const pastLocationsPointsDataSource = new atlas.source.DataSource();
const locationTrackerDataSource = new atlas.source.DataSource();
let locationTrackerPopup: atlas.Popup | null = null;
let carSpriteReady = false;
let cleanupIntervalId: number | null = null;

watch(() => sidebarStore.isOpen, (isOpen) => {
  if (!isOpen) {
    pastLocationsLineDataSource.clear();
    pastLocationsPointsDataSource.clear();
  }
});

function onGeofenceHover(e: atlas.MapMouseEvent) {
  //Make sure the event occurred on a shape feature.
  if (!e.shapes || e.shapes.length == 0) {
    return;
  }

  const shape = e.shapes[0] as atlas.Shape;
  const id = shape.getId();
  const properties = shape.getProperties();

  //Update the content and position of the popup.
  geofencePopup!.setOptions({
    //Create the content of the popup.
    content: `<div style="padding:10px;"><b>Geofence ${id}</b></div>`,
    position: properties.center,
    pixelOffset: [0, -18]
  });

  //Open the popup.
  geofencePopup!.open(map!);
}

function closePopups() {
  locationTrackerPopup!.close();
  geofencePopup!.close();
}

function onLocationTrackerHover(e: atlas.MapMouseEvent) {
  //Make sure the event occurred on a shape feature.
  if (!e.shapes || e.shapes.length == 0) {
    return;
  }

  const shape = e.shapes[0] as atlas.Shape;
  const properties = shape.getProperties();

  //Update the content and position of the popup.
  locationTrackerPopup!.setOptions({
    //Create the content of the popup.
    content: `<div style="padding:10px;"><b>${properties.name}</b><br/><span>${properties.speed?.toFixed(0) ?? '-'} km/h</span></div>`,
    position: shape.getCoordinates() as atlas.data.Position,
    pixelOffset: [0, -18]
  });

  //Open the popup.
  locationTrackerPopup!.open(map!);
}

function onLocationTrackerClick(e: atlas.MapMouseEvent) {
  if (!e.shapes || e.shapes.length == 0) {
    return;
  }
  
  const shape = e.shapes[0] as atlas.Shape;
  const id = shape.getId() as string;

  sidebarStore.openSidebar(id);

  pastLocationsLineDataSource.clear();
  pastLocationsPointsDataSource.clear();
  updatePastLocations(id);
}

function updatePastLocations(trackerId: string) {
  getPastLocations(trackerId)
    .then(pastLocations => {
      if (sidebarStore.selectedTrackerId !== trackerId) {
        return;
      }

      const line = new atlas.data.LineString(pastLocations.map((l: any) => [l.longitude, l.latitude]));
      const shape = new atlas.Shape(line, trackerId, {
        name: 'Tracker: ' + trackerId + ' past locations'
      });
      pastLocationsLineDataSource.add(shape);

      for (const location of pastLocations) {
        const point = new atlas.data.Point([location.longitude, location.latitude]);
        const pointShape = new atlas.Shape(point, trackerId + ':' + location.timestamp, {
          name: new Date(location.timestamp).toLocaleString()
        });
        pastLocationsPointsDataSource.add(pointShape);
      }
    })
}

function initMap() {
  const newMap = new atlas.Map("myMap", {
    center: [24.940806, 60.170218],
    zoom: 14,
    view: "Auto",
    authOptions: {
      authType: "anonymous" as any,
      clientId: import.meta.env.VITE_MAPS_CLIENT_ID,
      getToken: getMapsAccessToken,
    },
  });
  newMap.events.add("ready", function () {
    addControls(newMap);

    newMap.sources.add(geofenceDataSource);
    // https://learn.microsoft.com/en-us/javascript/api/azure-maps-control/atlas.polygonlayeroptions?view=azure-maps-typescript-latest
    const geofenceLayer = new atlas.layer.PolygonLayer(
      geofenceDataSource,
      undefined,
      {}
    );
    newMap.layers.add(geofenceLayer);

    newMap.sources.add(pastLocationsLineDataSource);
    const pastLocationsLineLayer = new atlas.layer.LineLayer(
      pastLocationsLineDataSource,
      undefined,
      {}
    );
    newMap.layers.add(pastLocationsLineLayer);
    newMap.sources.add(pastLocationsPointsDataSource);
    const pastLocationsPointsLayer = new atlas.layer.BubbleLayer(
      pastLocationsPointsDataSource,
      undefined,
      {
        radius: 8,
      }
    );
    newMap.layers.add(pastLocationsPointsLayer);

    newMap.sources.add(locationTrackerDataSource);

    newMap.imageSprite
      .createFromTemplate("car", "car", "teal", "#fff", 1)
      .then(function () {
        const locationTrackerLayer = new atlas.layer.SymbolLayer(
          locationTrackerDataSource,
          undefined,
          {
            iconOptions: {
              image: "car",
              anchor: "center",
              ignorePlacement: true,
              allowOverlap: true,
              rotation: ["get", "heading"],
              rotationAlignment: "map",
            },
          }
        );
        newMap.layers.add(locationTrackerLayer);

        newMap.events.add(
          "mousemove",
          locationTrackerLayer,
          onLocationTrackerHover
        );
        newMap.events.add(
          "touchstart",
          locationTrackerLayer,
          onLocationTrackerHover
        );
        newMap.events.add(
          "click",
          locationTrackerLayer,
          onLocationTrackerClick
        );

        carSpriteReady = true;
      });

    geofenceDataSource.importDataFromUrl("/api/geofences");
    geofencePopup = new atlas.Popup({
      position: [0, 0],
      pixelOffset: [0, -18],
    });

    locationTrackerPopup = new atlas.Popup({
      position: [0, 0],
      pixelOffset: [0, -18],
    });

    //Close the popups when the mouse moves on the map.
    newMap.events.add("mousemove", closePopups);
    /**
     * Open the popup on mouse move or touchstart on the symbol layer.
     * Mouse move is used because mouseover only fires when the mouse initially goes over a symbol.
     * If two symbols overlap, moving the mouse from one to the other won't trigger the event for the new shape as the mouse is still over the layer.
     */
    newMap.events.add("mousemove", geofenceLayer, onGeofenceHover);
    newMap.events.add("touchstart", geofenceLayer, onGeofenceHover);
  });

  map = newMap;
}

function addControls(map: atlas.Map) {
  map.controls.add(new atlas.control.ZoomControl(), {
    position: atlas.ControlPosition.TopLeft,
  });
  map.controls.add(
    new atlas.control.StyleControl({
      mapStyles: [
        "road",
        "grayscale_light",
        "night",
        "grayscale_dark",
        "high_contrast_dark",
      ],
    }),
    {
      position: atlas.ControlPosition.BottomLeft,
    }
  );
}

function onLocationTrackerUpdated(tracker: Events['trackerUpdated']) {
  if (!carSpriteReady) {
    return;
  }
  let shape = locationTrackerDataSource.getShapeById(tracker.trackerId);
  if (shape === null || shape === undefined) {
    shape = new atlas.Shape(tracker.latestLocation, tracker.trackerId, {
      name: 'Tracker: ' + tracker.trackerId,
      heading: tracker.heading ?? 0,
      speed: tracker.speed,
      eventReceivedTimestamp: tracker.latestEventReceivedTimestamp,
    });
    locationTrackerDataSource.add(shape);
  } else {
    shape.addProperty('heading', tracker.heading);
    shape.addProperty('speed', tracker.speed);
    shape.addProperty('eventReceivedTimestamp', tracker.latestEventReceivedTimestamp);
    shape.setCoordinates(tracker.latestLocation.coordinates);
  }
};

function updateGridBounds() {
  updateGridBoundsAsync(map!).then(function () {
    setTimeout(updateGridBounds, 5000);
  }).catch(function (reason) {
    console.error(reason);
    setTimeout(updateGridBounds, 5000);
  });
}

function cleanupOldTrackers() {
  const cleanupThresholdMillis = 15000;
  const now = Date.now();
  const shapes = locationTrackerDataSource.getShapes();

  for (const shape of shapes) {
    const trackerId = shape.getId() as string;
    const timestamp = shape.getProperties().eventReceivedTimestamp;
    if ((now - timestamp) > cleanupThresholdMillis) {
      console.info(`Removing tracker ${trackerId}, its last update was ${now - timestamp} ms ago`);

      if (sidebarStore.selectedTrackerId === trackerId) {
        sidebarStore.closeSidebar();
      }

      locationTrackerDataSource.removeById(trackerId);
    }
  }
}

onMounted(() => {
  initMap();
  updateGridBounds();

  emitter.on('trackerUpdated', onLocationTrackerUpdated);

  cleanupIntervalId = window.setInterval(cleanupOldTrackers, 5000);
});
onUnmounted(() => {
  if (cleanupIntervalId !== null) {
    window.clearInterval(cleanupIntervalId);
    cleanupIntervalId = null;
  }

  emitter.off('trackerUpdated', onLocationTrackerUpdated);

  map?.clear();
  map?.dispose();
  map = null;
});
</script>

<template>
  <div id="myMap"></div>
</template>

<style>
#myMap {
  position: relative;
  width: 100vw;
  height: 100vh;
}
</style>
