// Generated by CoffeeScript 1.3.1
(function() {
  var leaflet, models, nowjs,
    __hasProp = {}.hasOwnProperty;

  models = require('./models');

  nowjs = require('now');

  leaflet = require('./lib/leaflet-custom-src.js');

  module.exports = function(app, SessionModel) {
    var CUser, bridge, everyone, getWhoCanSee;
    everyone = nowjs.initialize(app);
    bridge = require('./bridge')(everyone, SessionModel);
    everyone.now.setCurrentWorld = function(currentWorldId) {
      var group;
      if (currentWorldId) {
        group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId);
        return this.now.currentWorldId = currentWorldId;
      } else {
        return this.now.currentWorldId = false;
      }
    };
    nowjs.on('connect', function() {
      var u;
      this.user.cid = this.user.clientId;
      u = new CUser(this.user);
    });
    nowjs.on('disconnect', function() {
      var cid, u, update;
      cid = this.user.clientId;
      u = CUser.byCid(cid);
      update = {
        cid: cid
      };
      getWhoCanSee(u.cursor, this.now.currentWorldId, function(toUpdate) {
        var i, _results;
        _results = [];
        for (i in toUpdate) {
          _results.push(nowjs.getClient(i, function() {
            return this.now.updateCursors(update);
          }));
        }
        return _results;
      });
      u.destroy();
    });
    everyone.now.setBounds = function(bounds) {
      var b;
      b = new leaflet.L.Bounds(bounds.max, bounds.min);
      return CUser.byCid(this.user.cid).bounds = b;
    };
    everyone.now.setClientStateFromServer = function(callback) {
      if (this.user.session) {
        return callback(this.user.session);
      }
    };
    everyone.now.setCursor = function(cellPoint) {
      var cid, update;
      if (!this.now.currentWorldId) {
        return false;
      }
      cid = this.user.clientId;
      CUser.byCid(cid).cursor = cellPoint;
      update = {
        cid: cid,
        x: cellPoint.x,
        y: cellPoint.y,
        color: this.user.session ? this.user.session.color : void 0
      };
      return getWhoCanSee(cellPoint, this.now.currentWorldId, function(toUpdate) {
        var i, _results;
        _results = [];
        for (i in toUpdate) {
          if (i !== cid) {
            _results.push(nowjs.getClient(i, function() {
              return this.now.updateCursors(update);
            }));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
    };
    everyone.now.writeCell = function(cellPoint, content) {
      var cid, currentWorldId;
      if (!this.now.currentWorldId) {
        return false;
      }
      currentWorldId = this.now.currentWorldId;
      cid = this.user.clientId;
      bridge.processRite(cellPoint, content, this.user, currentWorldId, function(commandType, rite, cellPoint, cellProps) {
        if (rite == null) {
          rite = false;
        }
        if (cellPoint == null) {
          cellPoint = false;
        }
        if (cellProps == null) {
          cellProps = false;
        }
        return getWhoCanSee(cellPoint, currentWorldId, function(toUpdate) {
          var i, _results;
          _results = [];
          for (i in toUpdate) {
            if (rite) {
              _results.push(nowjs.getClient(i, function() {
                return this.now.drawRite(commandType, rite, cellPoint, cellProps);
              }));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        });
      });
      return true;
    };
    everyone.now.getTile = function(absTilePoint, numRows, callback) {
      var _this = this;
      if (!this.now.currentWorldId) {
        return false;
      }
      return models.Cell.where('world', this.now.currentWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).populate('current').run(function(err, docs) {
        var c, pCell, results, _i, _len;
        results = {};
        if (docs.length) {
          for (_i = 0, _len = docs.length; _i < _len; _i++) {
            c = docs[_i];
            if (c.current) {
              pCell = {
                x: c.y,
                y: c.y,
                contents: c.current.contents,
                props: c.current.props
              };
              results["" + c.x + "x" + c.y] = pCell;
            }
          }
          return callback(results, absTilePoint);
        } else {
          return callback(results, absTilePoint);
        }
      });
    };
    getWhoCanSee = function(cellPoint, worldId, cb) {
      return nowjs.getGroup(worldId).getUsers(function(users) {
        var i, toUpdate, _i, _len, _ref, _ref1;
        toUpdate = {};
        if (worldId) {
          for (_i = 0, _len = users.length; _i < _len; _i++) {
            i = users[_i];
            if ((_ref = CUser.byCid(i)) != null ? (_ref1 = _ref.bounds) != null ? _ref1.contains(cellPoint) : void 0 : void 0) {
              toUpdate[i] = CUser.byCid(i);
            }
          }
        }
        return cb(toUpdate);
      });
    };
    everyone.now.getCloseUsers = function(cb) {
      var aC, cid, closeUsers;
      if (!this.now.currentWorldId) {
        return false;
      }
      console.log('getCloseUsers called');
      closeUsers = [];
      cid = this.user.clientId;
      aC = CUser.byCid(cid).cursor;
      nowjs.getGroup(this.now.currentWorldId).getUsers(function(users) {
        var distance, i, key, u, uC, value, _i, _len, _ref;
        for (_i = 0, _len = users.length; _i < _len; _i++) {
          i = users[_i];
          uC = CUser.byCid(i).cursor;
          distance = Math.sqrt((aC.x - uC.x) * (aC.x - uC.x) + (aC.y - uC.y) * (aC.y - uC.y));
          if (distance < 1000 && (i !== cid)) {
            u = {};
            _ref = CUser.byCid(i);
            for (key in _ref) {
              if (!__hasProp.call(_ref, key)) continue;
              value = _ref[key];
              u[key] = value;
            }
            u.distance = distance;
            closeUsers.push(u);
          }
        }
        return cb(closeUsers);
      });
      return true;
    };
    everyone.now.submitFeedback = function(f, t) {
      var feedback;
      this.now.insertMessage('Thanks', 'We appreciate your feedback');
      feedback = new models.Feedback({
        contents: f,
        t: t
      });
      return feedback.save(function(err) {
        if (err) {
          return console.log(err);
        }
      });
    };
    everyone.now.setUserOption = function(type, payload) {
      var cid, userId,
        _this = this;
      console.log('setUserOption', type, payload);
      if (type = 'color') {
        cid = this.user.clientId;
        CUser.byCid(cid).color = payload;
        this.user.session.color = payload;
        this.user.session.save();
        if (this.user.session.auth) {
          userId = this.user.session.auth.userId;
          return models.User.findById(userId, function(err, doc) {
            if (err) {
              console.log(err);
            }
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
      console.log('rcvd echo called');
      userId = this._id;
      rite.getOwner(function(err, u) {
        var cid, _ref;
        if (err) {
          console.log(err);
        }
        cid = (_ref = CUser.byUid(userId)) != null ? _ref.cid : void 0;
        if (cid) {
          return nowjs.getClient(cid(function() {
            if (u) {
              return this.now.insertMessage('Echoed!', "" + u.login + " echoed what you said!");
            } else {
              return this.now.insertMessage('Echoed!', "Someone echoed what you said!");
            }
          }));
        }
      });
      return true;
    });
    models.User.prototype.on('receivedOverRite', function(rite) {
      var userId;
      console.log('rcd ovrt called');
      userId = this._id;
      rite.getOwner(function(err, u) {
        var cid, _ref;
        if (err) {
          console.log(err);
        }
        cid = (_ref = CUser.byUid(userId)) != null ? _ref.cid : void 0;
        if (cid) {
          return nowjs.getClient(cid(function() {
            if (u) {
              return this.now.insertMessage('Over Written', "Someone called " + u.login + " is writing over your cells. Click for more info");
            } else {
              return this.now.insertMessage('Over Written', "Someone is writing over your cells. Click for more info");
            }
          }));
        }
      });
      return true;
    });
    CUser = (function() {
      var allByCid, allBySid, allByUid;

      CUser.name = 'CUser';

      allByCid = {};

      allBySid = {};

      allByUid = {};

      CUser.byCid = function(cid) {
        var r;
        r = allByCid[cid];
        return r;
      };

      CUser.byCidFull = function(cid) {
        return allByCid[cid];
      };

      CUser.bySid = function(sid) {
        return allBy[sid];
      };

      CUser.byUid = function(uid) {
        return allByUid[uid];
      };

      function CUser(nowUser) {
        var _ref,
          _this = this;
        this.nowUser = nowUser;
        this.cid = this.nowUser.clientId;
        this.sid = decodeURIComponent(this.nowUser.cookie['connect.sid']);
        if ((_ref = nowUser.session) != null ? _ref.auth : void 0) {
          this.uid = nowUser.session.auth.userId;
          models.User.findById(this.uid, function(err, doc) {
            _this.login = doc.login;
            return _this.nowUser.login = doc.login;
          });
        } else {
          SessionModel.findOne({
            'sid': this.sid
          }, function(err, doc) {
            _this.uid = doc._id;
            return _this.nowUser.soid = doc._id;
          });
        }
        allByCid[this.cid] = this;
        allBySid[this.sid] = this;
        allByUid[this.uid] = this;
      }

      CUser.prototype.destroy = function() {
        delete allByCid[this.cid];
        delete allBySid[this.sid];
        delete allByUid[this.uid];
        return delete this.nowUser;
      };

      return CUser;

    })();
    exports.CUser = CUser;
    return true;
  };

}).call(this);
