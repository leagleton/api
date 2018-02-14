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
 * 'xml' is used for correctly parsing XML.
 * 'logger' is used to define our custom logging functions.
 * 'config' refers to our application's config settings.
 * 'tp' is used for executing SQL queries.
 */
const xml = require('xml');
const logger = require('../middleware/logger');
const config = require('../config');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Define all useable content types.
 */
const contentTypes = {
    json: "application/json; charset=utf-8",
    xml: "application/xml; charset=utf-8"
};

/**
 * Define all possible reasons for returning an error.
 */
exports.reasons = {
    rejectHeader: 'This API produces XML or JSON only. Please alter your accept header accordingly.',
    requiredParam: 'A required parameter is missing:',
    invalidParam: 'A parameter is of the wrong type:',
    inadequateAccess: 'The client has not been granted adequate access to this resource.'
};

/**
 * Return an error response.
 * 
 * @param {Object} res    - The response.
 * @param {Object} req    - The request.
 * @param {String} reason - The reason for the error response.
 * @param {Number} status - The response status code, defaults to 400 Bad Request.
 */
exports.reject = (res, req, reason, status = 400) => {
    res.status(status);

    if (req.accepts('application/xml')) {
        this.setContentType(res, contentTypes.xml);

        let xmlResponse = '<Response><Status>Error</Status><StatusMessage>';
        xmlResponse += reason;
        xmlResponse += '</StatusMessage></Response>';

        res.write(xmlResponse);
        res.end();
    } else {
        res.json({
            Response: {
                Status: "Error",
                StatusMessage: reason
            }
        });
    }
}

/**
 * Return a success response.
 * 
 * @param {Object} res    - The response.
 * @param {Object} req    - The request.
 * @param {Object} object - The response to send.
 * @param {Number} status - The response status code, defaults to 200 OK.
 */
exports.success = (res, req, object, status = 200) => {
    res.status(status);

    if (req.accepts('application/xml')) {
        this.setContentType(res, contentTypes.xml);
        let xmlResponse = '<Response>';

        for (const item in object) {
            const element = {};
            element[item] = object[item];
            xmlResponse += xml(element);
        }

        xmlResponse += '</Response>';
        res.write(xmlResponse);
        res.end();
    } else {
        res.json({ Response: object });
    }
}

/**
 * Set the content-type response header.
 * 
 * @param {Object} res         - The response object.
 * @param {String} contentType - The content-type to set.
 */
exports.setContentType = (res, contentType) => {
    res.set('Content-Type', contentType);

    if (contentType == contentTypes.xml) {
        res.write('<?xml version="1.0" encoding="UTF-8"?>');
    }
}

/**
 * Execute the requested stored procedure.
 * 
 * @param {Object} res    - The response object.
 * @param {Object} req    - The request object.
 * @param {Object} params - The parameters to use to execute the stored procedure.
 */
exports.executeSelect = (res, req, params) => {
    let qry = "DECLARE @results nvarchar(max); EXEC ";
    let type = "";

    params.args.push("@results = @results OUTPUT");

    if (req.accepts('application/xml')) {
        /**
         * XML has been requested.
         */
        type += "XML ";
        this.setContentType(res, contentTypes.xml);
    } else if (req.accepts('application/json') || typeof req.headers.accept === 'undefined') {
        /**
         * JSON has been requested or the accept header is not set.
         * If the accept header is not set, we default to JSON.
         */
        type += "JSON ";
        this.setContentType(res, contentTypes.json);
    } else {
        /**
         * Something other than JSON or XML has been requested, 
         * so send a 406 Not Acceptable error.
         */
        return this.reject(res, req, this.reasons.rejectHeader, 406);
    }

    /**
     * Construct the SQL statement which will be executed.
     */
    qry = qry + params.sp + type + params.args.concat();

    /**
     * Define which system to use - training or live.
     */
    if (res.locals.system === 'training') {
        tp.setConnectionConfig(config.connectionTraining);
    } else {
        tp.setConnectionConfig(config.connection);
    }

    /**
     * Execute our SQL statement and handle the results.
     */
    tp.sql(qry)
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';
            if (result !== '') {
                throw new Error(result);
            } else {
                if (req.accepts('application/xml')) {
                    /**
                     * For XML responses, we need to explicitly write and then end the response body.
                     */
                    res.write(results[0].Results);
                    res.end();
                } else {
                    /**
                     * For JSON response, we can simply send the response.
                     */
                    res.send(results[0].Results);
                }
            }
        })
        .catch((err) => {
            let status = 400;

            /**
             * If our stored procedure returned an error message containing the phrase 'not enabled', 
             * the necessary REST API Scope is not enabled for the requested eCommerce website so return
             * a 401 Unauthorized error. Otherwise, return a 400 Bad Request error.
             */
            if (err.message.indexOf('not enabled') > -1) {
                status = 401;
            }

            /**
             * Log the stack trace and send the error response.
             */
            logger.error(err.stack);
            this.reject(res, req, err.message, status);
        });
}
