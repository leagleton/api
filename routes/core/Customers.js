'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');

/* Fetch all web enabled customers. */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('read') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
    }

    if (typeof res.locals.modified !== 'undefined') {
        if (!isNaN(parseInt(res.locals.modified))) {
            inputParams.push("@seconds = " + res.locals.modified);
        } else {
            return utils.reject(res, utils.reasons.invalidParam);
        }
    }

    if (typeof res.locals.guid !== 'undefined') {
        inputParams.push("@guid = '" + res.locals.guid + "'");
    }

    if (typeof res.locals.website !== 'undefined') {
        inputParams.push("@website = '" + res.locals.website + "'");
    } else {
        return utils.reject(res, utils.reasons.requiredParam);
    }

    const params = {
        sp: 'wsp_RestApiCustomersSelect',
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

router.put('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('write') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
    }

    res.status(200);
    res.send('Not yet implemented.');
});

router.post('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('write') === -1) {
        res.status(401);
        res.send(utils.reasons.inadequateAccess);
        return;
    }

    res.status(200);
    res.send('Not yet implemented.');
});

module.exports = router;
