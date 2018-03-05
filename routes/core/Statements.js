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
 * Fetch (GET) a customer's statements from WinMan.
 */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getStatements') === -1) {
        res.status(403);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getStatements'");
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

    if (typeof res.locals.outstanding !== 'undefined') {
        try {
            const outstanding = JSON.parse(String(res.locals.outstanding).toLowerCase());

            if (typeof outstanding !== 'boolean') {
                throw typeof outstanding;
            }

            inputParams.push("@outstanding = " + (outstanding ? 1 : 0));
        } catch (e) {
            const type = (e instanceof SyntaxError) ? typeof res.locals.outstanding : e;

            return utils.reject(res, req, utils.reasons.invalidParam
                + ' outstanding. This field should be a boolean but a '
                + type + ' was detected.');
        }
    } else {
        inputParams.push("@outstanding = 0");
    }

    if (typeof res.locals.orderby !== 'undefined') {
        const acceptedValues = {
            'salesinvoiceid': 'SalesInvoiceId',
            'date': 'EffectiveDate',
            'status': 'InvoiceStatus',
            'value': 'CurInvoiceValue'
        };

        const column = res.locals.orderby.toLowerCase();

        if (acceptedValues.hasOwnProperty(column)) {
            inputParams.push("@orderBy = '" + acceptedValues[column] + "'");
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' orderby. This field only accepts the values salesinvoiceid, date, status or value. You have supplied: '
                + column + '.');
        }
    } else {
        inputParams.push("@orderBy = 'SalesInvoiceId'");
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam
            + ' website.');
    }

    if (typeof res.locals.page !== 'undefined') {
        if (!isNaN(parseInt(res.locals.page))) {
            inputParams.push("@pageNumber = " + res.locals.page);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' page. This field should be an integer but a '
                + typeof res.locals.page + ' was detected.');
        }
    }

    if (typeof res.locals.size !== 'undefined') {
        if (!isNaN(parseInt(res.locals.size))) {
            inputParams.push("@pageSize = " + res.locals.size);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' size. This field should be an integer but a '
                + typeof res.locals.size + ' was detected.');
        }
    }

    const params = {
        sp: 'wsp_RestApiCustomerStatementsSelect',
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
