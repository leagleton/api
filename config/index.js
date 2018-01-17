/** 
 * Enable strict mode. See:
 * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
 * for more information.
 */
'use strict';

/**
 * The Windows service information.
 */
exports.service = {
  "serviceName": "winman-rest",
  "displayName": "WinMan REST API"
}

/**
 * Define whether we're running two systems ('dual') or one ('single').
 */
exports.mode = 'dual';

/**
 * The 'live' database connection information.
 */
exports.connection = {
  "server": "SQL2012SANDBOX",
  "userName": "winman",
  "password": "winman",
  "options": { "encrypt": true, "database": "WinManLEClean", "requestTimeout": 0, "rowCollectionOnRequestCompletion": false }
};

/**
 * The 'training' database connection information.
 */
exports.connectionTraining = {
  "server": "SQL2012SANDBOX",
  "userName": "winman",
  "password": "winman",
  "options": { "encrypt": true, "database": "WinManLE", "requestTimeout": 0, "rowCollectionOnRequestCompletion": false }
};

/**
 * The web server settings, i.e. the URL of the API.
 */
exports.server = {
  "scheme": "https",
  "host": "rest.winman.net",
  "port": 3000
};

/**
 * Configuration of access tokens.
 *
 * expiresIn                - The time in seconds before the access token expires. Default is 1 hour.
 * calculateExpirationDate  - A simple function which returns the date and time at which the token is
 *                            going to expire in a SQL-friendly format.
 */
exports.token = {
  expiresIn: 3600,
  calculateExpirationDate: (seconds = this.token.expiresIn) =>
    new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000) + (seconds * 1000)).toISOString()
};

/**
 * Configuration of authorisation codes.
 * 
 * expiresIn                - The time in seconds before the authorisation code expires. Default is 5 minutes.
 * calculateExpirationDate  - A simple function which returns the date and time at which the token is
 *                            going to expire in a SQL-friendly format.
 */
exports.codeToken = {
  expiresIn: 300,
  calculateExpirationDate: (seconds = this.codeToken.expiresIn) =>
    new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000) + (seconds * 1000)).toISOString()
};

/**
 * Session configuration
 * 
 * secret - The session secret.
 */
exports.session = {
  secret: 'gSxtmmq9kCxJjyD2eusTKM8KRJuFKcMS'
};
