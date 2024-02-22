export const getMapsAccessToken = (
  resolve: (value: string | undefined) => void,
  reject: (reason: any) => void
) => {
  fetch("/api/mapsToken")
    .then((r) => r.text())
    .then((token) => resolve(token))
    .catch((reason) => reject(reason));
};
