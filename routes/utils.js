'use strict';
const xml = require('xml');
const logger = require('../middleware/logger');
const config = require('../config');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

const contentTypes = {
    json: "application/json; charset=utf-8",
    xml: "application/xml; charset=utf-8"
};

exports.reasons = {
    rejectHeader: 'This API produces XML or JSON only. Please alter your accept header accordingly.',
    requiredParam: 'A required parameter is missing:',
    invalidParam: 'A parameter is of the wrong type:',
    inadequateAccess: 'The client has not been granted adequate access to this resource.',
    unspecified: 'There was a problem trying to execute your request. Please contact WinMan support if the problem persists.'
};

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

exports.error = (res, req, message) => {
    this.reject(res, req, message, 500);
}

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

exports.setContentType = (res, contentType) => {
    res.set('Content-Type', contentType);

    if (contentType == contentTypes.xml) {
        res.write('<?xml version="1.0" encoding="UTF-8"?>');
    }
}

exports.executeSelect = (res, req, params) => {
    let qry = "DECLARE @results NVARCHAR(MAX) EXEC ";
    let type = "";

    params.args.push("@results = @results OUTPUT");

    if (req.accepts('application/xml')) {
        type += "XML ";
        this.setContentType(res, contentTypes.xml);
    } else if (req.accepts('application/json') || typeof req.headers.accept === 'undefined') {
        type += "JSON ";
        this.setContentType(res, contentTypes.json);
    } else {
        return this.reject(res, this.reasons.rejectHeader);
    }

    qry = qry + params.sp + type + params.args.concat();

    if (res.locals.system === 'training') {
        tp.setConnectionConfig(config.connectionTraining);
    } else {
        tp.setConnectionConfig(config.connection);
    }

    tp.sql(qry)
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';
            if (result !== '') {
                throw new Error(result);
            } else {
                if (req.accepts('application/xml')) {
                    res.write(results[0].Results);
                    res.end();
                } else {
                    res.send(results[0].Results);
                }
            }
        })
        .catch((err) => {
            let status = 500;

            if (err.message.indexOf('parameter') > -1 ||
                err.message.indexOf('Parameter') > -1) {
                status = 400;
            }

            if (err.message.indexOf('not enabled') > -1) {
                status = 403;
            }

            if (status === 500) {
                logger.error(err.stack);
                this.error(res, req, err.message);
            } else {
                this.reject(res, req, err.message);
            }
        });
}
