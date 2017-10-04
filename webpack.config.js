const path = require('path');

const BUILD_DIR = path.resolve(__dirname, 'client/public');
const APP_DIR = path.resolve(__dirname, 'client/app');

const config = {
  entry: `${APP_DIR}/index.js`,
  output: {
    path: BUILD_DIR,
    filename: 'client.js',
  },
  module: {
    loaders: [
      {
        test: /\.elm$/,
        include: APP_DIR,
        loader: 'elm-webpack-loader?debug',
      },
    ],
  },
};

module.exports = config;
