const path = require('path');

const BUILD_DIR = path.resolve(__dirname, 'client/public');
const APP_DIR = path.resolve(__dirname, 'client/app');

const config = {
  entry: `${APP_DIR}/app.js`,
  output: {
    path: BUILD_DIR,
    filename: 'client.js',
  },
  module: {
    loaders: [
      {
        test: /\.js?/,
        include: APP_DIR,
        loader: ['babel-loader'],
      },
    ],
  },
};

module.exports = config;
