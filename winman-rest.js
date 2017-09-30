'use strict';

// Required for the Windows Service to run correctly
process.chdir(__dirname)

const env = process.env.NODE_ENV || 'development';
const config = require('./config');
const service = require("os-service");
const fs = require('fs');
const version = require('./package.json').version;
const serviceName = config.service.serviceName;
const options = {
    displayName: config.service.displayName,
    programArgs: ["--run",
        "--max-old-space-size=48",
        "--max-executable-size=64",
        "--max-semi-space-size=1"]
};

// Show usage hints on command line if app called improperly.
function usage() {
    console.log("\x1b[33mUsage: \x1b[37mnode winman-rest \x1b[36m[option] \x1b[32m[arguments]");
    console.log(" ");
    console.log("\x1b[33mOptions:");
    console.log("\x1b[36m  -v, --version   \x1b[37mPrint your WinMan REST API version number.");
    console.log("\x1b[36m  -a, --add       \x1b[37mAdd the WinMan REST API as a Windows service. Requires admin privileges.");
    console.log("\x1b[36m  -d, --delete    \x1b[37mDelete/remove the WinMan REST API service from Windows. Requires admin privileges and restart.");
    //console.log("\x1b[36m  -e, --edit      \x1b[37mEdit the database connection configuration. Requires admin privileges and restarts the service.");
    console.log("\x1b[36m  -r, --run       \x1b[37mRun the WinMan REST API service.");
    process.exit(0);
}

if (process.argv[2] == "-v" || process.argv[2] == "--version") {
    console.log("\x1b[33mv" + require('./package.json').version);
} else if (process.argv[2] == "-a" || process.argv[2] == "--add") {
    service.add(serviceName, options, function (error) {
        if (error)
            if ('development' == env)
                console.trace("\x1b[31m" + error);
            else
                console.log("\x1b[31m" + error.message);
        else
            console.log("\x1b[32m" + options.displayName + " service successfully added.");
    });
} else if (process.argv[2] == "-d" || process.argv[2] == "--delete") {
    service.remove(serviceName, function (error) {
        if (error)
            if ('development' == env)
                console.trace("\x1b[31m" + error);
            else
                console.log("\x1b[31m" + error.message);
        else
            console.log("\x1b[32m" + options.displayName + " service successfully removed.");
    });
//} else if (process.argv[2] == "-e" || process.argv[2] == "--edit") {
//    console.log("\x1b[36mTODO");
} else if (process.argv[2] == "-r" || process.argv[2] == "--run") {
    const logStream = fs.createWriteStream("./logs/activityLogs.log");
    const errorStream = fs.createWriteStream("./logs/errorLogs.log");

    service.run(logStream, errorStream, function (error) {
        if (error)
            console.error(error); // TODO: check that this actually works!

        service.stop(0);
    });

    const logger = require('./middleware/logger');
    const express = require('express');
    const compression = require('compression'); // To use gzip compression on response bodies
    const bodyParser = require('body-parser'); // To parse incoming request body (for posts)
    require('body-parser-xml')(bodyParser); // To allow parsing of XML request bodies
    const xml2js = require('xml2js'); // To allow correct parsing of numbers in XML request bodies.
    const tediousExpress = require('./middleware/express-tedious'); // To use DB queries
    const passport = require('passport'); // For login stuff
    const session = require('express-session');
    const path = require('path');
    const fileStore = require('session-file-store')(session);

    // Required for CORS issues
    const allowCrossDomain = function (req, res, next) {
        res.header('Access-Control-Allow-Origin', '*');
        res.header('Access-Control-Allow-Methods', 'GET,PUT,POST');
        res.header('Access-Control-Allow-Headers', 'Content-Type, Access-Control-Allow-Origin, Authorization');

        next();
    }

    const app = express();
    app.use(express.static(path.join(__dirname, 'views/static')));
    app.set('view engine', 'ejs'); // So we can render ejs files in the browser

    if ('development' == env) {
        // Session Configuration
        app.use(session({
            store: new fileStore({ logFn: logger.log }),
            saveUninitialized: false,
            resave: false,
            secret: config.session.secret,
            name: 'authorisation.sid',
            cookie: { secure: true },
        }));
    } else {
        // Session Configuration
        app.use(session({
            store: new fileStore({ logFn: logger.log }),
            saveUninitialized: false,
            resave: false,
            secret: config.session.secret,
            name: 'authorisation.sid',
            cookie: { secure: true },
        }));
    }

    app.use(compression()); // Enable gzip compression for response body
    app.use(allowCrossDomain);
    // End CORS stuff

    // Check that the request body content-type is JSON or XML. Nothing else allowed!
    const contentType = /^application\/(?:xml|json)(?:[\s;]|$)/i;
    app.use(function (req, res, next) {
        if (req.method === 'PUT' && !contentType.test(req.headers['content-type'])) { // TODO: include POST method.
            res.status(406);
            return res.send("The content type of the request must be either JSON or XML. '"
                + req.headers['content-type'] + "' was detected. Please reformat the request.");
        }
        next();
    });

    app.use(bodyParser.urlencoded({ extended: true }));
    app.use(bodyParser.json()); // To allow parsing of JSON request bodies
    app.use(bodyParser.xml({
        xmlParseOptions: {
            valueProcessors: [xml2js.processors.parseNumbers], // Parse numbers correctly
            explicitArray: false // Only put nodes in array if >1 
        }
    })); // To allow parsing of XML request bodies

    const auth = require('./auth');
    app.use(function (req, res, next) {
        auth.system(req);
        next();
    });

    const oauth2 = require('./oauth2');
    app.use(function (req, res, next) {
        oauth2.system(req);
        next();
    });

    const schema = require('./middleware/schema');
    app.use(function (req, res, next) {
        schema.build(req);
        next();
    });

    app.use(passport.initialize());
    app.use(passport.session());

    app.use('/api', function (req, res, next) {
        res.locals = req.query;
        res.locals.system = 'live';
        req.query = tediousExpress(req, config.connection);
        next();
    }, require('./routes/api'));

    app.use('/training', function (req, res, next) {
        res.locals = req.query;
        res.locals.system = 'training';
        req.query = tediousExpress(req, config.connectionTraining);
        next();
    }, require('./routes/api'));

    const flash = require('connect-flash');
    app.use(flash());

    // Account routes
    const site = require('./site'); //Layout/view info
    app.use(function (req, res, next) {
        site.system(req);
        next();
    });
    app.get('/', site.index);
    app.get('/login', site.loginForm);
    app.post('/login', site.login);
    app.get('/logout', site.logout);
    app.get('/account', site.account);
    app.get('/create', site.create);
    app.get('/scopes', site.scopes);
    app.get('/clients', site.clients);
    app.get('/userWebsites', site.websites);
    app.get('/userAccessTokens', site.userAccessTokens);
    app.get('/oauth2redirect', site.oauth2redirect);
    app.get('/passwordChange', site.passwordChange);

    // Auth routes
    app.get('/oauth/auth', oauth2.authorization);
    app.post('/oauth/auth/decision', oauth2.decision);
    app.post('/oauth/token', oauth2.token);

    const https = require('https')

    const httpsOptions = {
        key: fs.readFileSync('./certs/winman.key'),
        cert: fs.readFileSync('./certs/winman.crt')
    }

    const server = https.createServer(httpsOptions, app).listen(config.server.port, '0.0.0.0', function () {
        logger.log('Express server listening on port ' + server.address().port + " in " + app.settings.env + " mode.");
    });

    // catch 404 and forward to error handler
    app.use(function (req, res, next) {
        res.status(404).send('404 Not Found: ' + req.method + ": " + req.originalUrl);
        // TODO: make a nice 404 message :)
        // TODO: res.render('notfoundpage', { message: "whatever" });
    });

    // Generic error handler - TODO: make this render a nice page maybe?
    app.use(function (err, req, res, next) {
        if (req.hasOwnProperty('oauth2') && req.oauth2.redirectURI) {
            // This is an error from server.authorization. Will only ever be oauth2redirect.
            res.redirect(req.oauth2.redirectURI + '?error=' + err.message);
        } else {
            logger.error(err.stack);
        }
    });

    process.on('uncaughtException', function (err) {
        return logger.errorAndExit(5, err.stack);
    });
} else {
    usage();
}
// End os-service stuff
