'use strict';

const login = require('connect-ensure-login');
const passport = require('passport');
const version = require('./package.json').version;
const utils = require('./utils');
const auth = require('./auth');
const config = require('./config');
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
 * Render the main documentation page after ensuring the user is logged in.
 * @param   {Object} req - The request
 * @param   {Object} res - The response
 * @returns {undefined}
 */
exports.index = [
  login.ensureLoggedIn(),
  (req, res) => {
    res.render('index', {
      session: req.sessionID
    });
  },
];

/**
 * Render the oauth2 redirect page.
 * @param   {Object} req - The request
 * @param   {Object} res - The response
 * @returns {undefined}
 */
exports.oauth2redirect = (req, res) => {
  try {
    const query = JSON.parse(req.query.code);
    res.send(query.code);
  }
  catch (e) {
    res.render('oauth2redirect');
  }
};

/**
 * Render the login page.
 * @param   {Object} req - The request
 * @param   {Object} res - The response
 * @returns {undefined}
 */
exports.loginForm = (req, res) => {
  if (req.user) {
    res.redirect('/');
  } else {
    res.render('login', {
      message: req.flash('message'),
      title: 'Log In',
      version: version
    });
  }
};

/**
 * Authenticate normal login page using strategy of authenticate
 */
exports.login = [
  passport.authenticate('local', { successRedirect: '/', failureRedirect: '/login', failureFlash: true }),
];

/**
 * Log out of the system and redirect to home page.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
 */
exports.logout = (req, res) => {
  req.session.destroy(function (err) {
    res.clearCookie('authorisation.sid', { path: '/' });
    req.logout();
    res.redirect('/');
  });
};

/**
 * Render account.ejs but ensure the user is logged in before rendering.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
 */
exports.account = [
  login.ensureLoggedIn(),
  (req, res) => {
    res.render('account', {
      user: req.user,
      title: 'My Account',
      system: req.session.system,
      sessionId: req.sessionID,
      baseUrl: config.server.host + ":" + config.server.port,
      version: version
    });
  },
];

/**
 * Randomly generate a new client ID and secret but ensure the user is logged in first.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
 */
exports.create = [
  login.ensureLoggedIn(),
  (req, res, next) => {
    const clientId = utils.generateString(32);
    const clientSecret = utils.generateString(32);
    let client = 0;

    tp.sql("DECLARE @client BIGINT EXEC wsp_RestApiClientsInsert \
              @clientId = '" + clientId + "', \
              @secret = '" + clientSecret + "', \
              @redirectUri = '" + config.server.scheme + "://" + config.server.host + ":" + config.server.port + "/" + "oauth2redirect', \
              @user = " + req.user.id + ", \
              @scopes = '" + req.query.scopes + "', \
              @client = @client OUTPUT")
      .execute()
      .then((results) => client = results[0].client)
      .then(() => res.send({ client, clientId, clientSecret, scopes: req.query.scopes }))
      .catch(err => next(err));
  },
];

/**
 * Fetch scopes from DB to display on account page.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
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
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
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
      // Select all clients for the specified user.
      tp.sql("EXEC wsp_RestApiClientsSelect @user = " + req.user.id)
        .execute()
        .then((results) => res.send(results))
        .catch(err => next(err));
    }
  }
];

/**
 * Fetch access tokens from DB to display on account page.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
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
      // Select all access tokens for the specified user.
      tp.sql("EXEC wsp_RestApiUserAccessTokensSelect @user = " + req.user.id)
        .execute()
        .then((results) => res.send(results))
        .catch(err => next(err));
    }
  }
];

/**
 * Change the password of a REST API User.
 * @param   {Object}   req - The request
 * @param   {Object}   res - The response
 * @returns {undefined}
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
                    tp.sql("EXEC wsp_RestApiUsersUpdate @user = " + req.user.id + ", @password = '" + hash + "'")
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
