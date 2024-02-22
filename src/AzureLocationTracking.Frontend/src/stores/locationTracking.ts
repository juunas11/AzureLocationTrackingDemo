import { ref } from "vue";
import { defineStore } from "pinia";
import * as atlas from "azure-maps-control";
import { emitter, type Events } from "@/services/eventBus";

export interface LocationTrackerState {
  trackerId: string;
  previousLocation: atlas.data.Point | null;
  previousEventSentTimestamp: number | null;
  previousEventReceivedTimestamp: number | null;
  latestLocation: atlas.data.Point;
  latestEventSentTimestamp: number;
  latestEventReceivedTimestamp: number;
  heading: number | null;
  speed: number | null;
}

export const useLocationTrackingStore = defineStore("locationTracking", () => {
  const trackers = ref<Record<string, LocationTrackerState>>({});

  function onLocationUpdated({
    trackerId,
    latitude,
    longitude,
    timestamp,
  }: Events["locationUpdated"]) {
    let tracker = trackers.value[trackerId];
    if (tracker === undefined) {
      tracker = {
        trackerId,
        previousLocation: null,
        previousEventSentTimestamp: null,
        previousEventReceivedTimestamp: null,
        latestLocation: new atlas.data.Point([longitude, latitude]),
        latestEventSentTimestamp: timestamp,
        latestEventReceivedTimestamp: Date.now(),
        heading: null,
        speed: null,
      };
      trackers.value[trackerId] = tracker;
    } else {
      tracker.previousLocation = tracker.latestLocation;
      tracker.previousEventSentTimestamp = tracker.latestEventSentTimestamp;
      tracker.previousEventReceivedTimestamp =
        tracker.latestEventReceivedTimestamp;
      tracker.latestLocation = new atlas.data.Point([longitude, latitude]);
      tracker.latestEventSentTimestamp = timestamp;
      tracker.latestEventReceivedTimestamp = Date.now();

      const heading = atlas.math.getPixelHeading(
        tracker.previousLocation,
        tracker.latestLocation
      );
      const deltaSeconds = atlas.math.getTimespan(
        tracker.previousEventSentTimestamp,
        timestamp,
        atlas.math.TimeUnits.seconds
      );
      const speed = atlas.math.getSpeed(
        tracker.previousLocation,
        tracker.latestLocation,
        deltaSeconds,
        "seconds",
        "kilometersPerHour",
        0
      );

      tracker.heading = heading;
      tracker.speed = speed;
    }

    emitter.emit("trackerUpdated", tracker);
  }

  function subscribeLocationEvents() {
    emitter.on("locationUpdated", onLocationUpdated);
  }

  function unsubsrcibeLocationEvents() {
    emitter.off("locationUpdated", onLocationUpdated);
  }

  return {
    trackers,
    subscribeLocationEvents,
    unsubsrcibeLocationEvents,
  };
});
