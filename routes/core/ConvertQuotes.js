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
 * 'tp' is used for executing SQL queries.
 */
const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const tp = require('tedious-promises');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

/**
 * Convert (PUT) a customer's quote to an order in WinMan.
 */
router.put('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('putConvertQuotes') === -1) {
        return utils.reject(res, req, utils.reasons.inadequateAccess, 401);
    }

    if (res.locals.system === 'training') {
        tp.setConnectionConfig(config.connectionTraining);
    } else {
        tp.setConnectionConfig(config.connection);
    }

    if (req.body.hasOwnProperty('Data')) {
        req.body = req.body.Data;
    }

    const eCommerceWebsiteId = req.body.Website || '';
    const quoteId = req.body.QuoteId || '';
    const customerOrderNumber = req.body.CustomerOrderNumber || '';
    const customerGuid = req.body.CustomerGuid || '';
    const customerId = req.body.CustomerId || '';
    const customerBranch = req.body.CustomerBranch || '';

    if (!customerGuid) {
        if (!customerId && !customerBranch) {
            return utils.reject(res, req, utils.reasons.requiredParam
                + ' You must supply either CustomerGuid or CustomerId and CustomerBranch. You have supplied none of these.');
        } else if (!customerId || !customerBranch) {
            let missingParameter;
            let suppliedParameter;

            if (customerId) {
                missingParameter = 'CustomerBranch';
                suppliedParameter = 'CustomerId';
            } else {
                missingParameter = 'CustomerId';
                suppliedParameter = 'CustomerBranch';
            }

            return utils.reject(res, req, utils.reasons.requiredParam + ' '
                + missingParameter + '. You have supplied ' + suppliedParameter
                + ' but not ' + missingParameter + '.');
        }
    }

    if (!quoteId) {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' QuoteId.');
    }

    if (!customerOrderNumber) {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' CustomerOrderNumber.');
    }    

    if (!eCommerceWebsiteId) {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' Website.');
    }

    tp.sql("DECLARE @results nvarchar(100);\
            EXEC wsp_RestApiQuotesConvert \
                @website = '" + eCommerceWebsiteId + "',\
                @customerGuid = '" + customerGuid + "',\
                @customerId = '" + customerId + "',\
                @customerBranch = '" + customerBranch + "',\
                @quoteId = '" + quoteId + "',\
                @customerOrderNumber = '" + customerOrderNumber + "',\
                @scope = 'putConvertQuotes',\
                @results = @results OUTPUT;")
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            } else {
                utils.success(res, req, {
                    Status: "Success",
                    StatusMessage: results[0].Results
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
