import webpack from 'webpack';
import MiniCssExtractPlugin from 'mini-css-extract-plugin'
import { env } from './src/js/core/env.js';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

export default {

  mode: 'development',
  plugins: [
    new webpack.DefinePlugin({ __NODULAR_BUILD_ENV__: JSON.stringify(env) }),
    new MiniCssExtractPlugin({ filename: '../assets/style.css' }),
  ],
  target: 'node22',

  entry: {
    app: './src/js/app.js',
    main: './src/js/main.js',
    preload: './src/js/core/preload.js',
    session: './src/js/core/session.js',
    wm: './src/js/core/wm.js',
  },

  context: root,
  output: {
    path: join(root, 'build/js'),
    filename: '[name].mjs',
    module: true,
    // node-gyp owns build/Release; webpack must never clean that directory.
    clean: true,
  },

  experiments: { outputModule: true },
  externalsType: 'module',
  externals: [({ request }, callback) => {
    if (request === 'dotenv' || request.startsWith('!') || /^[./]/.test(request)) callback();
    else callback(null, `module ${request}`);
  }],

  module: {
    parser: { javascript: { createRequire: false, importMeta: false } },
    rules: [
      {
        test: /\.s[ac]ss$/i,
        use: [
          MiniCssExtractPlugin.loader,
          { loader: 'css-loader', options: { importLoaders: 1, url: false } },
          {
            loader: 'sass-loader',
            options: {
              sassOptions: {
                silenceDeprecations: ['import', 'global-builtin', 'color-functions', 'if-function'],
              },
            },
          },
        ],
      },
      {
        test: /\.less$/i,
        use: [
          MiniCssExtractPlugin.loader,
          { loader: 'css-loader', options: { importLoaders: 1, url: false } },
          'less-loader',
        ],
      },
    ],
  },
  devtool: 'source-map',
  optimization: { minimize: true },
};
