(function() {
  var app, cUsers, config, connect, everyone, express, getWhoCanSee, leaflet, models, mongoose, nowjs, sessionStore;

  express = require('express');

  nowjs = require('now');

  leaflet = require('./leaflet-custom-src.js');

  mongoose = require('mongoose');

  connect = require('connect');

  mongoose.connect('mongodb://localhost/mapist');

  models = require('./models.js');

  sessionStore = require("connect-mongoose")(connect);

  app = express.createServer();

  app.configure(function() {
    app.use(express.bodyParser());
    app.use(express.cookieParser());
    app.use(express.session({
      secret: 'tshh secret',
      store: new sessionStore()
    }));
    app.use(express.favicon(__dirname + '/public/favicon.ico'));
    app.use(express.compiler({
      src: __dirname + '/public',
      enable: ['less', 'coffeescript']
    }));
    return app.use(app.router);
  });

  app.configure('development', function() {
    app.use(express.static(__dirname + '/public'));
    app.use(express.logger({
      format: ':method :url'
    }));
    return app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
  });

  everyone = nowjs.initialize(app);

  config = {
    maxZoom: 18
  };

  cUsers = {};

  nowjs.on('connect', function() {
    var sid;
    sid = this.user.cookie['connect.sid'];
    cUsers[this.user.clientId] = {
      sid: sid
    };
    return console.log(this.user.clientId, 'connected');
  });

  nowjs.on('disconnect', function() {
    delete cUsers[this.user.clientId];
    return console.log('removing disconnected user');
  });

  everyone.now.setBounds = function(bounds) {
    var b;
    b = new leaflet.L.Bounds(bounds.max, bounds.min);
    return cUsers[this.user.clientId].bounds = b;
  };

  everyone.now.setSelectedCell = function(cellPoint) {
    var cid, i, toUpdate, updates, _results;
    cid = this.user.clientId;
    cUsers[cid].selected = cellPoint;
    toUpdate = getWhoCanSee(cellPoint);
    _results = [];
    for (i in toUpdate) {
      if (i !== cid) {
        updates = {
          cid: cUsers[cid]
        };
        _results.push(nowjs.getClient(i, function() {
          return this.now.drawCursors(updates);
        }));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  everyone.now.writeCell = function(cellPoint, content) {
    var cid, edits, i, toUpdate;
    console.log(this.user);
    cid = this.user.clientId;
    toUpdate = getWhoCanSee(cellPoint);
    console.log(cellPoint, content);
    edits = {};
    models.writeCellToDb(cellPoint, content, worldId);
    for (i in toUpdate) {
      if (i !== cid) {
        edits[cid] = {
          cellPoint: cellPoint,
          content: content
        };
        nowjs.getClient(i, function() {
          return this.now.drawEdits(edits);
        });
      }
    }
    return true;
  };

  everyone.now.getTile = function(absTilePoint, numRows, callback) {
    var _this = this;
    return models.CellModel.where('world', models.mainWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).run(function(err, docs) {
      var c, results, _i, _len;
      results = {};
      if (docs.length) {
        for (_i = 0, _len = docs.length; _i < _len; _i++) {
          c = docs[_i];
          results["" + c.x + "x" + c.y] = c;
        }
        return callback(results, absTilePoint);
      } else {
        return callback(results, absTilePoint);
      }
    });
  };

  getWhoCanSee = function(cellPoint) {
    var i, toUpdate;
    toUpdate = {};
    for (i in cUsers) {
      if (cUsers[i].bounds.contains(cellPoint)) toUpdate[i] = cUsers[i];
    }
    return toUpdate;
  };

  app.listen(3000);

}).call(this);
