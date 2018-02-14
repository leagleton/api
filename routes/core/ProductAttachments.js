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
 * GET all web enabled products.
 */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getProductAttachments') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getProductAttachments'");
    }

    if (typeof res.locals.modified !== 'undefined') {
        if (!isNaN(parseInt(res.locals.modified))) {
            inputParams.push("@seconds = " + res.locals.modified);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam);
        }
    }

    if (typeof res.locals.sku !== 'undefined') {
        inputParams.push("@sku = '" + res.locals.sku + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    const params = {
        sp: "wsp_RestApiDocumentsSelect",
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
