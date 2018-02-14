import deepExtend from 'deep-extend'
import System from 'core/system'
import win from 'core/window'
import Base from 'core/plugins/base'
import { parseSearch } from 'core/utils'

const { PACKAGE_VERSION, HOSTNAME, BUILD_TIME } = buildInfo

module.exports = function SwaggerUI(opts) {
  win.versions = win.versions || {}
  win.versions.swaggerUi = {
    version: PACKAGE_VERSION,
    buildTimestamp: BUILD_TIME,
    machine: HOSTNAME
  }

  const defaults = {
    dom_id: '#swagger-ui',
    domNode: null,
    spec: {},
    url: '',
    urls: null,
    layout: 'BaseLayout',
    docExpansion: 'list',
    maxDisplayedTags: null,
    filter: null,
    validatorUrl: 'https://online.swagger.io/validator',
    configs: {},
    custom: {},
    displayOperationId: false,
    displayRequestDuration: false,
    deepLinking: true,
    plugins: [
      Base
    ],
    fn: {},
    components: {},
    state: {},
    store: {}
  }

  let queryConfig = parseSearch()

  const constructorConfig = deepExtend({}, defaults, opts, queryConfig)

  const storeConfigs = deepExtend({}, constructorConfig.store, {
    system: {
      configs: constructorConfig.configs
    },
    state: {
      layout: {
        layout: constructorConfig.layout,
        filter: constructorConfig.filter
      },
      spec: {
        spec: '',
        url: constructorConfig.url
      }
    }
  })

  let inlinePlugin = () => {
    return {
      fn: constructorConfig.fn,
      components: constructorConfig.components,
      state: constructorConfig.state
    }
  }

  const store = new System(storeConfigs)
  store.register([constructorConfig.plugins, inlinePlugin])

  const system = store.getSystem()

  system.initOAuth = system.authActions.configureAuth

  const downloadSpec = (fetchedConfig) => {
    if (typeof constructorConfig !== 'object') {
      return system
    }

    let localConfig = system.specSelectors.getLocalConfig ? system.specSelectors.getLocalConfig() : {}
    let mergedConfig = deepExtend({}, localConfig, constructorConfig, fetchedConfig || {}, queryConfig)

    // deep extend mangles domNode, we need to set it manually
    if (opts.domNode) {
      mergedConfig.domNode = opts.domNode
    }

    store.setConfigs(mergedConfig)

    if (fetchedConfig !== null) {
      if (!queryConfig.url && typeof mergedConfig.spec === 'object' && Object.keys(mergedConfig.spec).length) {
        system.specActions.updateUrl('')
        system.specActions.updateLoadingStatus('success')
        system.specActions.updateSpec(JSON.stringify(mergedConfig.spec))
      } else if (system.specActions.download && mergedConfig.url) {
        system.specActions.updateUrl(mergedConfig.url)
        system.specActions.download(mergedConfig.url)
      }
    }

    if (mergedConfig.domNode) {
      system.render(mergedConfig.domNode, 'App')
    } else if (mergedConfig.dom_id) {
      let domNode = document.querySelector(mergedConfig.dom_id)
      system.render(domNode, 'App')
    } else {
      console.error('Skipped rendering: no `dom_id` or `domNode` was specified')
    }

    return system
  }

  let configUrl = queryConfig.config || constructorConfig.configUrl

  if (!configUrl || !system.specActions.getConfigByUrl || system.specActions.getConfigByUrl && !system.specActions.getConfigByUrl(configUrl, downloadSpec)) {
    return downloadSpec()
  }

  return system
}
