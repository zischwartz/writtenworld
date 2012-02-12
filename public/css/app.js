(function() {
  var app, connectedUsers, everyone, express, leaflet, nowjs;

  express = require('express');

  nowjs = require('now');

  leaflet = require('./leaflet-custom-src.js');

  app = express.createServer();

  app.configure(function() {
    app.use(express.bodyParser());
    return app.use(app.router);
  });

  app.configure('development', function() {
    app.use(express.static(__dirname + '/public'));
    return app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
  });

  everyone = nowjs.initialize(app);

  connectedUsers = {};

  nowjs.on('connect', function() {
    connectedUsers[this.user.clientId] = {};
    return console.log(this.user.clientID, 'connected');
  });

  nowjs.on('disconnect', function() {
    delete connectedUsers[this.user.clientId];
    return console.log('removing disconnected user');
  });

  everyone.now.setBounds = function(bounds) {
    var b;
    b = new leaflet.L.Bounds(bounds.max, bounds.min);
    return console.log('bounds are', b);
  };

  everyone.now.setSelected = function(cellPoint) {
    var i, _results;
    console.log('setselected');
    connectedUsers[this.user.clientId].selected = cellPoint;
    _results = [];
    for (i in connectedUsers) {
      _results.push(console.log(i, 'iii'));
    }
    return _results;
  };

  app.listen(3000);

}).call(this);
