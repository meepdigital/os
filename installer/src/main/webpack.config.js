const path = require('node:path');
const CopyPlugin = require('copy-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  target: 'electron-main',
  entry: {
    main: './src/main/main.js',
    renderer: './src/main/renderer.js',
  },
  output: {
    path: path.resolve(__dirname, '../../dist'),
    filename: '[name].js',
    clean: true,
  },
  module: {
    rules: [
      {
        test: /\.s[ac]ss$/i,
        use: [MiniCssExtractPlugin.loader, 'css-loader', 'sass-loader'],
      },
      {
        test: /\.(woff2?|ttf|eot|svg)$/i,
        type: 'asset/resource',
      },
    ],
  },
  plugins: [
    new MiniCssExtractPlugin({ filename: 'installer.css' }),
    new CopyPlugin({
      patterns: [
        { from: './templates/index.html', to: 'index.html' },
        { from: './src/main/preload.js', to: 'preload.js' },
        { from: './sh/run', to: 'run.sh' },
        { from: './assets/installer.png', to: 'installer.png' },
        { from: './pages', to: 'pages' },
      ],
    }),
  ],
  resolve: {
    extensions: ['.js'],
  },
  node: {
    __dirname: false,
    __filename: false,
  },
};
