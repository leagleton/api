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
 * 'config' refers to our application's config settings.
 * 'utils' refers to our custom functions for handling tokens.
 * 'jwt' is used for decoding tokens.
 * 'logger' is used to define our custom logging functions.
 * 'tp' is used for executing SQL queries.
 */
const config = require('../config');
const utils = require('./utils');
const jwt = require('jsonwebtoken');
const logger = require('./logger');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Set which system is in use - training or live.
 * 
 * @param {Object} req  - The request object.
 */
exports.system = (req) => {
  if (typeof req.session.system != 'undefined' && req.session.system === 'training') {
    tp.setConnectionConfig(config.connectionTraining);
  } else {
    tp.setConnectionConfig(config.connection);
  }
}

/**
 * Given a token and access token this will return the user associated with
 * the token if valid.  Otherwise this will throw an error.
 * 
 * @param   {Object}   token       - The token from the DB.
 * @param   {String}   accessToken - The full access token.
 * @param   {Callback} done        - The callback function.
 * @throws  {Error}    If the token is not valid.
 * @returns {Promise}  Resolved with the user associated with the token if valid.
 */
exports.token = (token, accessToken) => {
  utils.verifyToken(accessToken);

  return tp.sql("EXEC wsp_RestApiUsersSelect @user = " + token.userID + ", @website = " + token.website)
    .execute()
    .then(function (users) {
      if (users.length > 0) {
        const user = {
          "user": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };
        return user;
      } else {
        const err = new Error("Error: Token may be invalid.");
        return logger.error(err);
      }
    })
    .then(user => user)
    .catch(err => logger.error(err));
};

/**
 * Given an auth code, client, and redirect URI this will return the auth code if it exists and is
 * not 0, the client ID matches it, and the redirect URI matches it. Otherwise this will throw an
 * error.
 * 
 * @param  {Object}  code        - The raw auth code.
 * @param  {Object}  authCode    - The auth code record from the DB.
 * @param  {Object}  client      - The client profile.
 * @param  {Object}  redirectURI - The redirectURI to check against.
 * @throws {Error}   If the auth code does not exist or is zero or does not match the client or
 *                   the redirectURI.
 * @returns {Object} The auth code token if valid.
 */
exports.authCode = (code, authCode, client, redirectURI) => {
  utils.verifyToken(code);
  if (client.client !== authCode.client) {
    throw new Error('AuthCode client does not match client id given');
  }
  if (redirectURI.toLowerCase() !== authCode.RedirectURI.toLowerCase()) {
    throw new Error('AuthCode RedirectURI does not match redirectURI given');
  }
  return authCode;
};

/**
 * Given an auth code this will generate an access token, save that token and then return it.
 * 
 * @param   {Number}   user   - The user number.
 * @param   {Number}   client - The client number.
 * @param   {String}   scope  - The allowed scope(s).
 * @returns {Promise}  The resolved access token after saving.
 */
exports.generateToken = ({ user, client, scope, lifetime, source, website }) => {
  const expires = config.token.calculateExpirationDate(lifetime);
  const expiresIn = parseInt(Date.parse(expires) / 1000);

  const token = utils.createToken({ sub: user, exp: expiresIn, src: source, scp: scope });
  const uuid = jwt.decode(token).jti;

  return tp.sql("EXEC wsp_RestApiAccessTokensInsert \
                  @uuid = '" + uuid + "', \
                  @expires = '" + expires + "', \
                  @scopes = '" + scope + "', \
                  @user = " + user + ", \
                  @client = " + client + ", \
                  @website = " + website)
    .execute()
    .then(function () {
      const newToken = {
        token,
        expires
      }
      return newToken
    })
    .catch(err => logger.error(err.message));
};
