/** 
 * Enable strict mode. See:
 * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
 * for more information.
 */
'use strict';

/** 
 * Set the correct directory for the Windows service. 
 */
process.chdir(__dirname)

/** 
 * Determine which mode we're running in - production or development. 
 */
const env = process.env.NODE_ENV || 'development';

/** 
 * Initilaise required node modules. Similar to
 * 'Imports <namespace>' statements in VB.NET.
 * 
 * 'service' is used to run the application as a Windows service.
 * 'fs' is used to interact with the file system.
 */
const service = require("os-service");
const fs = require('fs');

/** 
 * Import the application's config settings and set memory usage parameters. 
 */
const config = require('./config');
const version = require('./package.json').version;
const serviceName = config.service.serviceName;
const options = {
    displayName: config.service.displayName,
    programArgs: ["--run",
        "--max-old-space-size=48",
        "--max-executable-size=64",
        "--max-semi-space-size=1"]
};

/**
 * Show usage hints on command line if app called improperly.
 */
function usage() {
    console.log("\x1b[33mUsage: \x1b[37mnode winman-rest \x1b[36m[option]");
    console.log(" ");
    console.log("\x1b[33mOptions:");
    console.log("\x1b[36m  -v, --version   \x1b[37mPrint your " + options.displayName + " version number.");
    console.log("\x1b[36m  -a, --add       \x1b[37mAdd the " + options.displayName + " as a Windows service. Requires admin privileges.");
    console.log("\x1b[36m  -d, --delete    \x1b[37mDelete/remove the " + options.displayName + " service from Windows. Requires admin privileges.");
    console.log("\x1b[36m  -r, --run       \x1b[37mRun the " + options.displayName + " service.");
    process.exit(0);
}

/**
 * Show API version number on command line.
 */
function showVersion() {
    console.log("\x1b[33mv" + require('./package.json').version + "\x1b[37m");
}

/**
 * Show error on command line.
 */
function showError(error) {
    if (env == 'development') {
        /** 
         * We're in development mode, so show the full stack trace. 
         */
        console.trace("\x1b[31m" + error + "\x1b[37m");
    } else {
        /** 
         * We're in production mode, so only show the error message. 
         */
        console.log("\x1b[31m" + error.message + "\x1b[37m");
    }
}

if (process.argv[2] == "-v" || process.argv[2] == "--version") {
    showVersion();
} else if (process.argv[2] == "-a" || process.argv[2] == "--add") {
    /**
     * Add the API as a Windows service.
     */
    service.add(serviceName, options, function (error) {
        if (error) {
            showError(error);
        } else {
            console.log("\x1b[32m" + options.displayName + " service successfully added.\x1b[37m");
        }
    });
} else if (process.argv[2] == "-d" || process.argv[2] == "--delete") {
    /**
     * Remove the API Windows service.
     */
    service.remove(serviceName, function (error) {
        if (error) {
            showError(error);
        } else {
            console.log("\x1b[32m" + options.displayName + " service successfully removed.\x1b[37m");
        }
    });
} else if (process.argv[2] == "-r" || process.argv[2] == "--run") {
    /** 
     * Define where console.log and console.error write output to. 
     */
    const logStream = fs.createWriteStream("./logs/activityLogs.log");
    const errorStream = fs.createWriteStream("./logs/errorLogs.log");

    /**
     * Attempt to run the API Windows service. If there is an error,
     * make sure the service is stopped.
     */
    service.run(logStream, errorStream, function (error) {
        if (error) {
            showError(error);
        }
        service.stop(0);
    });

    /** 
     * Initilaise required node modules. Similar to
     * 'Imports <namespace>' statements in VB.NET.
     * 
     * 'logger' is used to define our custom logging functions.
     * 'express' is used for routing, i.e. determining which URL goes where.
     * 'compression' is used to enable response body compression.
     * 'bodyParser' is used to enable request body parsing.
     * 'xml2js' is used to enable correct parsing of numbers in XML.
     * 'passport' is used for authentication.
     * 'session' is used to handle our application's sessions.
     * 'path' is used to correctly handle file paths.
     * 'fileStore' is used to handle session file storage.
     */
    const logger = require('./middleware/logger');
    const express = require('express');
    const compression = require('compression');
    const bodyParser = require('body-parser');
    require('body-parser-xml')(bodyParser);
    const xml2js = require('xml2js');
    const passport = require('passport');
    const session = require('express-session');
    const path = require('path');
    const fileStore = require('session-file-store')(session);

    /**
     * We use ExpressJS to handle frontend page rendering.
     * Initialise ExpressJS, define where our static files
     * are held and define which file type is used for our
     * web pages (.ejs).
     */
    const app = express();
    app.use(express.static(path.join(__dirname, 'views/static')));
    app.set('view engine', 'ejs');

    /** 
     * Define parameters for our sessions. 
     */
    app.use(session({
        store: new fileStore({ logFn: logger.log }),
        saveUninitialized: false,
        resave: false,
        secret: config.session.secret,
        name: 'authorisation.sid',
        cookie: { secure: true },
    }));

    /** 
     * Enable gzip compression for response body. 
     */
    app.use(compression());

    /** 
     * Set the necessary HTTP headers. 
     */
    app.use(function (req, res, next) {
        /** 
         * Required to prevent CORS issues.
         */
        res.header('Access-Control-Allow-Origin', '*');

        /** 
         * Required to allow GET, PUT and POST requests. 
         */
        res.header('Access-Control-Allow-Methods', 'GET,PUT,POST');

        /**
         * Required to allow appropriate request headers. 
         */
        res.header('Access-Control-Allow-Headers', 'Content-Type, Access-Control-Allow-Origin, Authorization');

        /**
         * 'next' is ExpressJS's callback function, which passes control
         * on to the next matching route. You will see this quite a lot
         * througout this application.
         */
        next();
    });

    /** 
     * Check that the incoming data is JSON or XML for PUT and POST requests.
     * If something else is used, return a 415 Unsupported Media Type error. 
     */
    const contentType = /^application\/(?:xml|json)(?:[\s;]|$)/i;
    app.use(function (req, res, next) {
        if (req.path.indexOf('/api') !== -1 || req.path.indexOf('/training') !== -1) {
            if ((req.method === 'PUT' || req.method === 'POST') && !contentType.test(req.headers['content-type'])) {
                res.status(415);
                return res.send("The content type of the request must be either JSON or XML. '"
                    + req.headers['content-type'] + "' was detected. Please reformat the request.");
            }
        }
        next();
    });

    /**
     * Load various body parsers so we can read encoded URLs,
     * JSON and XML input from the request body. 
     */
    app.use(bodyParser.urlencoded({ extended: true }));
    app.use(bodyParser.json());
    app.use(bodyParser.xml({
        xmlParseOptions: {
            /** 
             * Parse numbers correctly.
             */
            valueProcessors: [xml2js.processors.parseNumbers],
            /**
             * Only put XML nodes in arrays if there is more than
             * one node with the same name.
             */
            explicitArray: false
        }
    }));

    /**
     * Set which system is in use - training or live
     * for authentication routes. The authentication
     * routes handle things like logging the user in
     * to the API portal and authenticating against
     * access tokens.
     */
    const auth = require('./middleware/auth');
    app.use(function (req, res, next) {
        auth.system(req);
        next();
    });

    /**
     * Set which system is in use - training or live
     * for authorisation routes. The authorisation
     * routes handle things like access token generation
     * and validation, and checking user permissions.
     */
    const oauth2 = require('./middleware/oauth2');
    app.use(function (req, res, next) {
        oauth2.system(req);
        next();
    });

    /**
     * Build the Swagger JSON schema. This schema is
     * what is used to generate the API dashboard.
     */
    const schema = require('./middleware/schema');
    app.use(function (req, res, next) {
        schema.build(req);
        next();
    });

    /**
     * PassportJS is the middleware we use for authentication.
     * It utilises our authentication routes.
     * Initialise PassportJS and start a new session.
     */
    app.use(passport.initialize());
    app.use(passport.session());

    /**
     * Set up the main API routes.
     * /api covers all live endpoints.
     * /training covers all trainig endpoints.
     */
    app.use('/api', function (req, res, next) {
        res.locals = req.query;
        res.locals.system = 'live';
        next();
    }, require('./routes/api'));
    app.use('/training', function (req, res, next) {
        res.locals = req.query;
        res.locals.system = 'training';
        next();
    }, require('./routes/api'));

    /**
     * Enables the use of flash messages in
     * the API portal. E.g. the error message
     * that appears when you enter incorrect
     * login credentials.
     */
    const flash = require('connect-flash');
    app.use(flash());

    /**
     * Set which system is in use - training or live
     * for authorisation routes. The authorisation
     * routes handle things like access token generation
     * and validation, and checking user permissions.
     */
    const site = require('./middleware/site');;
    app.use(function (req, res, next) {
        site.system(req);
        next();
    });

    /**
     * app.get and app.post functions relate to HTTP(S) GET and POST requests.
     * These functions catch these requests and return the appropriate
     * web page.
     */

    /** 
     * Render the API dashboard (API portal home page). 
     */
    app.get('/', site.index);

    /** 
     * Render the API portal login page. 
     */
    app.get('/login', site.loginForm);

    /** 
     * The user has submitted the login form, so attempt to log the user
     * in to the API portal. 
     */
    app.post('/login', site.login);

    /** 
     * Log the user out of the API portal. 
     */
    app.get('/logout', site.logout);

    /** 
     * Render the API account screen. 
     */
    app.get('/account', site.account);

    /** 
     * Create a new client ID and secret. 
     */
    app.get('/create', site.create);

    /** 
     * Fetch user's scopes from DB to display on account page. 
     */
    app.get('/scopes', site.scopes);

    /** 
     * Fetch user's clients from DB to display on account page. 
     */
    app.get('/clients', site.clients);

    /** 
     * Fetch user's eCommerce websites from DB to display on account page. 
     */
    app.get('/userWebsites', site.websites);

    /** 
     * Fetch user's access tokens from DB to display on account page. 
     */
    app.get('/userAccessTokens', site.userAccessTokens);

    /** 
     * Render the oauth2 redirect page. 
     */
    app.get('/oauth2redirect', site.oauth2redirect);

    /** 
     * Change the user's API portal password. 
     */
    app.get('/passwordChange', site.passwordChange);

    /**
     * Authorisation routes, used for access token handling.
     * 
     * '/oauth/auth' is the starting point, where an authorisation code is issued.
     * '/oauth/token' is where the authorisation code is exchanged for an access token.
     */
    app.get('/oauth/auth', oauth2.authorization);
    app.post('/oauth/token', oauth2.token);

    /**
     * Set up HTTPS for our application and define the
     * location of our SSL certificate files.
     */
    const https = require('https');
    const httpsOptions = {
        key: fs.readFileSync('./certs/winman.key'),
        cert: fs.readFileSync('./certs/winman.crt')
    }

    /**
     * Create the web server. This basically makes the application
     * available via URLs rather than just command line on the server.
     */
    const server = https.createServer(httpsOptions, app).listen(config.server.port, '0.0.0.0', function () {
        logger.log('Express server listening on port ' + server.address().port + " in " + app.settings.env + " mode.");
    });

    /**
     * Catch 404 Not Found errors. We can use this to 
     * display custom 404 pages.
     */
    app.use(function (req, res, next) {
        res.status(404).send('404 Not Found: ' + req.method + ": " + req.originalUrl);

        /**
         * The above simply sends a blank page with a plain 404 error message.
         * To render a custom 'pretty' 404 page, use something like the below.
         * 
         * TODO
         */
        //res.render('error', { message: '404 Not Found: ' + req.method + ': ' + req.originalUrl });
    });

    /**
     * Our generic error handler. We can use this to render
     * custom error pages.
     */
    app.use(function (err, req, res, next) {
        if (req.hasOwnProperty('oauth2') && req.oauth2.redirectURI) {
            /**
             * If the request has the property 'oauth2', the error has come from
             * server.authorization, so will only ever be relevant to the oauth2redirect
             * page, which is used during access token handling.
             * Handle these errors by appending an error parameter to the URL.
             */
            res.redirect(req.oauth2.redirectURI + '?error=' + err.message);
        } else {
            /**
             * Log the stack trace for all other errors.
             */
            logger.error(err.stack);
        }
    });

    /** 
     * Catch all unhandled exceptions. 
     * Log the stack trace and shut down the API.
     * There should be a Windows Scheduled Task in place to
     * start it back up again.
     */
    process.on('uncaughtException', function (err) {
        return logger.errorAndExit(5, err.stack);
    });
} else {
    /**
     * If we get here, the user has called the application incorrectly from
     * the command line (or deliberately called the usage help message),
     * so display the usage help message.
     */
    usage();
}
