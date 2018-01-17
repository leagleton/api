/** 
 * Enable strict mode. See:
 * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
 * for more information.
 */
'use strict';

/** 
 * Initilaise required node modules. Similar to
 * 'Imports <namespace>' statements in VB.NET.
 * 
 * 'fs' is used to interact with the file system.
 * 'path' is used to correctly handle file paths.
 * 'uuid' is used to generate a UUID string for the token.
 * 'jwt' is used for decoding tokens.
 * 'logger' is used to define our custom logging functions.
 * 'config' refers to our application's config settings.
 * 'tp' is used for executing SQL queries.
 */
const fs = require('fs');
const path = require('path');
const uuid = require('uuid/v4');
const jwt = require('jsonwebtoken');
const logger = require('./logger');
const config = require('../config');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Run some cleanup operations every hour.
 */
setInterval(function () {
  /**
   * Delete expired access tokens and authorisation codes
   * from training and live DBs
   */
  tp.setConnectionConfig(config.connectionTraining);
  
  tp.sql("EXEC wsp_RestApiExpiredAccessTokensDelete")
    .execute()
    .then(() => {
      tp.setConnectionConfig(config.connection);
      tp.sql("EXEC wsp_RestApiExpiredAccessTokensDelete")
        .execute()
        .catch(err => logger.error(err.stack));
    })
    .catch(err => logger.error(err.stack));

  /**
   * Delete swagger schemas which belong to expired sessions.
   */
  fs.readdir('./views/static/swagger/schema/', function (err, fileNames) {
    if (err) return logger.error(err.stack);

    const files = fileNames.map((filename, index) => {
      if (filename.substr(filename.lastIndexOf('.') + 1).toLowerCase() !== 'json') {
        return;
      } else {
        return fs.stat(path.resolve('./sessions/', filename), function (err, stats) {
          if (!err && stats.isFile()) {
            return;
          } else {
            fs.unlink(path.resolve('./views/static/swagger/schema/', filename));
          }
        });
      }
    });
  });
}, 3600000);

/** 
 * Private certificate used for signing JSON WebTokens. 
 */
const privateKey = fs.readFileSync(path.join(__dirname, '../certs/winman.key'));

/** 
 * Public certificate used for verifying JSON WebTokens. 
 */
const publicKey = fs.readFileSync(path.join(__dirname, '../certs/winman.crt'));

/**
 * Creates a signed JSON WebToken and returns it.  Utilizes the private certificate to create
 * the signed JSON WebToken.
 * 
 * @param   {Number} exp - The exact date/time the token will expire, expressed in seconds.
 * @param   {String} sub - The subject or identity of the token.
 * @param   {String} src - The source of the request.
 * @param   {String} scp - The allowed scopes. 
 * @returns {String} The JSON WebToken.
 */
exports.createToken = ({ exp, sub, src, scp } = {}) => {
  const token = jwt.sign({
    jti: uuid(),
    sub,
    exp,
    src,
    scp
  }, privateKey, {
      algorithm: 'RS256',
    });

  return token;
};

/**
 * Verifies the token through the jwt library using the public certificate.
 * 
 * @param   {String} token - The token to verify.
 * @throws  {Error}  Error if the token could not be verified.
 * @returns {Object} The token decoded and verified.
 */
exports.verifyToken = token => jwt.verify(token, publicKey);

/**
 * Generates a random string for use as a new client ID or client secret.
 * 
 * @param   {Number} length - The length of the string to generate.
 * @returns {String} The randomly generated string.
 */
exports.generateString = length => {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  let randomString = '';

  for (let i = length; i > 0; --i) randomString += chars[Math.floor(Math.random() * chars.length)];

  return randomString;
};
