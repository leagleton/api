'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');

/* GET web enabled products. */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getProducts') === -1) {
        res.status(403);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getProducts'");
    }

    if (typeof res.locals.modified !== 'undefined') {
        if (!isNaN(parseInt(res.locals.modified))) {
            inputParams.push("@seconds = " + res.locals.modified);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam);
        }
    }    

    if (typeof res.locals.page !== 'undefined') {
        if (!isNaN(parseInt(res.locals.page))) {
            inputParams.push("@pageNumber = " + res.locals.page);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam);
        }
    }

    if (typeof res.locals.size !== 'undefined') {
        if (!isNaN(parseInt(res.locals.size))) {
            inputParams.push("@pageSize = " + res.locals.size);
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam);
        }
    }    

    if (typeof res.locals.sku !== 'undefined') {
        inputParams.push("@sku = '" + res.locals.sku + "'");
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    const params = {
        sp: "wsp_RestApiProductsSelect",
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
