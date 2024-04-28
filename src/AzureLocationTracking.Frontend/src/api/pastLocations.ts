export function getPastLocations(vehicleId: string) {
  return fetch(`/api/vehicles/${vehicleId}/pastLocations`)
    .then((r) => r.json())
    .catch((err) => console.error(err));
}
