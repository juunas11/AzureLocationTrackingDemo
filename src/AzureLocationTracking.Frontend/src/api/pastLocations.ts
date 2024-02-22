export function getPastLocations(trackerId: string) {
  return fetch(`/api/trackers/${trackerId}/pastLocations`)
    .then((r) => r.json())
    .catch((err) => console.error(err));
}
