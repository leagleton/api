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
 * 'fs' is used to interact with the file system.
 * 'logger' is used to define our custom logging functions.
 * 'path' is used to correctly handle file paths.
 */
const router = require('express').Router();
const fs = require('fs');
const logger = require('../middleware/logger');
const path = require('path');

/**
 * Cycle through all of our core and local route (endpoint) files and generate
 * the .use() functions based on the file names.
 * 
 * @param   {String}  coreDir  - The relative filepath of the core routes directory.
 * @param   {String}  localDir - The relative filepath of the local routes directory.
 * @returns {Promise} Resolved with all of the application's endpoints.
 */
function read(coreDir, localDir) {
  const coreFiles = new Promise((resolve, reject) => {
    fs.readdir('./routes/' + coreDir, function (err, fileNames) {
      if (err) return reject(new Error(err.message));

      const files = fileNames.map((filename, index) => {
        return new Promise((resolve) => {
          if (filename.substr(filename.lastIndexOf('.') + 1).toLowerCase() !== 'js') {
            return resolve();
          }
          return fs.stat(path.resolve('./routes/' + localDir, filename), function (err, stats) {
            if (!err && stats.isFile()) {
              return resolve();
            } else {
              router.use('/' + filename.toLowerCase().split(/[.]/)[0], require('./' + coreDir + filename));
              return resolve();
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
    fs.readdir('./routes/' + localDir, function (err, fileNames) {
      if (err) return reject(new Error(err.message));

      const files = fileNames.map((filename, index) => {
        return new Promise((resolve) => {
          if (filename.substr(filename.lastIndexOf('.') + 1).toLowerCase() !== 'js') {
            return resolve();
          }
          router.use('/' + filename.toLowerCase().split(/[.]/)[0], require('./' + localDir + filename));
          return resolve();
        })
          .catch(err => logger.error(err.stack));;
      });

      return Promise.all(files).then(() => resolve());
    });
  })
    .catch(err => logger.error(err.stack));

  return Promise.all([coreFiles, localFiles])
    .then(() => logger.log('API Routes configured.'));
}

read('core/', 'local/');

module.exports = router;
