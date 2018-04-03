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
 * 'login' is used to make sure the user is loggged in.
 * 'oauth2orize' and 'server' are used for the OAUTH2 token exchange process.
 * 'passport' is used for authentication.
 * 'utils' refers to our custom functions for handling tokens.
 * 'validate' refers to our custom token validation functions.
 * 'jwt' is used for decoding tokens.
 * 'tp' is used for executing SQL queries.
 */
const config = require('../config');
const login = require('connect-ensure-login');
const oauth2orize = require('oauth2orize');
const server = oauth2orize.createServer();
const passport = require('passport');
const utils = require('./utils');
const validate = require('./validate');
const jwt = require('jsonwebtoken');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Set which system is in use - training or live.
 * @param {Object} req  - The request object.
 */
exports.system = (req) => {
  if (typeof req.session.system != 'undefined' && req.session.system === 'training') {
    tp.setConnectionConfig(config.connectionTraining);
  } else {
    tp.setConnectionConfig(config.connection);
  }
  validate.system(req);
}

/**
 * This function is responsible for issuing an authorisation code.
 */
server.grant(oauth2orize.grant.code((client, redirectURI, user, ares, done) => {
  const expires = config.codeToken.calculateExpirationDate();
  const expiresIn = parseInt(Date.parse(expires) / 1000);
  let source = "swagger";

  if (ares.hasOwnProperty('response') && ares.response == 'ajax') {
    source = "account";
  }

  const eCommerceWebsite = ares.website;
  const code = utils.createToken({ sub: user.user, exp: expiresIn, src: source, scp: ares.scope });
  const uuid = jwt.decode(code).jti;

  tp.sql("EXEC wsp_RestApiAuthorisationCodesInsert \
            @uuid = '" + uuid + "', \
            @expires = '" + expires + "', \
            @scopes = '" + client.scope + "', \
            @client = " + client.client + ", \
            @user = " + user.user + ", \
            @website = " + eCommerceWebsite + ", \
            @redirectUri = '" + redirectURI + "'")
    .execute()
    .then(() => {
      if (ares.hasOwnProperty('response') && ares.response == 'ajax') {
        done(null, JSON.stringify({ code: code, response: "ajax" }))
      } else {
        done(null, code)
      }
    })
    .catch(err => done(err, false));

}));

/**
 * This function is reponsible for exchanging authorisation codes for
 * access tokens. We first check the validity of the authorisation
 * code then issue the access token if all is well.
 */
server.exchange(oauth2orize.exchange.code((client, code, redirectURI, done) => {
  const uuid = jwt.decode(code).jti;
  const source = jwt.decode(code).src;
  const scope = jwt.decode(code).scp;
  const tokenId = 0;

  tp.sql("EXEC wsp_RestApiAuthorisationCodesSelect @uuid = '" + uuid + "'")
    .execute()
    .then(function (authorisationCodes) {

      const dbAuthorisationCode = {
        "client": authorisationCodes[0].RestApiClient,
        "RedirectURI": authorisationCodes[0].RedirectURI,
        "user": authorisationCodes[0].RestApiUser,
        "scope": scope,
        "source": source,
        "website": authorisationCodes[0].EcommerceWebsite
      };

      if (source == "swagger") {
        dbAuthorisationCode.accessTokenLifetime = config.token.expiresIn;
      } else {
        dbAuthorisationCode.accessTokenLifetime = 31536000;
      }

      tp.sql("EXEC wsp_RestApiAuthorisationCodesDelete @uuid = '" + uuid + "'")
        .execute()
        .catch(err => done(err, false, false));

      return dbAuthorisationCode;
    })
    .then(dbAuthorisationCode => validate.authCode(code, dbAuthorisationCode, client, redirectURI))
    .then(authCode => validate.generateToken(authCode))
    .then((token) => {
      if (token.hasOwnProperty('token')) {
        const params = {
          "expires": token.expires,
          "id": tokenId
        }
        return done(null, token.token, false, params);
      }
      throw new Error('Error exchanging auth code for tokens');
    })
    .catch(err => done(err, false, false));
}));

/**
 * This endpoint checks to make sure the user is logged in,
 * all of the requested scopes exist, the client exists and is assigned to the user, 
 * and the client has been granted permission to use the requested scopes.
 * If all of the above is true, an authorisation code is issued which can then
 * be exchanged for an access token.
 */
exports.authorization = [
  login.ensureLoggedIn(),
  server.authorization((RestApiClientId, redirectURI, scope, done) => {

    tp.sql("EXEC wsp_RestApiClientsVerify @length = " + String(scope).split(",").length + ", @scopes = '" + scope + "', @clientId = '" + RestApiClientId + "'")
      .execute()
      .then((clients) => {
        if (clients[0] == null) {

          let err = new Error('Client does not exist or does not have permission to use selected scopes.');

          return done(err, false, '/oauth2redirect');
        } else if (clients[0].hasOwnProperty('ErrorMessage')) {
          let err = new Error(clients[0].ErrorMessage);
          return done(err, false, '/oauth2redirect');
        }

        const client = {
          'client': clients[0].RestApiClient,
          'clientId': clients[0].RestApiClientId,
          'clientSecret': clients[0].Secret,
          'scope': clients[0].Scopes,
          'redirectURI': clients[0].RedirectURI
        };

        if (redirectURI != client.redirectURI) {
          let err = new Error('RedirectURI wrong.');
          return done(err, false, '/oauth2redirect');
        }

        return done(null, client, redirectURI);
      })
      .catch(err => done(err, false, 'login'));
  }),
  (req, res, next) => {
    /**
     * Traditionally, we would render a 'decision' page here (i.e. a page like
     * '<application name> is requesting access to your account, do you want
     * to allow this?'), but we handle this internally so don't render anything.
     * Instead, simply send the response.
     */
    server.decision({ loadTransaction: false }, (serverReq, callback) => {
      let response = '';

      if (req.query.hasOwnProperty('response')) {
        response = req.query.response;
      }
      callback(null, { allow: true, scope: req.query.scope, response: response, website: req.query.website });
    })(req, res, next);
  }

];

/**
 * The token endpoint is responsible for exchanging an authorisation code
 * for an access token. The client must be authenticated first.
 */
exports.token = [
  passport.authenticate('oauth2-client-password', { session: true }),
  server.token(),
  server.errorHandler(),
];

/**
 * The complete process of issuing an access token involves multiple HTTPS
 * request/response exchanges, so we need to store client data in the session.
 */

/**
 * Write the client data to the session.
 */
server.serializeClient((client, done) => done(null, client.client));

/**
 * Read the client data from the session.
 */
server.deserializeClient((RestApiClient, done) => {
  tp.sql("EXEC wsp_RestApiClientsSelect @client = " + RestApiClient)
    .execute()
    .then(function (clients) {
      if (clients.length > 0) {
        const client = {
          "client": clients[0].RestApiClient,
          "clientId": clients[0].RestApiClientId,
          "clientSecret": clients[0].Secret,
          "scope": clients[0].Scopes
        };
        return done(null, client);
      } else {
        const err = new Error("No user found with supplied user number.");
        return done(err, false);
      }
    })
    .catch(err => done(err, false));
});
