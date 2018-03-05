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
 * 'router' is used for routing, i.e. determining which URL goes where.
 * 'passport' is used for authentication.
 * 'utils' refers to our custom functions for handling SQL queries and responses.
 * 'logger' is used to define our custom logging functions.
 * 'config' refers to our application's config settings.
 * 'httpntlm' is used for NTLM authentication for the customer's WinMan reports server.
 * 'tp' is used for executing SQL queries.
 */
const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const httpntlm = require('httpntlm');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Fetch (GET) PDF versions of a customer's orders, quotes, invoices or statements from WinMan.
 */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getPdfs') === -1) {
        res.status(403);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getPdfs'");
    }

    const customerGuid = res.locals.customerguid || '';
    const customerId = res.locals.customerid || '';
    const customerBranch = res.locals.customerbranch || '';

    if (!customerGuid) {
        if (!customerId && !customerBranch) {
            return utils.reject(res, req, utils.reasons.requiredParam
                + ' You must supply either customerguid or customerid and customerbranch. You have supplied none of these.');
        } else if (!customerId || !customerBranch) {
            let missingParameter;
            let suppliedParameter;

            if (customerId) {
                missingParameter = 'customerbranch';
                suppliedParameter = 'customerid';
            } else {
                missingParameter = 'customerid';
                suppliedParameter = 'customerbranch';
            }

            return utils.reject(res, req, utils.reasons.requiredParam + ' '
                + missingParameter + '. You have supplied ' + suppliedParameter
                + ' but not ' + missingParameter + '.');
        } else {
            inputParams.push("@customerId = '" + customerId + "'");
            inputParams.push("@customerBranch = '" + customerBranch + "'");
        }
    } else {
        inputParams.push("@customerGuid = '" + customerGuid + "'");
    }

    if (typeof res.locals.returntype !== 'undefined') {
        const acceptedValues = {
            'salesorder': 'Acknowledgement',
            'quote': 'Quotation',
            'statement': 'Statement',
            'salesinvoice': 'Sales%20Invoice'
        };

        const column = res.locals.returntype.toLowerCase();

        if (acceptedValues.hasOwnProperty(column)) {
            inputParams.push("@reportType = '" + acceptedValues[column] + "'");

            switch (column) {
                case 'quote':
                    inputParams.push("@parameterName = 'SalesOrderId'");

                    if (typeof res.locals.quoteid === 'undefined') {
                        return utils.reject(res, req, utils.reasons.requiredParam
                            + ' quoteid.');
                    } else {
                        inputParams.push("@parameterValue = '" + res.locals.quoteid + "'");
                    }
                    break;
                case 'statement':
                    inputParams.push("@parameterName = null");
                    break;
                case 'salesinvoice':
                    inputParams.push("@parameterName = 'SalesInvoiceId'");

                    if (typeof res.locals.salesinvoiceid === 'undefined') {
                        return utils.reject(res, req, utils.reasons.requiredParam
                            + ' salesinvoiceid.');
                    } else {
                        inputParams.push("@parameterValue = '" + res.locals.salesinvoiceid + "'");
                    }
                    break;
                default:
                    inputParams.push("@parameterName = 'SalesOrderId'");

                    if (typeof res.locals.salesorderid === 'undefined') {
                        return utils.reject(res, req, utils.reasons.requiredParam
                            + ' salesorderid.');
                    } else {
                        inputParams.push("@parameterValue = '" + res.locals.salesorderid + "'");
                    }
            }
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' returntype. This field only accepts the values salesorder, quote, statement or salesinvoice. You have supplied: '
                + column + '.');
        }
    } else {
        inputParams.push("@reportType = 'Acknowledgement'");
        inputParams.push("@parameterName = 'SalesOrderId'");

        if (typeof res.locals.salesorderid === 'undefined') {
            return utils.reject(res, req, utils.reasons.requiredParam
                + ' salesorderid.');
        } else {
            inputParams.push("@parameterValue = '" + res.locals.salesorderid + "'");
        }
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' website.');
    }

    const params = {
        sp: 'wsp_RestApiPdfUrlSelect',
        args: inputParams
    };

    let qry = "DECLARE @results nvarchar(200); EXEC ";
    params.args.push("@results = @results OUTPUT");
    qry = qry + params.sp + ' ' + params.args.concat();

    let reportsUserName = '';
    let lm_password = '';
    let nt_password = '';

    if (res.locals.system === 'training') {
        tp.setConnectionConfig(config.connectionTraining);

        reportsUserName = config.connectionTraining.reportsUserName;
        lm_password = config.connectionTraining.lm_password;
        nt_password = config.connectionTraining.nt_password;
    } else {
        tp.setConnectionConfig(config.connection);

        reportsUserName = config.connection.reportsUserName;
        lm_password = config.connection.lm_password;
        nt_password = config.connection.nt_password;        
    }

    tp.sql(qry)
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            } else {
                httpntlm.get({
                    url: results[0].Results,
                    username: reportsUserName,
                    lm_password: lm_password,
                    nt_password: nt_password,
                    binary: true
                }, function (err, response) {
                    if (err) throw new Error(err);

                    const pdf = Buffer(response.body).toString('base64');

                    utils.success(res, req, {
                        Data: pdf
                    }, 200, 'Pdf');
                });
            }
        })
        .catch((err) => {
            let status = 400;

            if (err.message.indexOf('not enabled') > -1) {
                status = 401;
            }

            logger.error(err.stack);
            utils.reject(res, req, err.message, status);
        });
});

module.exports = router;
