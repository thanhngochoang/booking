// Shared haversine distance helper, R = 6371.0088 km
export function distanceKm(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const R = 6371.0088;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;

  const sinHalfDlat = Math.sin(dLat / 2);
  const sinHalfDlng = Math.sin(dLng / 2);

  const h =
    sinHalfDlat * sinHalfDlat +
    Math.cos(lat1) * Math.cos(lat2) * sinHalfDlng * sinHalfDlng;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return R * c;
}
