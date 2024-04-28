export function getGeofences() {
  return fetch("/api/geofences")
    .then((r) => r.json())
    .catch((err) => console.error(err));
}
