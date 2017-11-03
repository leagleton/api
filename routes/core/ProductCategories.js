'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');

/* Fetch data */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getProductCategories') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getProductCategories'");
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

    if (typeof res.locals.guid !== 'undefined') {
        inputParams.push("@guid = '" + res.locals.guid + "'");
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, req, utils.reasons.requiredParam);
    } 

    const params = {
        sp: "wsp_RestApiProductCategoriesSelect",
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
