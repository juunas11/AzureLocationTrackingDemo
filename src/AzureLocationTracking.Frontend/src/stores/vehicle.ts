import { ref } from "vue";
import { defineStore } from "pinia";
import * as atlas from "azure-maps-control";
import { emitter, type Events } from "@/services/eventBus";

export interface VehicleState {
  vehicleId: string;
  previousLocation: atlas.data.Point | null;
  previousEventSentTimestamp: number | null;
  previousEventReceivedTimestamp: number | null;
  latestLocation: atlas.data.Point;
  latestEventSentTimestamp: number;
  latestEventReceivedTimestamp: number;
  heading: number | null;
  speed: number | null;
}

export const useVehicleStore = defineStore("vehicle", () => {
  const vehicles = ref<Record<string, VehicleState>>({});

  function onLocationUpdated({
    vehicleId,
    latitude,
    longitude,
    timestamp,
  }: Events["locationUpdated"]) {
    let vehicle = vehicles.value[vehicleId];
    if (vehicle === undefined) {
      vehicle = {
        vehicleId,
        previousLocation: null,
        previousEventSentTimestamp: null,
        previousEventReceivedTimestamp: null,
        latestLocation: new atlas.data.Point([longitude, latitude]),
        latestEventSentTimestamp: timestamp,
        latestEventReceivedTimestamp: Date.now(),
        heading: null,
        speed: null,
      };
      vehicles.value[vehicleId] = vehicle;
    } else {
      vehicle.previousLocation = vehicle.latestLocation;
      vehicle.previousEventSentTimestamp = vehicle.latestEventSentTimestamp;
      vehicle.previousEventReceivedTimestamp =
        vehicle.latestEventReceivedTimestamp;
      vehicle.latestLocation = new atlas.data.Point([longitude, latitude]);
      vehicle.latestEventSentTimestamp = timestamp;
      vehicle.latestEventReceivedTimestamp = Date.now();

      const heading = atlas.math.getPixelHeading(
        vehicle.previousLocation,
        vehicle.latestLocation
      );
      const deltaSeconds = atlas.math.getTimespan(
        vehicle.previousEventSentTimestamp,
        timestamp,
        atlas.math.TimeUnits.seconds
      );
      const speed = atlas.math.getSpeed(
        vehicle.previousLocation,
        vehicle.latestLocation,
        deltaSeconds,
        "seconds",
        "kilometersPerHour",
        0
      );

      vehicle.heading = heading;
      vehicle.speed = speed;
    }

    emitter.emit("vehicleUpdated", vehicle);
  }

  function subscribeLocationEvents() {
    emitter.on("locationUpdated", onLocationUpdated);
  }

  function unsubscribeLocationEvents() {
    emitter.off("locationUpdated", onLocationUpdated);
  }

  return {
    vehicles,
    subscribeLocationEvents,
    unsubscribeLocationEvents,
  };
});
