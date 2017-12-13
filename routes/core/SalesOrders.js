'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

function createCustomer(
    eCommerceWebsiteId,
    firstName,
    lastName,
    portalUserName,
    address,
    postalCode,
    countryCode) {

    let customerGuid = '';
    let customerId = '';
    let customerBranch = '';
    let error = '';

    return tp.sql("DECLARE @error nvarchar(1000);\
                    DECLARE @contact bigint;\
                    DECLARE @company bigint;\
                    EXEC wsp_RestApiContactsInsert \
                        @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                        @firstName = '" + firstName + "',\
                        @lastName = '" + lastName + "',\
                        @portalUserName = '" + portalUserName + "',\
                        @address = '" + address + "',\
                        @postalCode = '" + postalCode + "',\
                        @countryCode = '" + countryCode + "',\
                        @scope = 'postCustomers',\
                        @error = @error OUTPUT,\
                        @contact = @contact OUTPUT,\
                        @company = @company OUTPUT;")
        .execute()
        .then((results) => {
            const result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
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

/* Create new sales orders in WinMan. */
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
        let firstName = delFirstName;
        let lastName = delLastName;

        if (!firstName || !lastName) {
            let names = customerContact.split(' ');
            lastName = names.pop();
            firstName = names.join(' ');
        }

        firstName = (firstName) ? firstName : 'unknown';
        lastName = (lastName) ? lastName : 'unknown';

        customer = createCustomer(
            eCommerceWebsiteId,
            firstName,
            lastName,
            portalUserName,
            delAddress,
            delPostalCode,
            delCountryCode);
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
                                                @curTaxValue = " + shippingTaxValue)
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
                            const quantity = salesOrderItem.Quantity || 0;

                            const curValue = salesOrderItem.OrderLineValue || 0;
                            const curTaxValue = salesOrderItem.OrderLineTaxValue || 0;

                            if (!quantity) {
                                return reject(utils.reasons.requiredParam + ' Quantity.');
                            }

                            if (isNaN(parseFloat(curTaxValue))) {
                                return reject(utils.reasons.invalidParam + ' OrderLineTaxValue. ' + numeric + typeof salesOrderItem.OrderLineTaxValue + ' was detected.');
                            }

                            if (isNaN(parseFloat(quantity))) {
                                return reject(utils.reasons.invalidParam + ' Quantity. ' + numeric + typeof salesOrderItem.Quantity + ' was detected.');
                            }
                            
                            if (isNaN(parseFloat(curValue))) {
                                return reject(utils.reasons.invalidParam + ' OrderLineValue. ' + numeric + typeof salesOrderItem.OrderLineValue + ' was detected.');
                            }

                            if (typeof salesOrderItem.Sku === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' Sku.');
                            }                                                       

                            if (typeof salesOrderItem.OrderLineValue === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' OrderLineValue.');
                            }

                            if (typeof salesOrderItem.OrderLineTaxValue === 'undefined') {
                                return reject(utils.reasons.requiredParam + ' OrderLineTaxValue.');
                            }

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
                                                    @error = @error OUTPUT")
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

module.exports = router;
