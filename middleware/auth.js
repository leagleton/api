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
 * 'passport' and its various strategies are used for authentication.
 * 'validate' refers to one of our own middleware scripts, used for validating tokens.
 * 'jwt' is used to create tokens.
 * 'config' refers to our application's config settings.
 * 'bcrypt' is used for password encryption for the API portal.
 * 'logger' refers to one of our own middleware scripts, used to define our custom logging functions.
 * 'tp' is used for executing SQL queries.
 */
const passport = require('passport');
const { Strategy: LocalStrategy } = require('passport-local');
const { Strategy: ClientPasswordStrategy } = require('passport-oauth2-client-password');
const { Strategy: BearerStrategy } = require('passport-http-bearer');
const validate = require('./validate');
const jwt = require('jsonwebtoken');
const config = require('../config');
const bcrypt = require('bcrypt');
const logger = require('./logger');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/** 
 * Determine which mode we're running in - production or development. 
 */
const env = process.env.NODE_ENV || 'development';

/**
 * Set which system is in use - training or live.
 * 
 * @param {Object} req - The request.
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
 * Encrypt the user's password ready for storing in the DB.
 * 
 * @param {String}    password - The plain text password submitted from the browser.
 * @param {Callback}  callback - The callback function 
 */
exports.cryptPassword = (password, callback) => {
  bcrypt.genSalt(10, function (err, salt) {
    if (err) {
      return callback(err);
    }

    bcrypt.hash(password, salt, function (err, hash) {
      return callback(err, hash);
    });
  });
};

/**
 * Hash the submitted password and compare it to our stored password hash.
 * If the two match, the user can log in, otherwise return an error.
 * 
 * @param {String}    plainPass - The plain text password submitted from the browser.
 * @param {String}    hashword  - The hashed password from the DB.
 * @param {Callback}  callback  - The callback function.
 */
exports.comparePassword = (plainPass, hashword, callback) => {
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
 * We use this for logging the user in to the API portal.
 */
passport.use(new LocalStrategy({ passReqToCallback: true }, (req, RestApiUserId, Password, done) => {
  req.session.system = (req.body.system === 'training') ? 'training' : 'live';

  this.system(req);

  let message = 'There was a problem logging you in. Please try again. If the problem persists, please contact WinMan Support.';

  tp.sql("EXEC wsp_RestApiUsersSelect @userId = '" + RestApiUserId + "'")
    .execute()
    .then((users) => {

      if (users.length > 0) {
        const dbUser = {
          "user": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };

        this.comparePassword(Password, users[0].Password, function (err, match) {
          if (match) {
            return done(null, dbUser);
          } else if (err) {
            message = (env == 'development') ? err.stack : message;
            logger.error(message);
            return done(null, false, req.flash('message', message));
          } else {
            message = (env == 'development') ? 'Incorrect password entered.' : 'Incorrect username or password entered. Please try again';
            return done(null, false, req.flash('message', message));
          }
        });
      } else {
        message = (env == 'development') ? 'Username not found.' : 'Incorrect username or password entered. Please try again';
        return done(null, false, req.flash('message', message));
      }

    })
    .catch(err => {
      const message = (env == 'development') ? err.stack : 'Log in error. Please contact WinMan Support.';
      return done(null, false, req.flash('message', message));
    });

}));

/**
 * Client Password strategy
 *
 * This is used to authenticate the client via client ID and client secret.
 * We use this on the API dashboard (when the Authorise button is clicked)
 * and on the API account screen (when the Get Token button is clicked).
 */
passport.use(new ClientPasswordStrategy({ passReqToCallback: true }, (req, RestApiClientId, Secret, done) => {
  if (typeof req.body.system !== 'undefined') {
    req.session.system = req.body.system;
  }

  let user = 0;
  if (typeof req.user !== 'undefined') {
    user = req.user.user
  }

  this.system(req);

  tp.sql("EXEC wsp_RestApiClientsSelect @clientId = '" + RestApiClientId + "'")
    .execute()
    .then(function (clients) {

      const dbClient = {
        "user": user,
        "client": clients[0].RestApiClient,
        "clientId": clients[0].RestApiClientId,
        "clientSecret": clients[0].Secret,
        "scope": clients[0].Scopes
      };

      if (dbClient.clientSecret !== Secret) {
        return done(null, false);
      } else {
        return done(null, dbClient);
      }

    })
    .catch(err => {
      logger.error(err);
      return done(null, false);
    });
}));

/**
 * BearerStrategy
 *
 * This strategy is used to authenticate the user and client based on an access token
 * (a.k.a. a bearer token). We use this to protect our endpoints.
 */
passport.use(new BearerStrategy({ passReqToCallback: true }, (req, accessToken, done) => {
  if (typeof req.res.locals.system !== 'undefined') {
    req.session.system = req.res.locals.system;
  }

  this.system(req);

  const decodedToken = jwt.decode(accessToken);

  if (decodedToken === null) {
    const err = new Error('Unable to decode access token. Access token may be invalid.');
    logger.error(err);
    return done(null, false);
  }

  const uuid = jwt.decode(accessToken).jti;
  const allowedScopes = jwt.decode(accessToken).scp;
  let eCommerceWebsite = '';

  if (req.body.hasOwnProperty('Data')) {
    eCommerceWebsite = req.body.Data.Website;
  } else {
    eCommerceWebsite = req.res.locals.website;
  }

  tp.sql("EXEC wsp_RestApiAccessTokensSelect @uuid = '" + uuid + "', @website = '" + eCommerceWebsite + "'")
    .execute()
    .then(function (tokens) {
      if (tokens.length > 0) {
        const dbAccessToken = {
          "userID": tokens[0].RestApiUser,
          "expirationDate": tokens[0].Expires,
          "clientID": tokens[0].RestApiClient,
          "scope": tokens[0].Scopes,
          "website": tokens[0].EcommerceWebsite
        };

        return validate.token(dbAccessToken, accessToken);
      } else {
        const err = new Error('No matching access token found.');
        logger.error(err);
        return done(null, false);
      }
    })
    .then(token => done(null, token, { scope: allowedScopes }))
    .catch(err => {
      logger.error(err);
      return done(null, false);
    });
}));

/**
 * Authenticating users may involve multiple HTTPS request/response exchanges,
 * so we store the user's info in the session
 */

/**
 * Write the user's data to the session.
 */
passport.serializeUser((user, done) => {
  if (user.user === 0) {
    delete user.user;
  }
  return done(null, user);
});

/**
 * Read the user's data from the session.
 */
passport.deserializeUser((req, user, done) => {
  tp.sql("EXEC wsp_RestApiUsersSelect @user = " + user.user)
    .execute()
    .then(function (users) {
      if (users.length > 0) {
        const user = {
          "user": users[0].RestApiUser,
          "username": users[0].RestApiUserId,
          "name": users[0].Name
        };
        return done(null, user);
      } else {
        const err = new Error("No user found with supplied user number.");
        logger.error(err);
        return done(null, false);
      }
    })
    .catch(err => {
      logger.error(err);
      return done(null, false);
    });
});
