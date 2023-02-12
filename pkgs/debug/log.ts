export function viaHTTP(json: Record<string, any>) {
  http.post(`http://mr.thedevbird.com:3000/log`, textutils.serializeJSON(json));
}
