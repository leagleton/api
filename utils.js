'use strict';

const fs = require('fs');
const path = require('path');
const uuid = require('uuid/v4');
const jwt = require('jsonwebtoken');
const logger = require('./middleware/logger');
const config = require('./config');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

/** Delete expired access tokens and authorisation codes from training and live DBs every hour */
setInterval(function () {
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
}, 3600000);

/** Private certificate used for signing JSON WebTokens. */
const privateKey = fs.readFileSync(path.join(__dirname, 'certs/winman.key'));

/** Public certificate used for verifying JSON WebTokens. */
const publicKey = fs.readFileSync(path.join(__dirname, 'certs/winman.crt'));

/**
 * Creates a signed JSON WebToken and returns it.  Utilizes the private certificate to create
 * the signed JSON WebToken.
 * @param  {Number} exp - The exact date/time the token will expire, expressed in seconds.
 * @param  {String} sub - The subject or identity of the token.
 * @param  {String} src - The source of the request.
 * @param  {String} scp - The allowed scopes. 
 * @return {String} The JSON WebToken.
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
 * @param   {String} token - The token to verify.
 * @throws  {Error} Error if the token could not be verified.
 * @returns {Object} The token decoded and verified.
 */
exports.verifyToken = token => jwt.verify(token, publicKey);

/**
 * Generates a random string for use as a new client ID or secret.
 * @param   {Number} length - The length of the string to generate.
 * @returns {String} The randomly generated string.
 */
exports.generateString = length => {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  let randomString = '';

  for (let i = length; i > 0; --i) randomString += chars[Math.floor(Math.random() * chars.length)];

  return randomString;
};
