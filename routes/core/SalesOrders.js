'use strict';

const router = require('express').Router();
const passport = require('passport');
const utils = require('../utils');
const logger = require('../../middleware/logger');
const config = require('../../config');
const tp = require('tedious-promises');
tp.setPromiseLibrary('es6');

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

    const eCommerceWebsiteId = req.body.Website || '';
    const customerGuid = req.body.CustomerGuid || '';
    const customerId = req.body.CustomerId || '';
    const customerBranch = req.body.CustomerBranch || '';
    const effectiveDate = req.body.EffectiveDate || new Date(Date.now() - ((new Date()).getTimezoneOffset() * 60000)).toISOString();
    const customerOrderNumber = req.body.CustomerOrderNumber || '';
    let customerContact = '';
    let delName = req.body.SalesOrderShipping.ShippingName || '';
    let delTitle = req.body.SalesOrderShipping.ShippingTitle || '';
    let delFirstName = req.body.SalesOrderShipping.ShippingFirstName || '';
    let delLastName = req.body.SalesOrderShipping.ShippingLastName || '';
    let delAddress = req.body.SalesOrderShipping.ShippingAddress || '';
    let delCity = req.body.SalesOrderShipping.ShippingCity || '';
    let delRegion = req.body.SalesOrderShipping.ShippingRegion || '';
    let delPostalCode = req.body.SalesOrderShipping.ShippingPostalCode || '';
    let delCountryCode = req.body.SalesOrderShipping.ShippingCountryCode || '';
    let delPhoneNumber = req.body.SalesOrderShipping.ShippingPhoneNumber || '';
    let delEmailAddress = req.body.SalesOrderShipping.ShippingEmailAddress || '';
    const currencyCode = req.body.CurrencyCode || '';
    const portalUserName = req.body.WebsiteUserName || '';
    const freightMethodId = req.body.SalesOrderShipping.FreightMethodId || '';
    const totalOrderValue = req.body.TotalOrderValue || 0;
    let salesOrder = 0;
    let salesOrderId = '';

    if (isNaN(parseFloat(totalOrderValue)) || isNaN(parseFloat(req.body.SalesOrderShipping.Price))) {
        return utils.reject(res, req, utils.reasons.invalidParam);
    }

    if (typeof req.body.TotalOrderValue === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (!eCommerceWebsiteId || !customerOrderNumber || !freightMethodId || !delName ||
        !delAddress || !delCountryCode || !delPostalCode || !currencyCode || !portalUserName) {
        return utils.reject(res, req, utils.reasons.requiredParam);
    } else {
        customerContact = delName;
    }

    if (!customerGuid && (!customerId && !customerBranch)) {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (!req.body.hasOwnProperty('SalesOrderBilling')) {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (!req.body.hasOwnProperty('SalesOrderShipping')) {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    if (typeof req.body.SalesOrderShipping.Price === 'undefined') {
        return utils.reject(res, req, utils.reasons.requiredParam);
    }

    let transaction;

    tp.beginTransaction()
        .then(function (trans) {
            transaction = trans;

            return transaction.sql("EXEC wsp_RestApiSalesOrdersInsert \
                    @eCommerceWebsiteId = '" + eCommerceWebsiteId + "',\
                    @customerGuid = '" + customerGuid + "',\
                    @customerId = '" + customerId + "',\
                    @customerBranch = '" + customerBranch + "',\
                    @effectiveDate = '" + effectiveDate + "',\
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
                    @scope = 'postSalesOrders'")
                .execute();
        })
        .then((results) => {
            result = results[0].ErrorMessage || '';

            if (result === '') {
                salesOrder = results[0].SalesOrder;
                salesOrderId = results[0].SalesOrderId;
            } else {
                throw new Error(result);
            }
            
            const curPrice = req.body.SalesOrderShipping.Price;

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
                    @curPrice = " + curPrice)
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

                    if (!delName || !delAddress || !delCountryCode || !delPostalCode) {
                        return reject(utils.reasons.requiredParam);
                    }

                    const curPrice = salesOrderItem.Price || 0;

                    if (!quantity) {
                        return reject(utils.reasons.requiredParam);
                    }

                    if (isNaN(parseFloat(curPrice)) || isNaN(parseFloat(quantity))) {
                        return reject(utils.reasons.invalidParam);
                    }

                    if (typeof salesOrderItem.Price === 'undefined') {
                        return reject(utils.reasons.requiredParam);
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
                        @curPrice = " + curPrice + ";";

                    return resolve();
                });
            });

            return Promise.all(salesOrderItems).then(() => {
                return transaction.sql(sql)
                    .execute();
            });
        })
        .then((results) => {
            result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            }

            const creditCardTypeId = req.body.SalesOrderBilling.PaymentType || '';
            const curTransactionValue = req.body.SalesOrderBilling.CardPaymentReceived || 0;

            if (typeof curTransactionValue === 'undefined' || !creditCardTypeId) {
                throw new Error(utils.reasons.requiredParam);
            }

            if (isNaN(parseFloat(curTransactionValue))) {
                throw new Error(utils.reasons.invalidParam);
            }

            return transaction.sql("DECLARE @error NVARCHAR(1000) EXEC wsp_RestApiSalesOrdersPayment \
                    @salesOrder = " + salesOrder + ",\
                    @creditCardTypeId = '" + creditCardTypeId + "',\
                    @curTransactionValue = " + curTransactionValue + ",\
                    @error = @error OUTPUT")
                .execute();
        })
        .then((results) => {
            result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            }

            return transaction.sql("DECLARE @error NVARCHAR(1000) EXEC wsp_RestApiSalesOrdersFinalise \
                    @salesOrder = " + salesOrder + ",\
                    @totalOrderValue = " + totalOrderValue + ",\
                    @error = @error OUTPUT")
                .execute();
        })
        .then((results) => {
            result = results[0].ErrorMessage || '';

            if (result !== '') {
                throw new Error(result);
            } else {
                utils.success(res, req, {
                    Status: "Success",
                    SalesOrder: salesOrder,
                    SalesOrderId: salesOrderId
                });
                return transaction.commitTransaction();
            }
        })
        .catch((err) => {
            let status = 500;

            for (const reason in utils.reasons) {
                if (err.message === utils.reasons[reason] && utils.reasons[reason] !== utils.reasons.unspecified) {
                    status = 400;
                }
            }

            if (err.message.indexOf('input data') > -1 ||
                err.message.indexOf('parameter missing') > -1 ||
                err.message.indexOf('converting data type') > -1 ||
                err.message.indexOf('expects parameter') > -1) {
                status = 400;
            }

            if (status === 500) {
                logger.error(err.stack);
                utils.error(res, req, err.message);
            } else {
                utils.reject(res, req, err.message);
            }

            return transaction.rollbackTransaction();
        })
});

module.exports = router;
