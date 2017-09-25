'use strict';

const passport = require('passport');
const { Strategy: LocalStrategy } = require('passport-local');
const { BasicStrategy } = require('passport-http');
const { Strategy: ClientPasswordStrategy } = require('passport-oauth2-client-password');
const { Strategy: BearerStrategy } = require('passport-http-bearer');
const validate = require('./validate');
const jwt = require('jsonwebtoken');
const config = require('./config');
const bcrypt = require('bcrypt');
const logger = require('./middleware/logger');
const utils = require('./utils');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');
const env = process.env.NODE_ENV || 'development';

exports.system = (req) => {
  if (typeof req.session.system != 'undefined' && req.session.system === 'training') {
    tp.setConnectionConfig(config.connectionTraining);
  } else {
    tp.setConnectionConfig(config.connection);
  }
  validate.system(req);
}

function cryptPassword(password, callback) {
  bcrypt.genSalt(10, function (err, salt) {
    if (err)
      return callback(err);

    bcrypt.hash(password, salt, function (err, hash) {
      return callback(err, hash);
    });
  });
};

function comparePassword(plainPass, hashword, callback) {
  bcrypt.compare(plainPass, hashword, function (err, isPasswordMatch) {
    return err == null ?
      callback(null, isPasswordMatch) :
      callback(err);
  });
};

/**
 * LocalStrategy
 *
 * This strategy is used to authenticate users based on a username and password.
 * Anytime a request is made to authorize an application, we must ensure that
 * a user is logged in before asking them to approve the request.
 */
passport.use(new LocalStrategy({ passReqToCallback: true }, (req, RestApiUserId, Password, done) => {
  req.session.system = (req.body.system === 'training') ? 'training' : 'live';

  this.system(req);

  let message = 'There was a problem logging you in . Please try again. If the problem persists, please contact WinMan Support.';

  if ('development' == env) {

  }

  tp.sql("EXEC wsp_RestApiUsersSelect @userId = '" + RestApiUserId + "'")
    .execute()
    .then(function (users) {

      if (users.length > 0) {
        const dbUser = {
          "id": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };

        comparePassword(Password, users[0].Password, function (err, match) {
          if (match) {
            return done(null, dbUser);
          } else if (err) {
            message = ('development' == env) ? err.stack : message;
            return done(err, false, req.flash('message', message));
          } else {
            message = ('development' == env) ? 'Incorrect password entered.' : 'Incorrect username or password entered. Please try again';
            return done(null, false, req.flash('message', message));
          }
        });
      } else {
        message = ('development' == env) ? 'Username not found.' : 'Incorrect username or password entered. Please try again';
        return done(null, false, req.flash('message', message));
      }

    })
    .catch(err => {
      const message = ('development' == env) ? err.stack : 'Log in error. Please contact WinMan Support.';
      return done(null, false, req.flash('message', message));
    });

}));

/**
 * BasicStrategy & ClientPasswordStrategy
 *
 * These strategies are used to authenticate registered OAuth clients.  They are
 * employed to protect the `token` endpoint, which consumers use to obtain
 * access tokens.  The OAuth 2.0 specification suggests that clients use the
 * HTTP Basic scheme to authenticate.  Use of the client password strategy
 * allows clients to send the same credentials in the request body (as opposed
 * to the `Authorization` header).  While this approach is not recommended by
 * the specification, in practice it is quite common.
 */
passport.use(new BasicStrategy({ passReqToCallback: true }, (req, RestApiClientId, Secret, done) => {
  if (typeof req.body.system !== 'undefined') {
    req.session.system = req.body.system;
  }
  
  this.system(req);

  tp.sql("EXEC wsp_RestApiClientsSelect @clientId = '" + RestApiClientId + "'")
    .execute()
    .then(function (clients) {

      const dbClient = {
        "id": clients[0].RestApiClient,
        "clientId": clients[0].RestApiClientId,
        "clientSecret": clients[0].Secret,
        "scope": clients[0].Scopes
      };

      if (dbClient.clientSecret !== Secret) {
        return done(null, false, req.flash('message', 'secret wrong'));
      } else {
        return done(null, dbClient);
      }
    })
    .catch(() => done(null, false, req.flash('message', 'something bad happened')));

}));

/**
 * Client Password strategy
 *
 * The OAuth 2.0 client password authentication strategy authenticates clients
 * using a client ID and client secret. The strategy requires a verify callback,
 * which accepts those credentials and calls done providing a client.
 */
passport.use(new ClientPasswordStrategy({ passReqToCallback: true }, (req, RestApiClientId, Secret, done) => {
  if (typeof req.body.system !== 'undefined') {
    req.session.system = req.body.system;
  }
  
  this.system(req);

  tp.sql("EXEC wsp_RestApiClientsSelect @clientId = '" + RestApiClientId + "'")
    .execute()
    .then(function (clients) {

      const dbClient = {
        "id": clients[0].RestApiClient,
        "clientId": clients[0].RestApiClientId,
        "clientSecret": clients[0].Secret,
        "scope": clients[0].Scopes
      };

      if (dbClient.clientSecret !== Secret) {
        return done(null, false, req.flash('message', 'secret wrong'));
      } else {
        return done(null, dbClient);
      }

    })
    .catch(err => done(null, false, req.flash('message', err.message)));
}));

/**
 * BearerStrategy
 *
 * This strategy is used to authenticate either users or clients based on an access token
 * (aka a bearer token).  If a user, they must have previously authorized a client
 * application, which is issued an access token to make requests on behalf of
 * the authorizing user.
 *
 * To keep this example simple, restricted scopes are not implemented, and this is just for
 * illustrative purposes
 */
passport.use(new BearerStrategy((accessToken, done) => {
  const uuid = jwt.decode(accessToken).jti;
  const allowedScopes = jwt.decode(accessToken).scp;

  tp.sql("EXEC wsp_RestApiAccessTokensSelect @uuid = '" + uuid + "'")
    .execute()
    .then(function (tokens) {
      if (tokens.length > 0) {
        const dbAccessToken = {
          "userID": tokens[0].RestApiUser,
          "expirationDate": tokens[0].Expires,
          "clientID": tokens[0].RestApiClient,
          "scope": tokens[0].Scopes
        };

        return validate.token(dbAccessToken, accessToken);
      } else {
        const err = new Error("No matching access token found.");
        return done(err, false);
      }
    })
    .then(token => done(null, token, { scope: allowedScopes }))
    .catch(err => done(err, false));
}));

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

passport.serializeUser((user, done) => {
  done(null, user.id);
});

passport.deserializeUser((req, RestApiUser, done) => {
  tp.sql("EXEC wsp_RestApiUsersSelect @user = " + RestApiUser)
    .execute()
    .then(function (users) {
      if (users.length > 0) {
        const user = {
          "id": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };
        return done(null, user);
      } else {
        const err = new Error("No user found with supplied user number.");
        return done(err, false);
      }
    })
    .catch(err => done(err, false));
});
