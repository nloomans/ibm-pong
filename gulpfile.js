const gulp = require('gulp');
const spawn = require('child_process').spawn;

let node;

const paths = {
  javascript: {
    server: ['./src/server', './src/server/bin/www'],
  },
};

function killNode() {
  return new Promise((resolve) => {
    if (node) {
      node.on('close', resolve);
      node.kill('SIGINT');
    } else {
      resolve();
    }
  });
}

gulp.task('server', () => killNode().then(() => {
  const env = Object.create(process.env);
  env.DEV_WEBPACK = 1;
  node = spawn('node', ['./src/server/bin/www'], { stdio: 'inherit', env });
  node.on('close', (code) => {
    if (code !== 0) {
      process.exit(code);
    }
  });
}));

gulp.task('server:watch', () => gulp.watch(paths.javascript.server, ['server']));

gulp.task('default', ['server', 'server:watch']);
