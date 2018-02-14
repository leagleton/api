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
 * 'winston' is used to create custom logging functionality.
 * 'fs' is used to interact with the file system.
 */
const winston = require('winston');
const fs = require('fs');

/**
 * Determine how to format our logged messages in our log files.
 * 
 * @param {Object} options - Our logging options object.
 */
function customFileFormatter(options) {
    return "*** " + options.timestamp() + ": " + options.message.replace(/\s\s\s\s/g, "\r\n\t") + "\r\n-------------------------------";
}

/**
 * Configure our custom logging functionality.
 */
const logger = new (winston.Logger)({
    transports: [
        new (winston.transports.Console)({
            formatter: customFileFormatter,
            level: 'debug',
            json: false,
            timestamp: () => {
                return new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString();
            }
        })
    ]
});

/**
 * Log an information message.
 * 
 * @param {String} message - The message to log.
 */
exports.log = (message) => logger.info(message);

/**
 * Log an error message.
 * 
 * @param {String}   message  - The message to log.
 * @param {Callback} callback - The callback function.
 */
exports.error = (message, callback) => logger.error(message, callback);

/**
 * Log a fatal error message and stop the application.
 * 
 * @param {Number} code  - The status code to use when stopping the application.
 * @param {Object} stack - The message to log.
 */
exports.errorAndExit = (code, stack) => {
    /**
     * We use console.error here instead of logger.error because we want
     * to format fatal error messages differently.
     */
    console.error("*** " + new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString() + ": FATAL ERROR: " + stack.replace(/\s\s\s\s/g, "\r\n\t") + ". Shutting down.");
    process.exit(code);
};
