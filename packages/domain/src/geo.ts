/**
 * Shared straight-line geometry (plan #140 Decision 12): the one distance every rule uses
 * (instant candidates and arrival, job eligibility of #139). No Maps API.
 */

/** Mean Earth radius (IUGG), km. */
const EARTH_RADIUS_KM = 6371.0088;

const rad = (deg: number): number => (deg * Math.PI) / 180;

/** Great-circle (haversine) distance in km between two WGS84 points. */
export function distanceKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}
