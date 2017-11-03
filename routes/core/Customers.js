'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

/* Fetch all web enabled customers. */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getCustomers') === -1) {
        return utils.reject(res, req, utils.reasons.inadequateAccess, 401);
    } else {
        inputParams.push("@scope = 'getCustomers'");
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
        sp: 'wsp_RestApiCustomersSelect',
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

/* Create a new CRM contact and company which can be converted to a customer in WinMan. */
router.post('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('postCustomers') === -1) {
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
    const firstName = req.body.FirstName || '';
    const lastName = req.body.LastName || '';
    const workPhoneNumber = req.body.WorkPhoneNumber || '';
    const homePhoneNumber = req.body.HomePhoneNumber || '';
    const mobilePhoneNumber = req.body.MobilePhoneNumber || '';
    const faxNumber = req.body.FaxNumber || '';
    const homeEmailAddress = req.body.HomeEmailAddress || '';
    const workEmailAddress = req.body.WorkEmailAddress || '';
    const portalUserName = req.body.WebsiteUserName || '';
    const jobTitle = req.body.JobTitle || '';
    let allowCommunication = req.body.AllowCommunication || false;
    const address = req.body.Address || '';
    const city = req.body.City || '';
    const region = req.body.City || '';
    const postalCode = req.body.PostalCode || '';
    const countryCode = req.body.CountryCode || '';

    if (!eCommerceWebsiteId || !firstName || !lastName ||
        !address || !postalCode || !countryCode) {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (typeof req.body.AllowCommunication === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    allowCommunication = (allowCommunication) ? 1 : 0;

    tp.sql("DECLARE @error NVARCHAR(1000) EXEC wsp_RestApiContactsInsert \
                @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                @firstName = '" + firstName + "',\
                @lastName = '" + lastName + "',\
                @workPhoneNumber = '" + workPhoneNumber + "',\
                @homePhoneNumber = '" + homePhoneNumber + "',\
                @mobilePhoneNumber = '" + mobilePhoneNumber + "',\
                @faxNumber = '" + faxNumber + "',\
                @homeEmailAddress = '" + homeEmailAddress + "',\
                @workEmailAddress = '" + workEmailAddress + "',\
                @portalUserName = '" + portalUserName + "',\
                @jobTitle = '" + jobTitle + "',\
                @allowCommunication = " + allowCommunication + ",\
                @address = '" + address + "',\
                @city = '" + city + "',\
                @region = '" + region + "',\
                @postalCode = '" + postalCode + "',\
                @countryCode = '" + countryCode + "',\
                @scope = 'postCustomers',\
                @error = @error OUTPUT")
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            } else {
                utils.success(res, req, {
                    Status: "Success",
                    StatusMessage: "CRM Contact has been successfully created."
                });
            }
        })
        .catch((err) => {
            let status = 500;

            if (err.message.indexOf('input data') > -1 || 
                err.message.indexOf('parameter missing') > -1 ||
                err.message.indexOf('converting data type') > -1 ||
                err.message.indexOf('expects parameter') > -1)
            {
                status = 400;
            }

            if (status === 500) {
                logger.error(err.stack);
                utils.error(res, req, err.message);
            } else {
                utils.reject(res, req, err.message);
            }
        });       
});

module.exports = router;
