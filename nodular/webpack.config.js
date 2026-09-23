import webpack from 'webpack';
import { env } from './src/js/core/env.js';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

export default {

  mode: 'development',
  plugins: [new webpack.DefinePlugin({ __NODULAR_BUILD_ENV__: JSON.stringify(env) })],
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
    if (request === 'dotenv' || !/^[^./]/.test(request)) callback();
    else callback(null, `module ${request}`);
  }],

  module: { parser: { javascript: { createRequire: false, importMeta: false } } },
  devtool: 'source-map',
  optimization: { minimize: true },
};
