export function getGeofenceEvents(vehicleId: string) {
  return fetch(`/api/vehicles/${vehicleId}/geofenceEvents`)
    .then((r) => r.json())
    .catch((err) => console.error(err));
}
