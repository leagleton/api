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
 */
const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');

/**
 * Fetch (GET) a customer's account overview from WinMan.
 */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getAccountOverviews') === -1) {
        res.status(403);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getAccountOverviews'");
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

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' website.');
    }

    const params = {
        sp: 'wsp_RestApiCustomerAccountOverviewSelect',
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
