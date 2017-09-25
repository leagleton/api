'use strict';

const config = require('./config');
const utils = require('./utils');
const process = require('process');
const jwt = require('jsonwebtoken');
const logger = require('./middleware/logger');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

exports.system = (req) => {
  if (typeof req.session.system != 'undefined' && req.session.system === 'training') {
    tp.setConnectionConfig(config.connectionTraining);
  } else {
    tp.setConnectionConfig(config.connection);
  }
}

/**
 * Given a token and accessToken this will return the user associated with
 * the token if valid.  Otherwise this will throw.
 * @param   {Object}   token       - The token from the DB.
 * @param   {String}   accessToken - The full access token.
 * @param   {Callback} done        - The callback function.
 * @throws  {Error}   If the token is not valid
 * @returns {Promise} Resolved with the user associated with the token if valid
 */
exports.token = (token, accessToken) => {
  utils.verifyToken(accessToken);

  return tp.sql("EXEC wsp_RestApiUsersSelect @user = " + token.userID)
    .execute()
    .then(function (users) {
      if (users.length > 0) {
        const user = {
          "id": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };
        return user;
      } else {
        const err = new Error("No user found with supplied user number. Token may be invalid.");
        return logger.error(err);
      }
    })
    .then(user => user)
    .catch(err => logger.error(err));
};

/**
 * Given an auth code, client, and redirectURI this will return the auth code if it exists and is
 * not 0, the client id matches it, and the redirectURI matches it, otherwise this will throw an
 * error.
 * @param  {Object}  code        - The raw auth code
 * @param  {Object}  authCode    - The auth code record from the DB
 * @param  {Object}  client      - The client profile
 * @param  {Object}  redirectURI - The redirectURI to check against
 * @throws {Error}   If the auth code does not exist or is zero or does not match the client or
 *                   the redirectURI
 * @returns {Object} The auth code token if valid
 */
exports.authCode = (code, authCode, client, redirectURI) => {
  utils.verifyToken(code);
  if (client.id !== authCode.client) {
    throw new Error('AuthCode client does not match client id given');
  }
  if (redirectURI !== authCode.RedirectURI) {
    throw new Error('AuthCode RedirectURI does not match redirectURI given');
  }

  // TODO: check user too?
  return authCode;
};

/**
 * Given an auth code this will generate an access token, save that token and then return it.
 * @param   {Number}   user   - The user number.
 * @param   {Number}   client - The client number.
 * @param   {String}   scope  - The allowed scope(s).
 * @returns {Promise}  The resolved access token after saving.
 */
exports.generateToken = ({ user, client, scope, lifetime, source }) => {
  const expires = config.token.calculateExpirationDate(lifetime);
  const expiresIn = parseInt(Date.parse(expires) / 1000);

  const token = utils.createToken({ sub: user, exp: expiresIn, src: source, scp: scope });
  const uuid = jwt.decode(token).jti;

  return tp.sql("EXEC wsp_RestApiAccessTokensInsert \
                  @uuid = '" + uuid + "', \
                  @expires = '" + expires + "', \
                  @scopes = '" + scope + "', \
                  @user = " + user + ", \
                  @client = " + client)
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
