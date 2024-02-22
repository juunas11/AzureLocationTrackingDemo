import type { LocationTrackerState } from "@/stores/locationTracking";
import mitt from "mitt";

export const emitter = mitt<Events>();

export type Events = {
  locationUpdated: {
    trackerId: string;
    latitude: number;
    longitude: number;
    timestamp: number;
  };
  geofenceEntered: {
    trackerId: string;
    geofenceId: number;
  };
  geofenceExited: {
    trackerId: string;
    geofenceId: number;
  };
  trackerUpdated: LocationTrackerState;
};
