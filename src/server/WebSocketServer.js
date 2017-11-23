const WebSocketServer = require('websocket').server;
const EventEmitter = require('events');

/**
 * Decodes the output of `encode` back to the orignal array.
 * @param {string} string output of `encode`
 * @returns {array<int>} e.g. [101, 542]
 */
function decode(string) {
  return string.split('').map(char => char.charCodeAt(0));
}


/**
 * Takes an array of numbers and encodes them so that they can be send with
 * minimal bandwidth usuage.
 * @param {array<int>} e.g. [101, 542]
 * @returns {string} Encoded string
 */
function encode(array) {
  return array.map(int => String.fromCharCode(int)).join('');
}

class Game extends EventEmitter {
  start() {
    this.emit('ballUpdate', 50, 50, (0.2 * Math.PI));
  }
}

class ClientRepresentor extends EventEmitter {
  /**
   * This class represents the client.
   *
   * It emits the folowing events:
   *  - close: called when the client closed the connection.
   *
   * @param {WebSocketConnection} connection The web socket connection used to
   *     comunicate to the client.
   */
  constructor(connection) {
    super();

    this.connection = connection;

    // (╯°□°）╯︵ ┻━┻
    this.onMessage = this.onMessage.bind(this);
    this.onClose = this.onClose.bind(this);
    this.onBallUpdate = this.onBallUpdate.bind(this);

    this.connection.on('message', this.onMessage);
    this.connection.on('close', this.onClose);

    // Ensure that the client is in pending mode.
    this.sendMessage([102]);
  }

  /**
   * Save reference to game class and tell client that the game has been
   * started.
   * @param {game} game The game object.
   * @param {1 or 2} player Signifies whenever this client is player one or
   *     player two.
   */
  attachToGame(game, player) {
    this.player = player;
    this.game = game;

    this.game.on('ballUpdate', this.onBallUpdate);

    this.sendMessage([101]);
  }

  onBallUpdate(x, y, dir) {
    if (this.player === 1) {
      this.sendMessage([202, Math.round(x), Math.round(y), Math.round(dir * 100)]);
    } else {
      const flippedX = 800 - x;
      const flippedDir = Math.PI - dir;
      this.sendMessage([202, Math.round(flippedX), Math.round(y), Math.round(flippedDir * 100)]);
    }
  }

  /**
   * Stop the game and tell the connected client that the game has been stopped.
   */
  otherClientDisconnected() {
    this.game = null;
    this.player = null;
    this.sendMessage([102]);
  }

  /**
   * This function gets called when the client sends a message.
   * @param {string} utf8EncodedMessage String encoded by the `encode` function.
   */
  // eslint-disable-next-line class-methods-use-this
  onMessage(utf8EncodedMessage) {
    const message = decode(utf8EncodedMessage.utf8Data);
    console.log(`New message ${message}`);
  }

  /**
   * This function gets called when the client disconnects.
   */
  onClose() {
    console.log(`Peer ${this.connection.remoteAddress} disconnected.`);
    this.emit('close');
  }

  /**
   * Sends a message to the client.
   * @param {array<int>} message The message to send to the client.
   */
  sendMessage(message) {
    this.connection.sendUTF(encode(message));
  }
}

class Server {
  constructor(server) {
    this.server = new WebSocketServer({
      httpServer: server,
      autoAcceptConnections: false,
    });

    this.state = {
      games: [],
      pendingClients: [],
      clients: [],
    };

    // (╯°□°）╯︵ ┻━┻
    this.onNewConnection = this.onNewConnection.bind(this);
    this.onConnectionClose = this.onConnectionClose.bind(this);

    this.server.on('request', this.onNewConnection);
  }

  /**
   * This function gets called when a new client connects.
   */
  onNewConnection(request) {
    const connection = request.accept(null, request.origin);
    console.log('Connection accepted.');

    const clientRepresentor = new ClientRepresentor(connection);
    this.state.clients.push(clientRepresentor);
    this.addPendingClientRepresentor(clientRepresentor);

    clientRepresentor.on('close', () => {
      // Client closed connection, time for cleanup.
      this.onConnectionClose(clientRepresentor);
    });
  }

  /**
   * This function gets called when a client disconnects.
   * @param {ClientRepresentor} clientRepresentor The representor that
   *     represents the client that disconnected.
   */
  onConnectionClose(clientRepresentor) {
    // Remove the client from the pending clients list.
    for (let i = 0; i < this.state.pendingClients.length; i += 1) {
      if (clientRepresentor === this.state.pendingClients[i]) {
        this.state.pendingClients.splice(i, 1);
        i -= 1;
      }
    }

    for (let i = 0; i < this.state.clients.length; i += 1) {
      if (clientRepresentor === this.state.clients[i]) {
        // Remove the client from the clients list.
        this.state.clients.splice(i, 1);
        i -= 1;
      } else if (clientRepresentor.game === this.state.clients[i].game) {
        // Tell the other client that shares this clients game (if any) that
        // the client has disconnected and that the game has therefor been
        // stopped.
        this.state.clients[i].otherClientDisconnected();

        // Add the other client to the list of pending clients.
        this.addPendingClientRepresentor(this.state.clients[i]);
      }
    }

    // Remove the now empty game.
    for (let i = 0; i < this.state.games.length; i += 1) {
      if (clientRepresentor.game === this.state.games[i]) {
        this.state.games.splice(i, 1);
        i -= 1;
      }
    }
  }

  /**
   * add a client to the list of pending clients. This will also check if there
   * are two clients and if so, added them to a new game.
   * NEVER CALL `this.state.pendingClients.push` DIRECTLY!
   * @param {ClientRepresentor} clientRepresentor The client representor of the
   *     client that should be added to the pending clients list.
   */
  addPendingClientRepresentor(clientRepresentor) {
    this.state.pendingClients.push(clientRepresentor);
    if (this.state.pendingClients.length === 2) {
      const game = new Game();
      this.state.games.push(game);

      this.state.pendingClients[0].attachToGame(game, 1);
      this.state.pendingClients[1].attachToGame(game, 2);
      this.state.pendingClients = [];

      game.start();
    }
  }
}

module.exports = Server;
