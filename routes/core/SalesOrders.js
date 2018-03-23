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
 * 'uuid' is used for generating a GUID.
 */
const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const tp = require('tedious-promises');
const uuid = require('uuid/v4');

/**
 * Set the default tp promise library to es6 instead of Q.
 */
tp.setPromiseLibrary('es6');

function createCustomer(
    eCommerceWebsiteId,
    title,
    firstName,
    lastName,
    companyName,
    portalUserName,
    address,
    city,
    region,
    postalCode,
    countryCode,
    phoneNumber,
    emailAddress,
    deliveryTitle,
    deliveryFirstName,
    deliveryLastName,
    deliveryName,
    deliveryAddress,
    deliveryCity,
    deliveryRegion,
    deliveryPostalCode,
    deliveryCountryCode,
    deliveryPhoneNumber,
    deliveryEmailAddress) {

    let customerGuid = '';
    let customerId = '';
    let customerBranch = '';
    let error = '';

    return tp.sql("DECLARE @error nvarchar(1000);\
                    DECLARE @contact bigint;\
                    DECLARE @company bigint;\
                    DECLARE @exists bit;\
                    EXEC wsp_RestApiContactsInsert \
                        @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                        @title = '" + title + "',\
                        @firstName = '" + firstName + "',\
                        @lastName = '" + lastName + "',\
                        @companyName = '" + companyName + "',\
                        @portalUserName = '" + portalUserName + "',\
                        @address = '" + address + "',\
                        @city = '" + city + "',\
                        @region = '" + region + "',\
                        @postalCode = '" + postalCode + "',\
                        @countryCode = '" + countryCode + "',\
                        @workPhoneNumber = '" + phoneNumber + "',\
                        @workEmailAddress = '" + emailAddress + "',\
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
                return tp.sql("DECLARE @error nvarchar(1000);\
                                DECLARE @customerGuid nvarchar(36);\
                                DECLARE @customerId nvarchar(10);\
                                DECLARE @customerBranch nvarchar(4);\
                                EXEC wsp_RestApiCustomersSelectByPortalUserName \
                                    @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                                    @portalUserName = '" + portalUserName + "',\
                                    @scope = 'postCustomers',\
                                    @error = @error OUTPUT,\
                                    @customerGuid = @customerGuid OUTPUT,\
                                    @customerId = @customerId OUTPUT,\
                                    @customerBranch = @customerBranch OUTPUT;")
                    .execute()
                    .then((results) => {
                        const result = results[0].ErrorMessage || '';

                        if (result !== '') {
                            throw new Error(result);
                        } else {
                            return {
                                customerGuid: results[0].CustomerGUID,
                                customerId: results[0].CustomerId,
                                customerBranch: results[0].CustomerBranch,
                                errorMessage: error
                            };
                        }
                    })
                    .catch((err) => {
                        throw new Error(err.message);
                    });
            } else {
                return tp.sql("DECLARE @error nvarchar(1000);\
                                DECLARE @customerGuid nvarchar(36);\
                                DECLARE @customerId nvarchar(10);\
                                DECLARE @customerBranch nvarchar(4);\
                                EXEC wsp_RestApiCompaniesPromote \
                                    @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                                    @crmCompany = " + results[0].CRMCompany + ",\
                                    @scope = 'postCustomers',\
                                    @error = @error OUTPUT,\
                                    @customerGuid = @customerGuid OUTPUT,\
                                    @customerId = @customerId OUTPUT,\
                                    @customerBranch = @customerBranch OUTPUT;")
                    .execute()
                    .then((results) => {
                        const result = results[0].ErrorMessage || '';

                        if (result !== '') {
                            throw new Error(result);
                        } else {
                            return {
                                customerGuid: results[0].CustomerGUID,
                                customerId: results[0].CustomerId,
                                customerBranch: results[0].CustomerBranch,
                                errorMessage: error
                            };
                        }
                    })
                    .catch((err) => {
                        throw new Error(err.message);
                    });
            }
        })
        .then((results) => {
            const customer = results;
            
            return tp.sql("DECLARE @error nvarchar(1000);\
                            EXEC wsp_RestApiCustomerDeliveryAddressesInsert \
                                @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                                @customerGuid = '" + customer.customerGuid + "',\
                                @title = '" + deliveryTitle + "',\
                                @firstName = '" + deliveryFirstName + "',\
                                @lastName = '" + deliveryLastName + "',\
                                @deliveryName = '" + deliveryName + "',\
                                @address = '" + deliveryAddress + "',\
                                @city = '" + deliveryCity + "',\
                                @region = '" + deliveryRegion + "',\
                                @postalCode = '" + deliveryPostalCode + "',\
                                @countryCode = '" + deliveryCountryCode + "',\
                                @phoneNumber = '" + deliveryPhoneNumber + "',\
                                @emailAddress = '" + deliveryEmailAddress + "',\
                                @isDefault = 1,\
                                @scope = 'postCustomers',\
                                @error = @error OUTPUT;")
                .execute()
                .then((results) => {
                    const result = results[0].ErrorMessage || '';

                    if (result !== '') {
                        throw new Error(result);
                    } else {
                        return customer;
                    }
                })
                .catch((err) => {
                    throw new Error(err.message);
                });
        })
        .catch((err) => {
            error = err.message;

            return {
                customerGuid: customerGuid,
                customerId: customerId,
                customerBranch: customerBranch,
                errorMessage: error
            };
        });
}

function getConfiguredItemValuesSql(salesOrderItem, guid) {
    let sql = 'DECLARE @error nvarchar(1000);';

    const salesOrderItemOptions = salesOrderItem.Options.map((option) => {
        return new Promise((resolve, reject) => {
            const optionId = option.OptionId || '';
            const optionItemId = option.OptionItemId || '';
            const optionItemPrice = option.OptionItemPrice || 0;

            if (typeof option.OptionId === 'undefined') {
                return reject(utils.reasons.requiredParam + ' OptionId.');
            }

            if (typeof option.OptionItemId === 'undefined') {
                return reject(utils.reasons.requiredParam + ' OptionItemId.');
            }

            if (typeof option.OptionItemPrice === 'undefined') {
                return reject(utils.reasons.requiredParam + ' OptionItemPrice.');
            }

            if (isNaN(parseFloat(optionItemPrice))) {
                return reject(utils.reasons.invalidParam + ' OptionItemPrice. This field should be numeric but a ' + typeof optionItemPrice + ' was detected.');
            }

            sql = sql + "IF @error IS NULL OR @error = '' \
                            BEGIN \
                                EXEC wsp_RestApiConfiguredItemValuesInsert \
                                    @configuration = '" + guid + "',\
                                    @productId = '" + salesOrderItem.Sku + "',\
                                    @configuredStructureOptionId = '" + optionId + "',\
                                    @configuredItemId = '" + optionItemId + "',\
                                    @price = " + optionItemPrice + ",\
                                    @error = @error OUTPUT; \
                            END;";

            return resolve();
        });
    });

    return Promise.all(salesOrderItemOptions)
        .then(() => {
            return sql;
        })
        .catch((message) => {
            return message;
        });
}

/**
 * Create (POST) new sales orders in WinMan.
 */
router.post('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('postSalesOrders') === -1) {
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

    let result = '';

    let customerGuid = req.body.CustomerGuid || '';
    let customerId = req.body.CustomerId || '';
    let customerBranch = req.body.CustomerBranch || '';

    const eCommerceWebsiteId = req.body.Website || '';
    const dueDate = req.body.dueDate || new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString();
    const orderDate = req.body.orderDate || new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString();
    const customerOrderNumber = req.body.CustomerOrderNumber || '';
    let customerContact = '';
    const delName = req.body.SalesOrderShipping.ShippingName || '';
    const delTitle = req.body.SalesOrderShipping.ShippingTitle || '';
    const delFirstName = req.body.SalesOrderShipping.ShippingFirstName || '';
    const delLastName = req.body.SalesOrderShipping.ShippingLastName || '';
    const delAddress = req.body.SalesOrderShipping.ShippingAddress || '';
    const delCity = req.body.SalesOrderShipping.ShippingCity || '';
    const delRegion = req.body.SalesOrderShipping.ShippingRegion || '';
    const delPostalCode = req.body.SalesOrderShipping.ShippingPostalCode || '';
    const delCountryCode = req.body.SalesOrderShipping.ShippingCountryCode || '';
    const delPhoneNumber = req.body.SalesOrderShipping.ShippingPhoneNumber || '';
    const delEmailAddress = req.body.SalesOrderShipping.ShippingEmailAddress || '';

    const billingCompanyName = req.body.SalesOrderBilling.BillingName || '';
    const billingTitle = req.body.SalesOrderBilling.BillingTitle || '';
    const billingFirstName = req.body.SalesOrderBilling.BillingFirstName || '';
    const billingLastName = req.body.SalesOrderBilling.BillingLastName || '';
    const billingAddress = req.body.SalesOrderBilling.BillingAddress || '';
    const billingCity = req.body.SalesOrderBilling.BillingCity || '';
    const billingRegion = req.body.SalesOrderBilling.BillingRegion || '';
    const billingPostalCode = req.body.SalesOrderBilling.BillingPostalCode || '';
    const billingCountryCode = req.body.SalesOrderBilling.BillingCountryCode || '';
    const billingPhoneNumber = req.body.SalesOrderBilling.BillingPhoneNumber || '';
    const billingEmailAddress = req.body.SalesOrderBilling.BillingEmailAddress || '';

    const currencyCode = req.body.CurrencyCode || '';
    const portalUserName = req.body.WebsiteUserName || '';
    const freightMethodId = req.body.SalesOrderShipping.FreightMethodId || '';
    const totalOrderValue = req.body.TotalOrderValue || 0;
    const totalTaxValue = req.body.TotalTaxValue || 0;
    const curTransactionValue = req.body.SalesOrderBilling.CardPaymentReceived || 0;
    const shippingValue = req.body.SalesOrderShipping.ShippingValue || 0;
    const shippingTaxValue = req.body.SalesOrderShipping.ShippingTaxValue || 0;
    const creditCardTypeId = req.body.SalesOrderBilling.PaymentType || '';
    const notes = req.body.Notes || '';
    const coupon = req.body.Coupon || '';
    let salesOrder = 0;
    let salesOrderId = '';

    if (!eCommerceWebsiteId) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' Website.');
    }

    if (!customerOrderNumber) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' CustomerOrderNumber.');
    }

    if (!freightMethodId) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' FreightMethodId.');
    }

    if (!delName) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingName.');
    }

    if (!delAddress) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingAddress.');
    }

    if (!delCountryCode) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingCountryCode.');
    }

    if (!delPostalCode) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingPostalCode.');
    }

    if (!billingCompanyName) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' BillingName.');
    }

    if (!billingAddress) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' BillingAddress.');
    }

    if (!billingCountryCode) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' BillingCountryCode.');
    }

    if (!billingPostalCode) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' BillingPostalCode.');
    }

    if (!currencyCode) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' CurrencyCode.');
    }

    if (!portalUserName) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' WebsiteUserName.');
    }

    if (!creditCardTypeId) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' PaymentType.');
    }

    if (!req.body.hasOwnProperty('SalesOrderBilling')) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' SalesOrderBilling object.');
    }

    if (!req.body.hasOwnProperty('SalesOrderShipping')) {
        return utils.reject(res, req, utils.reasons.requiredParam + ' SalesOrderShipping object.');
    }

    if (typeof req.body.TotalOrderValue === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam + ' TotalOrderValue.');
    }

    if (typeof req.body.TotalTaxValue === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam + ' TotalTaxValue.');
    }

    if (typeof req.body.SalesOrderShipping.ShippingValue === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingValue.');
    }

    if (typeof req.body.SalesOrderShipping.ShippingTaxValue === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam + ' ShippingTaxValue.');
    }

    customerContact = delName;

    const numeric = 'This field should be numeric but a ';

    if (isNaN(parseFloat(totalOrderValue))) {
        return utils.reject(res, req, utils.reasons.invalidParam + ' TotalOrderValue. ' + numeric + typeof totalOrderValue + ' was detected.');
    }

    if (isNaN(parseFloat(shippingValue))) {
        return utils.reject(res, req, utils.reasons.invalidParam + ' ShippingValue. ' + numeric + typeof shippingValue + ' was detected.');
    }

    if (isNaN(parseFloat(shippingTaxValue))) {
        return utils.reject(res, req, utils.reasons.invalidParam + ' ShippingValue. ' + numeric + typeof shippingTaxValue + ' was detected.');
    }

    if (isNaN(parseFloat(totalTaxValue))) {
        return utils.reject(res, req, utils.reasons.invalidParam + ' TotalTaxValue. ' + numeric + typeof totalTaxValue + ' was detected.');
    }

    if (isNaN(parseFloat(curTransactionValue))) {
        return utils.reject(res, req, utils.reasons.invalidParam + ' CardPaymentReceived. ' + numeric + typeof curTransactionValue + ' was detected.');
    }

    let customer;

    /**
     * If all 3 of customerGuid, customerId and customerBranch are missing,
     * assume customer is new and create records in WinMan.
     */
    if (!customerGuid && !customerId && !customerBranch) {
        let firstName = billingFirstName;
        let lastName = billingLastName;

        if (!firstName || !lastName) {
            let names = billingCompanyName.split(' ');
            lastName = names.pop();
            firstName = names.join(' ');
        }

        firstName = (firstName) ? firstName : 'unknown';
        lastName = (lastName) ? lastName : 'unknown';

        customer = createCustomer(
            eCommerceWebsiteId,
            billingTitle,
            firstName,
            lastName,
            billingCompanyName,
            portalUserName,
            billingAddress,
            billingCity,
            billingRegion,
            billingPostalCode,
            billingCountryCode,
            billingPhoneNumber,
            billingEmailAddress,
            delTitle,
            delFirstName,
            delLastName,
            delName,
            delAddress,
            delCity,
            delRegion,
            delPostalCode,
            delCountryCode,
            delPhoneNumber,
            delEmailAddress);
    } else {
        customer = new Promise((resolve) => {
            const info = {
                customerGuid: customerGuid,
                customerId: customerId,
                customerBranch: customerBranch,
                errorMessage: ''
            };
            resolve(info);
        });
    }

    Promise.all([customer]).then((data) => {
        customerGuid = data[0].customerGuid;
        customerId = data[0].customerId;
        customerBranch = data[0].customerBranch;

        if (data[0].errorMessage !== '') {
            return utils.reject(res, req, data[0].errorMessage);
        } else {
            /** 
             * If customerId supplied and customerBranch missing (or vice versa) 
             * and customerGuid also missing, return error.
             */
            if (!customerGuid && (!customerId || !customerBranch)) {
                let missingParameter;
                let suppliedParameter;

                if (customerId) {
                    missingParameter = 'CustomerBranch';
                    suppliedParameter = 'CustomerId';
                } else {
                    missingParameter = 'CustomerId';
                    suppliedParameter = 'CustomerBranch';
                }

                return utils.reject(res, req, utils.reasons.invalidParam + ' '
                    + missingParameter + '. You have supplied ' + suppliedParameter
                    + ' but not ' + missingParameter + '.');
            }

            let transaction;

            tp.beginTransaction()
                .then(function (trans) {
                    transaction = trans;
                    return transaction.sql("DECLARE @error nvarchar(1000);\
                                            DECLARE @salesOrder bigint;\
                                            DECLARE @salesOrderId nvarchar(15);\
                                            DECLARE @guid nvarchar(36);\
                                            DECLARE @id nvarchar(10);\
                                            DECLARE @branch nvarchar(4);\
                                            EXEC wsp_RestApiSalesOrdersInsert \
                                                @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                                                @customerGuid = '" + customerGuid + "',\
                                                @customerId = '" + customerId + "',\
                                                @customerBranch = '" + customerBranch + "',\
                                                @dueDate = '" + dueDate + "',\
                                                @orderDate = '" + orderDate + "',\
                                                @customerOrderNumber = '" + customerOrderNumber + "',\
                                                @customerContact = '" + customerContact + "',\
                                                @delName = '" + delName + "',\
                                                @delTitle = '" + delTitle + "',\
                                                @delFirstName = '" + delFirstName + "',\
                                                @delLastName = '" + delLastName + "',\
                                                @delAddress = '" + delAddress + "',\
                                                @delCity = '" + delCity + "',\
                                                @delRegion = '" + delRegion + "',\
                                                @delPostalCode = '" + delPostalCode + "',\
                                                @delCountryCode = '" + delCountryCode + "',\
                                                @delPhoneNumber = '" + delPhoneNumber + "',\
                                                @delEmailAddress = '" + delEmailAddress + "',\
                                                @currencyCode = '" + currencyCode + "',\
                                                @portalUserName = '" + portalUserName + "',\
                                                @freightMethodId = '" + freightMethodId + "',\
                                                @notes = '" + notes + "',\
                                                @coupon = '" + coupon + "',\
                                                @curValuePaid = " + curTransactionValue + ",\
                                                @scope = 'postSalesOrders',\
                                                @error = @error OUTPUT,\
                                                @salesOrder = @salesOrder OUTPUT,\
                                                @guid = @guid OUTPUT,\
                                                @id = @id OUTPUT,\
                                                @branch = @branch OUTPUT,\
                                                @salesOrderId = @salesOrderId OUTPUT;")
                        .execute();
                })
                .then((results) => {
                    result = results[0].ErrorMessage || '';

                    if (result === '') {
                        salesOrder = results[0].SalesOrder;
                        salesOrderId = results[0].SalesOrderId;

                        customerGuid = (customerGuid) ? customerGuid : results[0].CustomerGUID;
                        customerId = (customerId) ? customerId : results[0].CustomerId;
                        customerBranch = (customerBranch) ? customerBranch : results[0].CustomerBranch;
                    } else {
                        throw new Error(result);
                    }

                    return transaction.sql("EXEC wsp_RestApiSalesOrderItemsInsert \
                                                @salesOrder = " + salesOrder + ",\
                                                @itemType = 'F',\
                                                @quantity = 1,\
                                                @delName = '" + delName + "',\
                                                @delTitle = '" + delTitle + "',\
                                                @delFirstName = '" + delFirstName + "',\
                                                @delLastName = '" + delLastName + "',\
                                                @delAddress = '" + delAddress + "',\
                                                @delCity = '" + delCity + "',\
                                                @delRegion = '" + delRegion + "',\
                                                @delPostalCode = '" + delPostalCode + "',\
                                                @delCountryCode = '" + delCountryCode + "',\
                                                @delPhoneNumber = '" + delPhoneNumber + "',\
                                                @delEmailAddress = '" + delEmailAddress + "',\
                                                @freightMethodId = '" + freightMethodId + "',\
                                                @curValue = " + shippingValue + ",\
                                                @curTaxValue = " + shippingTaxValue + ";")
                        .execute();
                })
                .then((results) => {
                    result = results[0].ErrorMessage || '';

                    if (result !== '') {
                        throw new Error(result);
                    }

                    let sql = '';

                    const salesOrderItems = req.body.SalesOrderItems.map((salesOrderItem) => {
                        return new Promise((resolve, reject) => {
                            const sku = salesOrderItem.Sku || '';
                            const curValue = salesOrderItem.OrderLineValue || 0;
                            const curTaxValue = salesOrderItem.OrderLineTaxValue || 0;
                            const quantity = salesOrderItem.Quantity || 0;
                            const useConfigurator = salesOrderItem.UseConfigurator || false;

                            if (typeof salesOrderItem.Sku === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' Sku.');
                            }

                            if (typeof salesOrderItem.OrderLineValue === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' OrderLineValue.');
                            }

                            if (typeof salesOrderItem.OrderLineTaxValue === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' OrderLineTaxValue.');
                            }

                            if (typeof salesOrderItem.Quantity === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' Quantity.');
                            }

                            if (isNaN(parseFloat(curValue))) {
                                return reject(utils.reasons.invalidParam + ' OrderLineValue. ' + numeric + typeof salesOrderItem.OrderLineValue + ' was detected.');
                            }

                            if (isNaN(parseFloat(curTaxValue))) {
                                return reject(utils.reasons.invalidParam + ' OrderLineTaxValue. ' + numeric + typeof salesOrderItem.OrderLineTaxValue + ' was detected.');
                            }

                            if (isNaN(parseFloat(quantity))) {
                                return reject(utils.reasons.invalidParam + ' Quantity. ' + numeric + typeof salesOrderItem.Quantity + ' was detected.');
                            }

                            if (typeof salesOrderItem.UseConfigurator !== 'undefined' && typeof salesOrderItem.UseConfigurator !== 'boolean') {
                                return reject(utils.reasons.invalidParam + ' UseConfigurator. This field should be a boolean but a ' + typeof salesOrderItem.UseConfigurator + ' was detected.');
                            }

                            if (useConfigurator) {
                                const configuredSku = salesOrderItem.ConfiguredSku || '';

                                if (typeof salesOrderItem.ConfiguredSku === 'undefined') {
                                    return reject(utils.reasons.requiredParam + ' ConfiguredSku.');
                                }

                                if (typeof salesOrderItem.Options === 'undefined') {
                                    return reject(utils.reasons.requiredParam + ' Options.');
                                }


                                if (typeof salesOrderItem.Options !== 'object') {
                                    return reject(utils.reasons.invalidParam
                                        + ' Options. This field should be an array but a '
                                        + typeof salesOrderItem.Options + ' was detected.');
                                }

                                if (Object.keys(salesOrderItem.Options).length === 0) {
                                    return reject(utils.reasons.requiredParam + ' Options. The Options array cannot be empty but you have supplied an empty array.');
                                }

                                const guid = uuid();
                                const itemValues = getConfiguredItemValuesSql(salesOrderItem, guid);

                                itemValues.then((result) => {
                                    if (result.indexOf('EXEC') === -1) {
                                        reject(result);
                                    }

                                    sql = sql + result
                                        + "IF @error IS NULL OR @error = '' \
                                            BEGIN \
                                                EXEC wsp_RestApiSalesOrderItemsInsert \
                                                    @salesOrder = " + salesOrder + ",\
                                                    @itemType = 'N',\
                                                    @sku = '" + sku + "',\
                                                    @quantity = " + quantity + ",\
                                                    @delName = '" + delName + "',\
                                                    @delTitle = '" + delTitle + "',\
                                                    @delFirstName = '" + delFirstName + "',\
                                                    @delLastName = '" + delLastName + "',\
                                                    @delAddress = '" + delAddress + "',\
                                                    @delCity = '" + delCity + "',\
                                                    @delRegion = '" + delRegion + "',\
                                                    @delPostalCode = '" + delPostalCode + "',\
                                                    @delCountryCode = '" + delCountryCode + "',\
                                                    @delPhoneNumber = '" + delPhoneNumber + "',\
                                                    @delEmailAddress = '" + delEmailAddress + "',\
                                                    @curValue = " + curValue + ",\
                                                    @curTaxValue = " + curTaxValue + ", \
                                                    @configuration = '" + guid + "', \
                                                    @pseudoSku = '" + configuredSku + "'; \
                                            END;";

                                    return resolve();
                                })
                                    .catch((message) => {
                                        reject(message);
                                    });
                            } else {
                                sql = sql + "EXEC wsp_RestApiSalesOrderItemsInsert \
                                                @salesOrder = " + salesOrder + ",\
                                                @itemType = 'P',\
                                                @sku = '" + sku + "',\
                                                @quantity = " + quantity + ",\
                                                @delName = '" + delName + "',\
                                                @delTitle = '" + delTitle + "',\
                                                @delFirstName = '" + delFirstName + "',\
                                                @delLastName = '" + delLastName + "',\
                                                @delAddress = '" + delAddress + "',\
                                                @delCity = '" + delCity + "',\
                                                @delRegion = '" + delRegion + "',\
                                                @delPostalCode = '" + delPostalCode + "',\
                                                @delCountryCode = '" + delCountryCode + "',\
                                                @delPhoneNumber = '" + delPhoneNumber + "',\
                                                @delEmailAddress = '" + delEmailAddress + "',\
                                                @curValue = " + curValue + ",\
                                                @curTaxValue = " + curTaxValue + ";";

                                return resolve();
                            }
                        });
                    });

                    return Promise.all(salesOrderItems).then(() => {
                        return transaction.sql(sql)
                            .execute();
                    })
                        .catch((message) => {
                            throw new Error(message);
                        });
                })
                .then((results) => {
                    result = results[0].ErrorMessage || '';

                    results.map(qry => {
                        if (qry.ErrorMessage !== 'undefined') {
                            result = qry.ErrorMessage;
                        }
                    });

                    if (result !== '') {
                        throw new Error(result);
                    }

                    if (creditCardTypeId.toLowerCase().replace(/\s/g, '') === 'onaccount') {
                        const results = [{ ErrorMessage: '' }];
                        return results;
                    } else {
                        return transaction.sql("DECLARE @error nvarchar(1000);\
                                                EXEC wsp_RestApiSalesOrdersPayment \
                                                    @salesOrder = " + salesOrder + ",\
                                                    @creditCardTypeId = '" + creditCardTypeId + "',\
                                                    @curTransactionValue = " + curTransactionValue + ",\
                                                    @error = @error OUTPUT;")
                            .execute();
                    }
                })
                .then((results) => {
                    result = results[0].ErrorMessage || '';

                    if (result !== '') {
                        throw new Error(result);
                    }

                    return transaction.sql("DECLARE @error nvarchar(1000);\
                                            EXEC wsp_RestApiSalesOrdersFinalise \
                                                @salesOrder = " + salesOrder + ",\
                                                @totalOrderValue = " + totalOrderValue + ",\
                                                @error = @error OUTPUT;")
                        .execute();
                })
                .then((results) => {
                    result = results[0].ErrorMessage || '';

                    if (result !== '') {
                        throw new Error(result);
                    } else {
                        utils.success(res, req, {
                            Status: "Success",
                            SalesOrderId: salesOrderId,
                            CustomerGUID: customerGuid,
                            CustomerId: customerId,
                            CustomerBranch: customerBranch
                        });
                        return transaction.commitTransaction();
                    }
                })
                .catch((err) => {
                    logger.error(err.stack);
                    utils.reject(res, req, err.message);

                    return transaction.rollbackTransaction();
                });
        }
    });
});

/**
 * Fetch (GET) existing sales orders or quotes from WinMan.
 */
router.get('/', passport.authenticate('bearer', { session: false }), function (req, res, next) {
    const inputParams = [];
    const scopes = req.authInfo.scope.split(',');

    if (scopes.indexOf('getSalesOrders') === -1) {
        res.status(403);
        res.send(utils.reasons.inadequateAccess);
        return;
    } else {
        inputParams.push("@scope = 'getSalesOrders'");
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

    if (typeof res.locals.returntype !== 'undefined') {
        if (res.locals.returntype.toLowerCase() !== 'orders' && res.locals.returntype.toLowerCase() !== 'quotes') {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' returntype. This field only accepts the values orders or quotes. You have supplied: '
                + res.locals.returntype + '.');
        } else {
            inputParams.push("@systemType = '" + res.locals.returntype.charAt(0).toUpperCase() + "'");
        }
    } else {
        inputParams.push("@systemType = 'O'");
    }

    if (typeof res.locals.orderby !== 'undefined') {
        const acceptedValues = {
            'salesorderid': 'SalesOrderId',
            'quoteid': 'SalesOrderId',
            'customerreference': 'CustomerOrderNumber',
            'date': 'EffectiveDate',
            'status': 'SystemType',
            'value': 'OrderValue'
        };

        const column = res.locals.orderby.toLowerCase();

        if (acceptedValues.hasOwnProperty(column)) {
            inputParams.push("@orderBy = '" + acceptedValues[column] + "'");
        } else {
            return utils.reject(res, req, utils.reasons.invalidParam
                + ' orderby. This field only accepts the values salesorderid, quoteid, customerreference, date, status or value. You have supplied: '
                + res.locals.orderby + '.');
        }
    } else {
        inputParams.push("@orderBy = 'SalesOrderId'");
    }

    if (typeof res.locals.salesorderid !== 'undefined'
        && (typeof res.locals.returntype === 'undefined'
            || res.locals.returntype.toLowerCase() === 'orders')) {
        inputParams.push("@salesOrderId = '" + res.locals.salesorderid + "'");
    }

    if (typeof res.locals.quoteid !== 'undefined'
        && typeof res.locals.returntype !== 'undefined'
        && res.locals.returntype.toLowerCase() === 'quotes') {
        inputParams.push("@salesOrderId = '" + res.locals.quoteid + "'");
    }

    if (typeof res.locals.customerordernumber !== 'undefined') {
        inputParams.push("@customerOrderNumber = '" + res.locals.customerordernumber + "'");
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
        sp: 'wsp_RestApiSalesOrdersSelect',
        args: inputParams
    };

    return utils.executeSelect(res, req, params);
});

module.exports = router;
