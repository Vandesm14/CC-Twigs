/** The interval at which nodes broadcast an update */
export const TIMEOUT = 5 * 1000;

/** The TTL of an entry in the database */
export const TTL = TIMEOUT + 2_000;

/** The port that BGP runs on */
export const BGP_PORT = 179;

/** The port that IP runs on */
export const IP_PORT = 80;
