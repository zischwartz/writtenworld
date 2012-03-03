(function() {
  var leaflet, models, nowjs;

  models = require('./models.js');

  nowjs = require('now');

  leaflet = require('./leaflet-custom-src.js');

  module.exports = function(app, SessionModel) {
    var aUsers, cUsers, everyone, getWhoCanSee;
    console.log('now now with the app!');
    everyone = nowjs.initialize(app);
    everyone.now.setCurrentWorld = function(currentWorldId) {
      var group;
      group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId);
      return this.now.currentWorldId = currentWorldId;
    };
    cUsers = {};
    aUsers = {};
    nowjs.on('connect', function() {
      var sid, _ref;
      sid = decodeURIComponent(this.user.cookie['connect.sid']);
      if ((_ref = this.user.session) != null ? _ref.auth : void 0) {
        cUsers[this.user.clientId] = {
          sid: sid,
          userId: this.user.session.auth.userId
        };
        aUsers[this.user.session.auth.userId] = {
          sid: sid,
          cid: this.user.clientId
        };
      } else {
        cUsers[this.user.clientId] = {
          sid: sid
        };
      }
      console.log(this.user.clientId, 'connected clientId: ');
      return true;
    });
    nowjs.on('disconnect', function() {
      var _ref;
      delete cUsers[this.user.clientId];
      if ((_ref = this.user.session) != null ? _ref.auth : void 0) {
        delete aUsers[this.user.session.auth.userId];
        console.log('removing authd disconnected user');
      }
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
      var cid;
      cid = this.user.clientId;
      cUsers[cid].selected = cellPoint;
      return getWhoCanSee(cellPoint, this.now.currentWorldId, function(toUpdate) {
        var i, updates, _results;
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
      });
    };
    everyone.now.writeCell = function(cellPoint, content) {
      var cid, currentWorldId, edits, isOwnerAuth, ownerId, props, sid;
      cid = this.user.clientId;
      currentWorldId = this.now.currentWorldId;
      sid = decodeURIComponent(this.user.cookie['connect.sid']);
      props = {};
      isOwnerAuth = false;
      if (this.user.session.auth) {
        isOwnerAuth = true;
        ownerId = this.user.session.auth.userId;
        props.color = this.user.session.color;
        models.writeCellToDb(cellPoint, content, currentWorldId, ownerId, isOwnerAuth, props);
        models.User.findById(ownerId, function(err, user) {
          console.log(typeof user.personalWorld.toString(), currentWorldId);
          if (user.personalWorld.toString() !== currentWorldId) {
            return models.writeCellToDb(cellPoint, content, user.personalWorld, ownerId, isOwnerAuth, props);
          }
        });
      } else {
        SessionModel.findOne({
          'sid': sid
        }, function(err, doc) {
          var data;
          data = JSON.parse(doc.data);
          ownerId = doc._id;
          props.color = data.color;
          return models.writeCellToDb(cellPoint, content, currentWorldId, ownerId, isOwnerAuth, props);
        });
      }
      if (this.user.session.color != null) props.color = this.user.session.color;
      edits = {};
      getWhoCanSee(cellPoint, this.now.currentWorldId, function(toUpdate) {
        var i, _results;
        _results = [];
        for (i in toUpdate) {
          if (i !== cid) {
            edits[cid] = {
              cellPoint: cellPoint,
              content: content,
              props: props
            };
            _results.push(nowjs.getClient(i, function() {
              return this.now.drawEdits(edits);
            }));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
      return true;
    };
    everyone.now.getTile = function(absTilePoint, numRows, callback) {
      var _this = this;
      return models.Cell.where('world', this.now.currentWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).populate('current').run(function(err, docs) {
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
    getWhoCanSee = function(cellPoint, worldId, cb) {
      return nowjs.getGroup(worldId).getUsers(function(users) {
        var i, toUpdate, _i, _len;
        toUpdate = {};
        for (_i = 0, _len = users.length; _i < _len; _i++) {
          i = users[_i];
          if (cUsers[i].bounds.contains(cellPoint)) toUpdate[i] = cUsers[i];
        }
        return cb(toUpdate);
      });
    };
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
    models.User.prototype.on('receivedEcho', function(rite) {
      var userId;
      if (aUsers[this._id]) {
        userId = this._id;
        rite.getOwner(function(err, u) {
          if (err) console.log(err);
          return nowjs.getClient(aUsers[userId].cid, function() {
            if (u) {
              return this.now.insertMessage('Echoed!', "" + u.login + " echoed what you said!");
            } else {
              return this.now.insertMessage('Echoed!', "Someone echoed what you said!");
            }
          });
        });
      }
      return true;
    });
    models.User.prototype.on('receivedOverRite', function(rite) {
      var userId;
      if (aUsers[this._id]) {
        userId = this._id;
        rite.getOwner(function(err, u) {
          if (err) console.log(err);
          return nowjs.getClient(aUsers[userId].cid, function() {
            if (u) {
              return this.now.insertMessage('Over Written', "Someone called " + u.login + " is writing over your cells. Click for more info");
            } else {
              return this.now.insertMessage('Over Written', "Someone is writing over your cells. Click for more info");
            }
          });
        });
      }
      return true;
    });
    return 5;
  };

}).call(this);
