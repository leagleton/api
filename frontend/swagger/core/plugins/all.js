import { pascalCaseFilename } from "core/utils"

const request = require.context(".", true, /\.jsx?$/)

request.keys().forEach(function (key) {
  if (key === "./index.js") {
    return
  }

  let mod = request(key)
  module.exports[pascalCaseFilename(key)] = mod.default ? mod.default : mod
})
