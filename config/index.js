'use strict';

// The configuration options of the server

exports.service = {
  "serviceName": "winman-rest",
  "displayName": "WinMan REST API"
}

exports.connection = {
  "server": "SQL2012SANDBOX",
  "userName": "winman",
  "password": "winman",
  "options": { "encrypt": true, "database": "WinManLEClean", "requestTimeout": 0, "rowCollectionOnRequestCompletion": false }
};

exports.connectionTraining = {
  "server": "SQL2012SANDBOX",
  "userName": "winman",
  "password": "winman",
  "options": { "encrypt": true, "database": "WinManLE", "requestTimeout": 0, "rowCollectionOnRequestCompletion": false }
};

exports.server = {
  "scheme": "https",
  "host": "rest.winman.net",
  "port": 3000
};

/**
 * Configuration of access tokens.
 *
 * expiresIn               - The time in seconds before the access token expires. Default is 1 hour.
 * calculateExpirationDate - A simple function to calculate the absolute time that the token is
 *                           going to expire in.
 */
exports.token = {
  expiresIn: 3600,
  calculateExpirationDate: (seconds = this.token.expiresIn) =>
    new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000) + (seconds * 1000)).toISOString()
};

/**
 * Configuration of code token.
 * expiresIn - The time in seconds before the authorisation code expires.  Default is 5 minutes.
 */
exports.codeToken = {
  expiresIn: 300,
  calculateExpirationDate: (seconds = this.codeToken.expiresIn) =>
    new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000) + (seconds * 1000)).toISOString()
};

/**
 * Session configuration
 * secret - The session secret.
 */
exports.session = {
  secret: 'gSxtmmq9kCxJjyD2eusTKM8KRJuFKcMS'
};
