const Elm = require('./Main.elm');

const app = Elm.Main.fullscreen({
  wsserver: (window.location.protocol.includes('https') ? 'wss://' : 'ws://') + window.location.host,
});

window.document.addEventListener('keydown', function (event) {
  app.ports.onKeyDown.send(event.key);
});

let prevTick = new Date().valueOf();

function tick() {
  app.ports.tick.send(new Date().valueOf() - prevTick);
  prevTick = new Date().valueOf();
  window.requestAnimationFrame(tick);
}

tick();
