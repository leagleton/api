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
 * 'login' is used to make sure the user is loggged in.
 * 'passport' is used for authentication.
 * 'version' refers to the application's version number in the config file.
 * 'utils' refers to our custom functions for handling tokens.
 * 'auth' refers to our custom authentication functions.
 * 'config' refers to our application's config settings.
 * 'logger' is used to define our custom logging functions.
 * 'tp' is used for executing SQL queries.
 */
const login = require('connect-ensure-login');
const passport = require('passport');
const version = require('../package.json').version;
const utils = require('./utils');
const auth = require('./auth');
const config = require('../config');
const logger = require('./logger');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

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
}

/**
 * Render the API dashboard after ensuring the user is logged in.
 * Pass the session ID to the page so that we can fetch the relevant
 * Swagger schema.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.index = [
  login.ensureLoggedIn(),
  (req, res) => {
    res.render('index', {
      session: req.sessionID,
      apiName: config.service.displayName,
      title: 'Dashboard'
    });
  },
];

/**
 * Render the oauth2 redirect page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.oauth2redirect = (req, res) => {
  try {
    const query = JSON.parse(req.query.code);
    res.send(query.code);
  } catch (e) {
    res.render('oauth2redirect');
  }
};

/**
 * Render the login page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.loginForm = (req, res) => {
  if (req.user) {
    res.redirect('/');
  } else {
    res.render('login', {
      message: req.flash('message'),
      title: 'Log In',
      version: version,
      apiName: config.service.displayName,
      mode: config.mode
    });
  }
};

/**
 * Authenticate normal login page using PassportJS 'local' strategy.
 */
exports.login = [
  passport.authenticate('local', { successRedirect: '/', failureRedirect: '/login', failureFlash: true }),
];

/**
 * Log out of the system and redirect to home page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.logout = (req, res) => {
  req.session.destroy(function (err) {
    res.clearCookie('authorisation.sid', { path: '/' });
    req.logout();
    res.redirect('/');
  });
};

/**
 * Render account page but ensure the user is logged in first.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.account = [
  login.ensureLoggedIn(),
  (req, res) => {
    res.render('account', {
      user: req.user,
      title: 'Account Screen',
      system: req.session.system,
      sessionId: req.sessionID,
      scheme: config.server.scheme,
      baseUrl: config.server.host + ":" + config.server.port,
      baseEnd: (req.session.system === 'training') ? 'training' : 'api',
      version: version,
      apiName: config.service.displayName,
      mode: config.mode
    });
  },
];

/**
 * Randomly generate a new client ID and secret but ensure the user is logged in first.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.create = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    const clientId = utils.generateString(32);
    const clientSecret = utils.generateString(32);
    const redirectUri = config.server.scheme + "://" + config.server.host + ":" + config.server.port + "/" + "oauth2redirect"
    let client = 0;

    tp.sql("DECLARE @client BIGINT EXEC wsp_RestApiClientsInsert \
              @clientId = '" + clientId + "', \
              @secret = '" + clientSecret + "', \
              @redirectUri = '" + redirectUri + "', \
              @user = " + req.user.user + ", \
              @scopes = '" + req.query.scopes + "', \
              @client = @client OUTPUT")
      .execute()
      .then((results) => client = results[0].client)
      .then(() => res.send({ client, clientId, clientSecret, redirectUri, scopes: req.query.scopes }))
      .catch(err => next(err));
  },
];

/**
 * Fetch scopes from DB to display on account page.
 * 
 * @param {Object} req - The request.
 * @param {Object}  res - The response.
 */
exports.scopes = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    tp.sql("EXEC wsp_RestApiScopesSelect")
      .execute()
      .then((results) => res.send(results))
      .catch(err => next(err));
  },
];

/**
 * Fetch clients from DB to display on account page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.clients = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    if (req.query.action == 'delete') {
      tp.sql("EXEC wsp_RestApiClientsDelete @client = " + req.query.client)
        .execute()
        .then(() => res.send("Success"))
        .catch(err => next(err));
    } else {
      tp.sql("EXEC wsp_RestApiClientsSelect @user = " + req.user.user)
        .execute()
        .then((results) => res.send(results))
        .catch(err => next(err));
    }
  }
];

/**
 * Fetch access token information from DB to display on account page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.userAccessTokens = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    if (req.query.action == 'delete') {
      tp.sql("EXEC wsp_RestApiUserAccessTokensDelete @token = " + req.query.token)
        .execute()
        .then(() => res.send("Success"))
        .catch(err => next(err));
    } else {
      tp.sql("EXEC wsp_RestApiUserAccessTokensSelect @user = " + req.user.user)
        .execute()
        .then((results) => res.send(results))
        .catch(err => next(err));
    }
  }
];

/**
 * Fetch eCommerce websites from DB to display on account page.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.websites = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    tp.sql("EXEC wsp_RestApiEcommerceWebsitesSelect @user = " + req.user.user)
      .execute()
      .then((results) => res.send(results))
      .catch(err => next(err));
  }
];

/**
 * Change the password of a REST API User.
 * 
 * @param {Object} req - The request.
 * @param {Object} res - The response.
 */
exports.passwordChange = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    tp.sql("EXEC wsp_RestApiUsersSelect @userId = '" + req.user.username + "'")
      .execute()
      .then((users) => {
        if (users.length > 0) {
          auth.comparePassword(req.query.currentPassword, users[0].Password, function (err, match) {
            if (match) {
              if (req.query.currentPassword === req.query.newPassword) {
                res.send('New and current match.');
              } else {
                auth.cryptPassword(req.query.newPassword, function (err, hash) {
                  if (hash) {
                    tp.sql("EXEC wsp_RestApiUsersUpdate @user = " + req.user.user + ", @password = '" + hash + "'")
                      .execute()
                      .then(() => res.send('Success.'))
                      .catch(err => next(err));
                  } else if (err) {
                    throw new Error(err.message);
                  }
                })
              }
            } else if (err) {
              throw new Error(err.message);
            } else {
              res.send('Password incorrect.');
            }
          });
        } else {
          throw new Error('User not found.');
        }
      })
      .catch(err => next(err));
  }
];
