'use strict';

const TYPES = require('tedious').TYPES;
const logger = require('./logger');

function tediousExpress(req, config) {

    return function (sqlQueryText) {

        const Connection = require('tedious').Connection;
        const httpRequest = req;

        return {
            req: httpRequest,
            connection: new Connection(config),
            sql: sqlQueryText,
            parameters: [],
            param: function (param, value, type) {
                this.parameters.push({ name: param, type: type, value: value });
                return this;
            },
            exec: function (ostream, successResponse) {
                const request = this.__createRequest(ostream);
                const fnDoneHandler = this.fnOnDone;
                request.on('done', function (rowCount, more, rows) {
                    successResponse && ostream.write(successResponse);
                    fnDoneHandler && fnDoneHandler('done', ostream);
                });
                request.on('doneProc', function (rowCount, more, rows) {
                    successResponse && ostream.write(successResponse);
                    fnDoneHandler && fnDoneHandler('doneProc', ostream);
                });
                this.__ExecuteRequest(request);
            },
            into: function (ostream, defaultOutput) {
                const fnDoneHandler = this.fnOnDone;
                const request = this.__createRequest(ostream);
                let empty = true;
                request.on('row', function (columns) {
                    if (empty) {
                        empty = false;
                    }
                    ostream.write(columns[0].value);
                });
                request.on('done', function (rowCount, more, rows) {
                    try {
                        if (empty) {
                            defaultOutput && ostream.write(defaultOutput);
                        }
                    } catch (ex) {
                        logger.error(ex.stack);
                    }
                    fnDoneHandler && fnDoneHandler('done', ostream);
                });
                request.on('doneProc', function (rowCount, more, rows) {
                    try {
                        if (empty) {
                            defaultOutput && ostream.write(defaultOutput);
                        }
                    } catch (ex) {
                        logger.error(ex.stack);
                    }
                    fnDoneHandler && fnDoneHandler('doneProc', ostream);
                });
                this.__ExecuteRequest(request);
            },
            done: function (fnDone) {
                this.fnOnDone = fnDone;
                return this;
            },
            fail: function (fnFail) {
                this.fnOnError = fnFail;
                return this;
            },
            __ExecuteRequest: function (request, ostream) {
                const currentConnection = this.connection;
                const fnErrorHandler = this.fnOnError;
                currentConnection.on('connect', function (err) {
                    if (err) {
                        logger.error(err.stack);
                        fnErrorHandler && fnErrorHandler(err, ostream);
                    }
                    currentConnection.execSql(request);
                });
            },
            __createRequest: function (ostream) {
                const Request = require('tedious').Request;
                const fnErrorHandler = this.fnOnError;
                const fnDoneHandler = this.fnOnDone;
                const request =
                    new Request(this.sql,
                        function (err, rowCount) {
                            try {
                                if (err) {
                                    fnErrorHandler && fnErrorHandler(err, ostream);
                                }
                            }
                            finally {
                                this.connection && this.connection.close();
                                fnDoneHandler && fnDoneHandler('Connection closed', ostream);
                            }
                        });

                for (const index in this.parameters) {
                    request.addParameter(
                        this.parameters[index].name,
                        this.parameters[index].type || TYPES.NVarChar,
                        this.parameters[index].value);
                }
                return request;
            },
            fnOnDone: function (message, ostream) {
                try {
                    ostream && ostream.end();
                } catch (ex) {
                    logger.error(ex.stack);
                }
            },
            fnOnError: function (error, ostream) {
                try {
                    ostream && ostream.status(500).end();
                } catch (ex) {
                    logger.log("Warning: Cannot close response after error: " + ex.message + "\nOriginal error:" + error);
                }
                logger.error(error.stack);
            }
        }
    }
}

module.exports = tediousExpress;
