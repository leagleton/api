const winston = require('winston');
const fs = require('fs');

function customFileFormatter(options) {
    return "*** " + options.timestamp() + ": " + options.message.replace(/\s\s\s\s/g, "\r\n\t") + "\r\n-------------------------------";
}

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

const errorLogger = new (winston.Logger)({
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

exports.log = (message) => logger.info(message);
exports.error = (message, callback) => errorLogger.error(message, callback);
exports.errorAndExit = (code, stack) => {
    console.error("*** " + new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString() + ": FATAL ERROR: " + stack.replace(/\s\s\s\s/g, "\r\n\t") + ". Shutting down.");
    process.exit(code);
};
