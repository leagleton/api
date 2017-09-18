const router = require('express').Router();
const fs = require('fs');
const logger = require('../middleware/logger');
const path = require('path');

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
              router.use('/' + filename.toLowerCase().replace(/\.[^/.]+$/, ""), require('./' + coreDir + filename));
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
          router.use('/' + filename.toLowerCase().replace(/\.[^/.]+$/, ""), require('./' + localDir + filename));
          return resolve();
        })
          .catch(err => logger.error(err.stack));;
      });

      return Promise.all(files).then(() => resolve());
    });
  })
    .catch(err => logger.error(err.stack));;

  return Promise.all([coreFiles, localFiles])
    .then(() => logger.log("API Routes configured."));
}

read('core/', 'local/');

module.exports = router;
