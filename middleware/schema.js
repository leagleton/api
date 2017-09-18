'use strict';
// Update the URLs in swagger.json so that the file validates correctly.
// Better to add URLs this way because we only need to specify once in our app's config file then :).

const logger = require('./logger');
const fs = require('fs');
const config = require('../config');
const path = require('path');
const version = require('../package.json').version;

function compare(a, b) {
    if (a.filename < b.filename)
        return -1;
    if (a.filename > b.filename)
        return 1;
    return 0;
}

function read(coreDir, localDir) {
    const fileContents = [];

    const coreFiles = new Promise((resolve, reject) => {
        fs.readdir(coreDir, function (err, fileNames) {
            if (err) return reject(new Error(err.message));

            const files = fileNames.map((filename, index) => {
                return new Promise((resolve, reject) => {
                    if (filename.substr(filename.lastIndexOf('.') + 1).toLowerCase() !== 'json') {
                        return resolve();
                    }
                    return fs.stat(path.resolve(localDir, filename), function (err, stats) {
                        if (!err && stats.isFile()) {
                            return resolve();
                        } else {
                            return fs.readFile(path.resolve(coreDir, filename), 'utf-8', function (err, content) {
                                if (err) return reject(err);
                                fileContents.push({ filename: filename, contents: content });
                                return resolve();
                            });
                        }
                    });
                })
                    .catch(err => logger.error(err.stack));
            });
            return Promise.all(files).then(() => resolve());
        });
    })
        .catch(err => logger.error(err.stack));

    const localFiles = new Promise((resolve, reject) => {
        fs.readdir(localDir, function (err, fileNames) {
            if (err) return reject(new Error(err.message));

            const files = fileNames.map((filename, index) => {
                return new Promise((resolve, reject) => {
                    if (filename.substr(filename.lastIndexOf('.') + 1).toLowerCase() !== 'json') {
                        return resolve();
                    }                  
                    return fs.readFile(path.resolve(localDir, filename), 'utf-8', function (err, content) {
                        if (err) return reject(new Error(err.message));
                        fileContents.push({ filename: filename, contents: content });
                        return resolve();
                    })
                })
                    .catch(err => logger.error(err.stack));;
            });

            return Promise.all(files).then(() => resolve());
        });
    })
        .catch(err => logger.error(err.stack));;

    return Promise.all([coreFiles, localFiles])
        .then(() => fileContents.sort(compare))
        .then(() => fileContents);
}

exports.build = function (req) {
    if (typeof req.session.system == 'undefined' || typeof req.session.generating != 'undefined') {
        return;
    }
    req.session.generating = true;

    const definitions = new Promise((resolve) => {
        const swaggerDefinitions = {};

        return read('./views/static/swagger/schema/definitions/core/', './views/static/swagger/schema/definitions/local/')
            .then(files => {
                const fetchedFiles = files.map((item, index) => {
                    return new Promise((resolve) => {
                        let key = item.filename.replace(/\.[^/.]+$/, "");
                        swaggerDefinitions[key] = JSON.parse(item.contents)[key];
                        return resolve();
                    })
                        .catch(err => logger.error(err.stack));
                });

                return Promise.all(fetchedFiles)
                    .then(() => swaggerDefinitions);
            })
            .then(definitions => resolve(definitions))
            .catch(err => logger.error(err.stack));
    });

    const paths = new Promise((resolve) => {
        const swaggerPaths = {};

        return read('./views/static/swagger/schema/paths/core/', './views/static/swagger/schema/paths/local/')
            .then(files => {
                const fetchedFiles = files.map((item, index) => {
                    return new Promise((resolve) => {
                        let key = "/" + item.filename.replace(/\.[^/.]+$/, "");
                        key = key.toLowerCase();
                        swaggerPaths[key] = JSON.parse(item.contents)[key];
                        return resolve();
                    })
                        .catch(err => logger.error(err.stack));
                });

                return Promise.all(fetchedFiles).then(() => swaggerPaths);
            })
            .then(paths => resolve(paths))
            .catch(err => logger.error(err.stack));
    });

    const tags = new Promise((resolve) => {
        const swaggerTags = {};

        return read('./views/static/swagger/schema/tags/core/', './views/static/swagger/schema/tags/local/')
            .then(files => {
                const fetchedFiles = files.map((item, index) => {
                    return new Promise((resolve) => {
                        let key = item.filename.replace(/\.[^/.]+$/, "");
                        key = key.toLowerCase();
                        swaggerTags[key] = JSON.parse(item.contents)[key];
                        return resolve();
                    })
                        .catch(err => logger.errorAndExit(5, err.message, err.stack));
                });

                return Promise.all(fetchedFiles).then(() => swaggerTags);
            })
            .then(tags => resolve(tags))
            .catch(err => logger.errorAndExit(5, err.stack));
    });

    Promise.all([definitions, paths, tags]).then((data) => {
        const swaggerDefinitions = data[0];
        const swaggerPaths = data[1];
        const swaggerTags = data[2];

        const swaggerDist = './views/static/swagger/swagger.json.dist';
        const swaggerFile = './views/static/swagger/schema/' + req.sessionID + '.json';

        fs.readFile(swaggerDist, function (err, data) {
            if (err) {
                try {
                    throw new Error(err.message);
                } catch (e) {
                    return logger.errorAndExit(5, e.stack);
                }
            }

            const json = JSON.parse(data);

            json.definitions = swaggerDefinitions;
            json.paths = swaggerPaths;
            json.tags = swaggerTags.tags

            json.host = config.server.host + ":" + config.server.port;

            const url = config.server.scheme + "://" + json.host;

            const tokenUrl = url + "/oauth/token";
            const authUrl = url + "/oauth/auth";

            json.securityDefinitions.OAuth2.tokenUrl = tokenUrl;
            json.securityDefinitions.OAuth2.authorizationUrl = authUrl;

            json.info.version = version;

            json.basePath = (req.session.system === 'training') ? '/training' : '/api';

            fs.writeFile(swaggerFile, JSON.stringify(json), function (err) {
                if (err) {
                    try {
                        throw new Error(err.message);
                    } catch (e) {
                        return logger.errorAndExit(5, e.stack);
                    }
                }
                logger.log('Swagger schema successfully generated.');
            });
        });
    });
}
