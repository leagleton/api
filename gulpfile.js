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
 * 'gulp' is used for task automation.
 * 'pump' is used for piping multiple streams through our gulp tasks at one time.
 * 'inquirer' is used for collecting responses from the user via command line.
 * 'replace' is used replacing text within files.
 * 'rename' is used for renaming files.
 * 'clean' is used for deleting files.
 * 'sass' is used for compile Sass into CSS.
 * 'sass-lint' is used to ensure our Sass is properly formatted.
 * 'uglify' is used for obfuscation.
 * 'minifyejs' is used for minifying our ejs files.
 * 'strip' is used for stripping out code comments.
 */
const gulp = require('gulp');
const pump = require('pump');
const inquirer = require('inquirer');
const replace = require('gulp-replace');
const rename = require('gulp-rename');
const clean = require('gulp-clean');
const sass = require('gulp-sass');
const sassLint = require('gulp-sass-lint');
const uglify = require('gulp-uglify-es').default;
const minifyejs = require('gulp-minify-ejs');
const strip = require('gulp-strip-comments');

/**
 * Declare a global vairable for storing user input. 
 */
let settings;

/**
 * Generates a random string for use as a new session secret.
 * We can't import our utils middleware for this function because
 * the setInterval function in that file will keep the node process running
 * and gulp will never exit.
 * 
 * @param   {Number} length - The length of the string to generate.
 * @returns {String} The randomly generated string.
 */
function generateString(length) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let randomString = '';

    for (let i = length; i > 0; --i) randomString += chars[Math.floor(Math.random() * chars.length)];

    return randomString;
};

/**
 * Remove all files from the dist folder.
 */
gulp.task('clean', function () {
    return gulp.src('dist/*', { read: false })
        .pipe(clean());
});

/** 
 * Copy necessary static files to the dist folder.
 */
gulp.task('copy', ['clean'], function () {
    pump([
        gulp.src([
            '*.json',
            'certs/*',
            'config/index.js.dist',
            'logs/.gitignore',
            'sessions/.gitignore',
            'routes/**/.gitignore',
            'views/**/.gitignore',
            'views/**',
            '!views/**/schema/**/*.dist',
            '!views/static/swagger/schema/*.json'], { base: '.' }),
        gulp.dest('dist')
    ]
    );
});

/** 
 * Make sure we have a .gitignore file in the dist folder itself
 * to avoid causing version control problems.
 */
gulp.task('ignore', ['copy'], function () {
    pump([
        gulp.src('logs/.gitignore'),
        gulp.dest('dist')
    ]);
});

/**
 * Ask the user to input the config settings.
 */
gulp.task('config', ['ignore'], function (done) {
    console.log('\x1b[37m\x1b[1m\n\   Please enter the config settings as requested below.\n   You can enter ? for any question to view a help message.\n   If you make a mistake, you can manually edit the config\n   file after it has been generated.\x1b[21m\n\x1b[37m');

    inquirer.prompt([{
        type: 'input',
        message: 'Service name (press enter to use the default value): ',
        default: 'winman-rest',
        name: 'service.serviceName',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mThe service name is the system name for the WinMan REST API Windows service.\n   Each installation of the API on the customer\'s server must have a\n   different service name, so please ensure the customer is not already\n   using the service name you enter here. Examples:\n\twinman-rest\n\twinman-rest-usa\n\twinman-rest-prerelease\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Service display name (press enter to use the default value): ',
        default: 'WinMan REST API',
        name: 'service.displayName',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mThe service display name is the user-friendly name for the WinMan REST API\n   Windows service. Multiple installations of the API can use the same service\n   display name, but to avoid possible confusion it is highly recommended that\n   each installation has a different service display name. Examples:\n\tWinMan REST API\n\tWinMan REST API USA\n\tWinMan REST API Pre-Release\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Live SQL server name (press enter to use the default value): ',
        default: 'localhost',
        name: 'connection.server',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the name or IP address of the customer\'s SQL server on which\n   their Live system database resides. Examples:\n\tlocalhost\n\t192.168.56.1\n\tMSSQLSERVER\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Live SQL server username: ',
        name: 'connection.userName',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter a valid username for the customer\'s SQL server on which\n   their Live system database resides.\x1b[37m';
            }
            if (!value) {
                return '\x1b[31mPlease enter a valid username.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'password',
        message: 'Live SQL server password (masked): ',
        name: 'connection.password',
        mask: '*',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the password associated with the username you entered\n   for the previous question. The password will be masked as you type.\x1b[37m';
            }
            if (!value) {
                return '\x1b[31mPlease enter a valid password.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Live SQL server database name (press enter to use the default value): ',
        default: 'Winman',
        name: 'connection.options.database',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the database name for the customer\'s Live system.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Would you like to add a Training system? ',
        default: 'Y/N',
        name: 'training',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mIf the customer does not have a Training system or does not\n   require the API to communicate with their Training system, you\n   can set up the API in single-system mode. To do this, answer\n   this question with no.\x1b[37m';
            }
            if (value.toLowerCase() === 'y' || value.toLowerCase() === 'yes') {
                return true;
            }
            if (value.toLowerCase() === 'n' || value.toLowerCase() === 'no') {
                return true;
            }
            return '\x1b[31mPlease enter yes or no.\x1b[37m';
        }
    },
    {
        type: 'input',
        message: 'Training SQL server name (press enter to use the default value): ',
        default: 'localhost',
        name: 'connectionTraining.server',
        when: function (answers) {
            if (answers.training.toLowerCase() === 'yes' || answers.training.toLowerCase() === 'y') {
                return true;
            } else {
                return false;
            }
        },
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the name or IP address of the customer\'s SQL server on which\n   their Training system database resides. It is highly likely that this\n   will be the same as the Live SQL server name. Examples:\n\tlocalhost\n\t192.168.56.1\n\tMSSQLSERVER\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Training SQL server username: ',
        name: 'connectionTraining.userName',
        when: function (answers) {
            if (answers.training.toLowerCase() === 'yes' || answers.training.toLowerCase() === 'y') {
                return true;
            } else {
                return false;
            }
        },
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter a valid username for the customer\'s SQL server on which\n   their Training system database resides.\x1b[37m';
            }
            if (!value) {
                return '\x1b[31mPlease enter a valid username.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'password',
        message: 'Training SQL server password (masked): ',
        name: 'connectionTraining.password',
        mask: '*',
        when: function (answers) {
            if (answers.training.toLowerCase() === 'yes' || answers.training.toLowerCase() === 'y') {
                return true;
            } else {
                return false;
            }
        },
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the password associated with the username you entered\n   for the previous question. The password will be masked as you type.\x1b[37m';
            }
            if (!value) {
                return '\x1b[31mPlease enter a valid password.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'Training SQL server database name (press enter to use the default value): ',
        default: 'Training',
        name: 'connectionTraining.options.database',
        when: function (answers) {
            if (answers.training.toLowerCase() === 'yes' || answers.training.toLowerCase() === 'y') {
                return true;
            } else {
                return false;
            }
        },
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mPlease enter the database name for the customer\'s Training system.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'API URL: ',
        name: 'server.host',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mThe API URL is the URL at which the API will be available over\n   HTTPS. This should match the DNS entry which has been set up for\n   the customer. Examples:\n\ttalkingtablesrest.winman.net\n\ttildenetrest.winman.net\x1b[37m';
            }
            if (!value) {
                return '\x1b[31mPlease enter the API URL.\x1b[37m';
            }
            return true;
        }
    },
    {
        type: 'input',
        message: 'API port (press enter to use the default value): ',
        default: 3000,
        name: 'server.port',
        validate: function (value) {
            if (value === '?') {
                return '\x1b[92mThe API port is the port number at which the API will be available\n   over HTTPS. Each installation of the API on the customer\'s server\n   must run on a different port number, so please ensure the customer\n   is not already using the port number you specify here.\x1b[37m';
            }
            if (isNaN(value) || (value % 1 !== 0)) {
                return '\x1b[31mPlease enter a valid port number. This should be an integer.\x1b[37m';
            }
            return true;
        }
    }]).then(answers => {
        answers.session = {};
        answers.session.secret = generateString(32);

        /**
         * Save the user's input to a global variable so we can access
         * it in the next gulp task.
         */
        settings = answers;

        done();
    });
});

/**
 * Set the config settings based on user input.
 */
gulp.task('generate', ['config'], function () {
    /**
     * Open index.js.dist as a writeable stream, set the config settings accordingly
     * then save the file as dist/config/index.js.dist.
     */
    return gulp.src(['config/index.js.dist'])
        .pipe(replace("'serviceName': ''", "'serviceName': '" + settings.service.serviceName + "'"))
        .pipe(replace("'displayName': ''", "'displayName': '" + settings.service.displayName + "'"))
        .pipe(replace("'liveServer': ''", "'server': '" + settings.connection.server + "'"))
        .pipe(replace("'liveUserName': ''", "'userName': '" + settings.connection.userName + "'"))
        .pipe(replace("'livePassword': ''", "'password': '" + settings.connection.password + "'"))
        .pipe(replace("'liveDatabase': ''", "'database': '" + settings.connection.options.database + "'"))
        .pipe(replace("'dual'", function () {
            if (settings.hasOwnProperty('connectionTraining')) {
                return "'dual'";
            }
            return "'single'";
        }))
        .pipe(replace("'trainingServer': ''", function () {
            if (settings.hasOwnProperty('connectionTraining')) {
                return "'server': '" + settings.connectionTraining.server + "'";
            }
            return "'server': ''";
        }))
        .pipe(replace("'trainingUserName': ''", function () {
            if (settings.hasOwnProperty('connectionTraining')) {
                return "'userName': '" + settings.connectionTraining.userName + "'";
            }
            return "'userName': ''";
        }))
        .pipe(replace("'trainingPassword': ''", function () {
            if (settings.hasOwnProperty('connectionTraining')) {
                return "'password': '" + settings.connectionTraining.password + "'";
            }
            return "'password': ''";
        }))
        .pipe(replace("'trainingDatabase': ''", function () {
            if (settings.hasOwnProperty('connectionTraining')) {
                return "'database': '" + settings.connectionTraining.options.database + "'";
            }
            return "'database': ''";
        }))
        .pipe(replace("'host': ''", "'host': '" + settings.server.host + "'"))
        .pipe(replace("'port': ''", "'port': " + settings.server.port))
        .pipe(replace("'secret': ''", "'secret': '" + settings.session.secret + "'"))
        .pipe(gulp.dest('dist/config'));
});

/**
 * Create index.js from index.js.dist and obfuscate.
 */
gulp.task('tidy', ['generate'], function () {
    return gulp.src('dist/config/index.js.dist')
        .pipe(rename('index.js'))
        .pipe(uglify())
        .pipe(gulp.dest('dist/config'));;
});

/**
 * Remove unnecessary index.js.dist file.
 */
gulp.task('remove', ['tidy'], function () {
    return gulp.src('dist/config/*.dist', { read: false })
        .pipe(clean());
});

/** 
 * Copy necessary JS files to the dist folder and obfuscate.
 */
gulp.task('build', ['remove'], function () {
    pump([
        gulp.src([
            'middleware/**/*.js',
            'routes/**/*.js',
            'winman-rest.js'], { base: '.' }),
        uglify(),
        gulp.dest('dist')
    ]
    );
});

/**
 * Obfuscate our frontend JS files and minify our EJS files.
 */
gulp.task('uglify', function () {
    gulp.src('frontend/pages/**/*.ejs')
        .pipe(strip())
        .pipe(minifyejs())
        .pipe(gulp.dest('views'));

    return gulp.src('frontend/js/*.js')
        .pipe(rename(function (path) {
            path.basename += '.min';
        }))
        .pipe(uglify({ toplevel: true }))
        .pipe(gulp.dest('views/static/js'));
});

/**
 * Check that our Sass is properly formatted. Any errors
 * or warnings will be shown in the terminal.
 */
gulp.task('sass-lint', function () {
    return gulp.src('frontend/style/**/*.s+(a|c)ss')
        .pipe(sassLint({
            options: {
                configFile: './sass-lint.yml'
            }
        }))
        .pipe(sassLint.format())
        .pipe(sassLint.failOnError());
});

/**
 * Generate our CSS from Sass.
 */
gulp.task('sass', ['sass-lint'], function () {
    return gulp.src('frontend/style/main.scss')
        .pipe(sass({ outputStyle: 'compressed' }))
        .pipe(rename('winman.min.css'))
        .pipe(gulp.dest('views/static/css'));
});
