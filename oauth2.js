'use strict';

// Register supported grant types.
//
// OAuth 2.0 specifies a framework that allows users to grant client
// applications limited access to their protected resources.  It does this
// through a process of the user granting access, and the client exchanging
// the grant for an access token.

const config = require('./config');
const login = require('connect-ensure-login');
const oauth2orize = require('oauth2orize');
const server = oauth2orize.createServer();
const passport = require('passport');
const utils = require('./utils');
const validate = require('./validate');
const jwt = require('jsonwebtoken');
const tp = require('tedious-promises');

exports.system = (req) => {
  if (typeof req.session.system != 'undefined' && req.session.system === 'training') {
    tp.setConnectionConfig(config.connectionTraining);
  } else {
    tp.setConnectionConfig(config.connection);
  }
  validate.system(req);
}

/**
 * Grant authorization codes
 *
 * The callback takes the `client` requesting authorization, the `redirectURI`
 * (which is used as a verifier in the subsequent exchange), the authenticated
 * `user` granting access, and their response, which contains approved scope,
 * duration, etc. as parsed by the application.  The application issues a code,
 * which is bound to these values, and will be exchanged for an access token.
 */
server.grant(oauth2orize.grant.code((client, redirectURI, user, ares, done) => {
  const expires = config.codeToken.calculateExpirationDate();
  const expiresIn = parseInt(Date.parse(expires) / 1000);
  let source = "swagger";

  if (ares.hasOwnProperty('response') && ares.response == 'ajax') {
    source = "account";
  }

  const code = utils.createToken({ sub: user.id, exp: expiresIn, src: source, scp: ares.scope });
  const uuid = jwt.decode(code).jti;

  tp.sql("EXEC wsp_RestApiAuthorisationCodesInsert \
            @uuid = '" + uuid + "', \
            @expires = '" + expires + "', \
            @scopes = '" + client.scope + "', \
            @client = " + client.id + ", \
            @user = " + user.id + ", \
            @redirectUri = '" + redirectURI + "'")
    .execute()
    .then(() => {
      if (ares.hasOwnProperty('response') && ares.response == 'ajax') {
        done(null, JSON.stringify({ code: code, response: "ajax" }))
      } else {
        done(null, code)
      }
    })
    .fail(err => done(err, false));

}));

/**
 * Exchange authorization codes for access tokens.
 *
 * The callback accepts the `client`, which is exchanging `code` and any
 * `redirectURI` from the authorization request for verification.  If these values
 * are validated, the application issues an access token on behalf of the user who
 * authorized the code.
 */
server.exchange(oauth2orize.exchange.code((client, code, redirectURI, done) => {
  const uuid = jwt.decode(code).jti;
  const source = jwt.decode(code).src;
  const scope = jwt.decode(code).scp;

  tp.sql("EXEC wsp_RestApiAuthorisationCodesSelect @uuid = '" + uuid + "'")
    .execute()
    .then(function (authorisationCodes) {

      const dbAuthorisationCode = {
        "client": authorisationCodes[0].RestApiClient,
        "RedirectURI": authorisationCodes[0].RedirectURI,
        "user": authorisationCodes[0].RestApiUser,
        "scope": scope,
        "source": source
      };

      if (source == "swagger") {
        dbAuthorisationCode.lifetime = 3600
      } else {
        dbAuthorisationCode.lifetime = 31536000
      }

      tp.sql("EXEC wsp_RestApiAuthorisationCodesDelete @uuid = '" + uuid + "'")
        .execute()
        .fail(err => done(err, false, false));

      return dbAuthorisationCode;

    })
    .then(dbAuthorisationCode => validate.authCode(code, dbAuthorisationCode, client, redirectURI))
    .then(authCode => validate.generateToken(authCode))
    .then((token) => {
      if (token.hasOwnProperty('token')) {
        const params = {
          "expires": token.expires
        }
        return done(null, token.token, false, params);
      }
      throw new Error('Error exchanging auth code for tokens');
    })
    .fail(err => done(err, false, false));
}));

/*
 * User authorization endpoint
 *
 * `authorization` middleware accepts a `validate` callback which is
 * responsible for validating the client making the authorization request.  In
 * doing so, is recommended that the `redirectURI` be checked against a
 * registered value, although security requirements may vary accross
 * implementations.  Once validated, the `done` callback must be invoked with
 * a `client` instance, as well as the `redirectURI` to which the user will be
 * redirected after an authorization decision is obtained.
 *
 * This middleware simply initializes a new authorization transaction.  It is
 * the application's responsibility to authenticate the user and render a dialog
 * to obtain their approval (displaying details about the client requesting
 * authorization).  We accomplish that here by routing through `ensureLoggedIn()`
 * first, and rendering the `dialog` view.
 */
exports.authorization = [
  login.ensureLoggedIn(),
  server.authorization((RestApiClientId, redirectURI, scope, done) => {
    // This SP checks to make sure all of the requested scopes exist,
    // the client exists and is assigned to the user, 
    // and the client has been granted permission to use the requested scopes.

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
          'id': clients[0].RestApiClient,
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
    server.decision({ loadTransaction: false }, (serverReq, callback) => {
      let response = '';
      if (req.query.hasOwnProperty('response')) {
        response = req.query.response;
      }
      callback(null, { allow: true, scope: req.query.scope, response: response });
    })(req, res, next);
  }

];

/**
 * User decision endpoint
 *
 * `decision` middleware processes a user's decision to allow or deny access
 * requested by a client application.  Based on the grant type requested by the
 * client, the above grant middleware configured above will be invoked to send
 * a response.
 */
exports.decision = [
  login.ensureLoggedIn(),
  server.decision(),
];

/**
 * Token endpoint
 *
 * `token` middleware handles client requests to exchange authorization grants
 * for access tokens.  Based on the grant type being exchanged, the above
 * exchange middleware will be invoked to handle the request.  Clients must
 * authenticate when making requests to this endpoint.
 */
exports.token = [
  passport.authenticate(['basic', 'oauth2-client-password'], { session: true }),
  server.token(),
  server.errorHandler(),
];

// Register serialialization and deserialization functions.
//
// When a client redirects a user to user authorization endpoint, an
// authorization transaction is initiated.  To complete the transaction, the
// user must authenticate and approve the authorization request.  Because this
// may involve multiple HTTPS request/response exchanges, the transaction is
// stored in the session.
//
// An application must supply serialization functions, which determine how the
// client object is serialized into the session.  Typically this will be a
// simple matter of serializing the client's ID, and deserializing by finding
// the client by ID from the database.

server.serializeClient((client, done) => done(null, client.id));

server.deserializeClient((RestApiClient, done) => {
  tp.sql("EXEC wsp_RestApiClientsSelect @client = " + RestApiClient) // TODO: use stored proecures instead of inline qry.
    .execute()
    .then(function (clients) {
      if (clients.length > 0) {
        const client = {
          "id": clients[0].RestApiClient,
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
    .fail(err => done(err, false));
});
