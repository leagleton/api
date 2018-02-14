const path = require('path')
const Webpack = require('webpack')
const os = require('os')
const pkg = require('./package.json')

module.exports = [
  {
    entry: {
      'swagger-ui.min': [
        './frontend/swagger/polyfills',
        './frontend/swagger/core/index.js'
      ]
    },
    target: 'web',
    // yaml-js has a reference to `fs`, this is a workaround
    node: {
      fs: 'empty'
    },
    module: {
      rules: [
        {
          test: /\.(js(x)?)(\?.*)?$/,
          use: [{
            loader: 'babel-loader',
            options: {
              retainLines: true
            }
          }],
          include: [path.join(__dirname, './frontend/swagger')]
        }
      ]
    },
    resolveLoader: {
      modules: [path.join(__dirname, 'node_modules')]
    },
    externals: {
      'buffertools': true // json-react-schema/deeper depends on buffertools, which fails.
    },
    output: {
      path: path.join(__dirname, './views/static'),
      library: 'SwaggerUI',
      libraryTarget: 'umd',
      filename: 'js/[name].js',
      chunkFilename: 'js/[name].js'
    },
    resolve: {
      modules: [
        path.join(__dirname, './frontend/swagger'),
        'node_modules'
      ],
      extensions: ['.web.js', '.js', '.jsx', '.json']
    },
    plugins: [
      new Webpack.DefinePlugin({
        'process.env': {
          NODE_ENV: JSON.stringify('production'),
          WEBPACK_INLINE_STYLES: false
        },
        'buildInfo': JSON.stringify({
          PACKAGE_VERSION: (pkg.version),
          HOSTNAME: os.hostname(),
          BUILD_TIME: new Date().toUTCString()
        })
      }),
      new Webpack.optimize.UglifyJsPlugin({
        sourceMap: false
      }),
      new Webpack.LoaderOptionsPlugin({
        options: {
          context: __dirname
        }
      }),
      new Webpack.NoEmitOnErrorsPlugin()
    ]
  }
]
