export function getGeofenceEvents(trackerId: string) {
  return fetch(`/api/trackers/${trackerId}/geofenceEvents`)
    .then((r) => r.json())
    .catch((err) => console.error(err));
}
