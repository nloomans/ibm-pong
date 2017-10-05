const path = require('path');

const BUILD_DIR = path.resolve(__dirname, 'src/client/public');
const APP_DIR = path.resolve(__dirname, 'src/client/app');

module.exports = {
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
