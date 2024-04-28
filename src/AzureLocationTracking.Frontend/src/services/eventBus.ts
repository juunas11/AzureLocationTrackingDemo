import type { VehicleState } from "@/stores/vehicle";
import mitt from "mitt";

export const emitter = mitt<Events>();

export type Events = {
  locationUpdated: {
    vehicleId: string;
    latitude: number;
    longitude: number;
    timestamp: number;
  };
  geofenceEntered: {
    vehicleId: string;
    geofenceId: number;
  };
  geofenceExited: {
    vehicleId: string;
    geofenceId: number;
  };
  vehicleUpdated: VehicleState;
};
