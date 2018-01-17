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
 * GET all web enabled customers.
 */
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

/**
 * Create (POST) a new CRM contact and company which can be 
 * converted to a customer in WinMan.
 */
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
    const region = req.body.Region || '';
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

    tp.sql("DECLARE @error nvarchar(1000);\
            DECLARE @contact bigint;\
            DECLARE @company bigint;\
            DECLARE @exists bit;\
            EXEC wsp_RestApiContactsInsert \
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
                @error = @error OUTPUT,\
                @contact = @contact OUTPUT,\
                @company = @company OUTPUT,\
                @exists = @exists OUTPUT;")
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            } else if (results[0].hasOwnProperty('Exists')) {
                throw new Error('The specified WebsiteUserName already exists for the specified Website. Please check your input data.');
            } else {
                utils.success(res, req, {
                    Status: "Success",
                    StatusMessage: "CRM Contact has been successfully created."
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
