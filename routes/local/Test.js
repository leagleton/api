'use strict';

const router = require('express').Router();

/* GET all web enabled customers. */
router.get('/', function (req, res, next) {
    res.status(200);
    res.send("All good (local) :).");
});

module.exports = router;
