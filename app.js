(function() {
  var SessionModel, app, cUsers, config, connect, events, everyone, express, fs, getWhoCanSee, jade, leaflet, mainWorldId, models, mongoose, nowjs, sessionStore, util, _ref;

  express = require('express');

  nowjs = require('now');

  mongoose = require('mongoose');

  connect = require('connect');

  mongoose.connect('mongodb://localhost/mapist');

  jade = require('jade');

  fs = require('fs');

  events = require('events');

  util = require('util');

  leaflet = require('./leaflet-custom-src.js');

  models = require('./models.js');

  _ref = require("./mongoose-session.js")(connect), sessionStore = _ref[0], SessionModel = _ref[1];

  app = express.createServer();

  app.configure(function() {
    app.use(express.bodyParser());
    app.use(express.cookieParser());
    app.use(express.session({
      secret: 'tshh secret',
      store: new sessionStore()
    }));
    app.use(express.favicon(__dirname + '/public/favicon.ico'));
    return app.use(models.mongooseAuth.middleware());
  });

  app.configure('development', function() {
    app.use(express.static(__dirname + '/public'));
    app.set('view engine', 'jade');
    app.use(express.logger({
      format: ':method :url'
    }));
    app.set('view options', {
      layout: false
    });
    return app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
  });

  mainWorldId = mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001");

  everyone = nowjs.initialize(app);

  config = {
    maxZoom: 18
  };

  cUsers = {};

  nowjs.on('connect', function() {
    var sid;
    sid = decodeURIComponent(this.user.cookie['connect.sid']);
    cUsers[this.user.clientId] = {
      sid: sid
    };
    console.log(this.user.clientId, 'connected clientId: ');
    console.log('connected sid: ', sid);
    return true;
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

  everyone.now.setClientState = function(callback) {
    if (this.user.session) return callback(this.user.session);
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
    var cid, edits, i, isOwnerAuth, ownerId, props, sid, toUpdate;
    cid = this.user.clientId;
    sid = decodeURIComponent(this.user.cookie['connect.sid']);
    props = {};
    isOwnerAuth = false;
    if (this.user.session.auth) {
      isOwnerAuth = true;
      ownerId = this.user.session.auth.userId;
      props.color = this.user.session.color;
      models.writeCellToDb(cellPoint, content, mainWorldId, ownerId, isOwnerAuth, props);
    } else {
      SessionModel.findOne({
        'sid': sid
      }, function(err, doc) {
        var data;
        data = JSON.parse(doc.data);
        ownerId = doc._id;
        props.color = data.color;
        return models.writeCellToDb(cellPoint, content, mainWorldId, ownerId, isOwnerAuth, props);
      });
    }
    if (this.user.session.color != null) props.color = this.user.session.color;
    toUpdate = getWhoCanSee(cellPoint);
    edits = {};
    for (i in toUpdate) {
      if (i !== cid) {
        edits[cid] = {
          cellPoint: cellPoint,
          content: content,
          props: props
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
    return models.Cell.where('world', mainWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).populate('current').run(function(err, docs) {
      var c, pCell, results, _i, _len;
      results = {};
      if (docs.length) {
        for (_i = 0, _len = docs.length; _i < _len; _i++) {
          c = docs[_i];
          pCell = {
            x: c.y,
            y: c.y,
            contents: c.current.contents,
            props: c.current.props
          };
          results["" + c.x + "x" + c.y] = pCell;
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

  app.get('/home', function(req, res) {
    return res.render('home.jade', {
      title: 'My Site'
    });
  });

  app.get('/', function(req, res) {
    return res.render('map_base.jade', {
      title: 'Mapist'
    });
  });

  everyone.now.setUserOption = function(type, payload) {
    var userId,
      _this = this;
    console.log('setUserOption', type, payload);
    if (type = 'color') {
      this.user.session.color = payload;
      this.user.session.save();
      if (this.user.session.auth) {
        userId = this.user.session.auth.userId;
        return models.User.findById(userId, function(err, doc) {
          if (err) console.log(err);
          doc.color = payload;
          doc.save();
          console.log('USER COLORCHANGE', doc);
          return _this.now.insertMessage('hi', 'nice color');
        });
      }
    }
  };

  models.mongooseAuth.helpExpress(app);

  app.listen(3000);

}).call(this);
