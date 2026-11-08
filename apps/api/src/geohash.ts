const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
const CELL = /^[0123456789bcdefghjkmnpqrstuvwxyz]{5}$/;

export const isCell = (value: string): boolean => CELL.test(value);

export function geohash(lat: number, lng: number, precision = 5): string {
  const latRange = [-90, 90];
  const lngRange = [-180, 180];
  let output = "";
  let bits = 0;
  let index = 0;
  let useLng = true;
  while (output.length < precision) {
    const range = useLng ? lngRange : latRange;
    const value = useLng ? lng : lat;
    const mid = (range[0] + range[1]) / 2;
    if (value >= mid) {
      index = (index << 1) | 1;
      range[0] = mid;
    } else {
      index = index << 1;
      range[1] = mid;
    }
    useLng = !useLng;
    bits++;
    if (bits === 5) {
      output += BASE32[index];
      bits = 0;
      index = 0;
    }
  }
  return output;
}
