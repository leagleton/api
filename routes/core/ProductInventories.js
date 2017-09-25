'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');

/* GET web enabled product stock levels. */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('read') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
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
        sp: "wsp_RestApiInventoriesSelect",
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
