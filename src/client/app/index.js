const Elm = require('./Main.elm');

Elm.Main.fullscreen({
  wsserver: (window.location.protocol.includes('https') ? 'wss://' : 'ws://') + window.location.host,
});
