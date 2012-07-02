// Generated by CoffeeScript 1.3.1
(function() {
  var delay, leaflet, models, noteBodies, noteHeads, nowjs, powers,
    __hasProp = {}.hasOwnProperty,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  models = require('./models');

  nowjs = require('now');

  powers = require('./powers');

  leaflet = require('./lib/leaflet-custom-src.js');

  module.exports = function(app, SessionModel, redis_client) {
    var CUser, bridge, everyone, getWhoCanSee;
    everyone = nowjs.initialize(app);
    bridge = require('./bridge')(everyone, SessionModel);
    everyone.now.setGroup = function(currentWorldId) {
      var group;
      if (currentWorldId) {
        group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId);
      } else {
        return false;
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
      if (!bounds) {
        return false;
      }
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
      var cid, currentWorldId, k, v,
        _this = this;
      if (!this.now.currentWorldId) {
        return false;
      }
      currentWorldId = this.now.currentWorldId;
      cid = this.user.clientId;
      bridge.processRite(cellPoint, absTilePoint, content, this.user, this.now.isLocal, currentWorldId, function(commandType, rite, cellPoint, cellProps) {
        if (rite == null) {
          rite = false;
        }
        if (cellPoint == null) {
          cellPoint = false;
        }
        if (cellProps == null) {
          cellProps = false;
        }
      });
      if (typeof content !== 'string') {
        for (k in content) {
          v = content[k];
          if (k === 'linkurl') {
            process.nextTick(function() {
              return models.User.findById(CUser.byCid(_this.user.cid).uid, function(err, doc) {
                doc.powers.lastLinkOn = new Date;
                doc.save();
                _this.user.powers.lastLinkOn = new Date;
              });
            });
          }
          if (!powers.canLink(this.user)) {
            this.now.insertMessage("Sorry, 1 Link/Hour", "For now. Sorry.", 'alert-error');
            return false;
          }
        }
      }
      bridge.processRite(cellPoint, content, this.user, this.now, currentWorldId, function(commandType, rite, cellPoint, cellProps, originalOwner) {
        if (rite == null) {
          rite = false;
        }
        if (cellPoint == null) {
          cellPoint = false;
        }
        if (cellProps == null) {
          cellProps = false;
        }
        if (originalOwner == null) {
          originalOwner = false;
        }
        return getWhoCanSee(cellPoint, currentWorldId, function(toUpdate) {
          var i, _results;
          _results = [];
          for (i in toUpdate) {
            if (rite) {
              CUser.byCid(cid).addToRiteQueue({
                x: cellPoint.x,
                y: cellPoint.y,
                world: currentWorldId,
                rite: rite,
                commandType: commandType,
                originalOwner: originalOwner
              });
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
    everyone.now.getZoomedOutTile = function(absTilePoint, numRows, numCols, callback) {
      var _this = this;
      if (!this.now.currentWorldId) {
        return false;
      }
      return models.Cell.where('world', this.now.currentWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numCols).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).count(function(err, count) {
        var density, results;
        if (count) {
          density = count / (numRows * numCols);
          results = {
            density: density
          };
        } else {
          results = {
            density: 0
          };
        }
        return callback(results, absTilePoint);
      });
    };
    everyone.now.getTile = function(absTilePoint, numRows, callback) {
      var key, worldId;
      if (!this.user.currentWorldId) {
        return false;
      }
      worldId = this.user.currentWorldId.toString();
      key = "t:" + worldId + ":" + numRows + ":" + absTilePoint.x + ":" + absTilePoint.y;
      return redis_client.exists(key, function(err, exists) {
        var _this = this;
        if (exists) {
          return redis_client.hgetall(key, function(err, obj) {
            var i;
            console.log('hit ', key);
            for (i in obj) {
              obj[i] = JSON.parse(obj[i]);
            }
            return callback(obj, absTilePoint);
          });
        } else {
          return models.Cell.where('world', worldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x + numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y + numRows).populate('current').run(function(err, docs) {
            var c, pCell, results, _i, _len;
            console.log('miss');
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
                  redis_client.hmset(key, "" + c.x + "x" + c.y, JSON.stringify(pCell));
                }
              }
              return callback(results, absTilePoint);
            } else {
              redis_client.set(key, results);
              return callback(results, absTilePoint);
            }
          });
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
    everyone.now.setServerState = function(type, payload) {
      var cid, userId,
        _this = this;
      console.log('setUserOption', type, payload);
      if (type === 'color') {
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
            return _this.now.insertMessage('hi', 'nice color');
          });
        }
      }
    };
    everyone.now.createGeoLink = function(cellKey, zoom) {
      var b, geoLink64;
      b = "" + zoom + "x" + cellKey;
      geoLink64 = new Buffer(b).toString('base64');
      return this.now.insertMessage('Have a link:', "<a href='/l/" + geoLink64 + "'>/l/" + geoLink64 + "</a>");
    };
    CUser = (function() {
      var allByCid, allBySid, allByUid;

      CUser.name = 'CUser';

      allByCid = {};

      allBySid = {};

      allByUid = {};

      CUser.byCid = function(cid) {
        return allByCid[cid];
      };

      CUser.byCidFull = function(cid) {
        return allByCid[cid];
      };

      CUser.bySid = function(sid) {
        return allBySid[sid];
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
        this.riteQueue = [];
        if ((_ref = nowUser.session) != null ? _ref.auth : void 0) {
          this.uid = nowUser.session.auth.userId;
          models.User.findById(this.uid, function(err, doc) {
            _this.login = doc.login;
            _this.nowUser.login = doc.login;
            return _this.nowUser.powers = doc.powers;
          });
          allByUid[this.uid] = this;
        } else {
          SessionModel.findOne({
            'sid': this.sid
          }, function(err, doc) {
            _this.uid = doc._id;
            _this.nowUser.soid = doc._id;
            return allByUid[_this.uid] = _this;
          });
        }
        allByCid[this.cid] = this;
        allBySid[this.sid] = this;
      }

      CUser.prototype.findEdits = function(riteQueue) {
        var i, results, _i, _ref, _ref1, _ref2;
        if (riteQueue.length === 1) {
          return riteQueue;
        }
        results = [];
        riteQueue.sort(function(a, b) {
          if (a.y === b.y) {
            if (a.x === b.x) {
              return a.rite.date - b.rite.date;
            } else {
              return a.x - b.x;
            }
          } else {
            return a.y - b.y;
          }
        });
        for (i = _i = 0, _ref = riteQueue.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
          if (riteQueue[i].y === ((_ref1 = riteQueue[i + 1]) != null ? _ref1.y : void 0)) {
            results.push(riteQueue[i]);
          } else if (riteQueue[i].y === ((_ref2 = riteQueue[i - 1]) != null ? _ref2.y : void 0)) {
            results.push(riteQueue[i]);
          }
        }
        return results;
      };

      CUser.prototype.addToRiteQueue = function(edit) {
        var _this = this;
        this.riteQueue.push(edit);
        clearTimeout(this.timerId);
        return this.timerId = delay(1000 * 5, function() {
          var results;
          results = _this.findEdits(_this.riteQueue);
          _this.riteQueue = [];
          _this.processEdit(results);
          return false;
        });
      };

      CUser.prototype.processEdit = function(results) {
        var cellPoints, col, fix, fixed, i, login, note, r, row, s, toNotify, type, uid, x, y, _i, _j, _k, _len, _len1, _ref, _ref1, _ref2, _ref3;
        console.log('processEdit');
        s = '';
        toNotify = {
          own: [results[0].rite.owner],
          overrite: [],
          echo: [],
          downrote: []
        };
        fix = {};
        fixed = [];
        for (_i = 0, _len = results.length; _i < _len; _i++) {
          r = results[_i];
          if (!fix[r.y]) {
            fix[r.y] = {};
          }
          fix[r.y][r.x] = r;
          if (r.originalOwner) {
            if ((_ref = r.originalOwner.toString(), __indexOf.call(toNotify[r.commandType], _ref) < 0) && r.originalOwner.toString() !== toNotify.own[0].toString()) {
              toNotify[r.commandType].push(r.originalOwner.toString());
            }
          }
        }
        cellPoints = [];
        for (y in fix) {
          if (!__hasProp.call(fix, y)) continue;
          row = fix[y];
          for (x in row) {
            if (!__hasProp.call(row, x)) continue;
            col = row[x];
            fixed.push(col);
            cellPoints.push({
              x: x,
              y: y
            });
          }
        }
        fixed.sort(function(a, b) {
          if (a.y === b.y) {
            return a.x - b.x;
          } else {
            return a.y - b.y;
          }
        });
        for (i = _j = 0, _ref1 = fixed.length - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; i = 0 <= _ref1 ? ++_j : --_j) {
          s += fixed[i].rite.contents;
          if (fixed[i + 1] && ((_ref2 = fixed[i + 1]) != null ? _ref2.y : void 0) !== fixed[i].y) {
            s += '<br>';
          }
        }
        if (this.login) {
          login = this.login;
        } else {
          login = 'Someone';
        }
        for (type in toNotify) {
          _ref3 = toNotify[type];
          for (_k = 0, _len1 = _ref3.length; _k < _len1; _k++) {
            uid = _ref3[_k];
            note = new models.Note({
              x: results[0].x,
              y: results[0].y,
              contents: s,
              read: type === 'own' ? true : false,
              from: results[0].rite.owner,
              fromLogin: login,
              to: uid,
              type: type,
              world: results[0].world,
              cellPoints: cellPoints
            });
            if (type !== 'own') {
              if (CUser.byUid(uid)) {
                nowjs.getClient(CUser.byUid(uid).cid, function() {
                  this.now.insertMessage(noteHeads[type], "<span class='user'>" + login + "</span> " + noteBodies[type] + "<br>They wrote: <blockquote>" + s + "</blockquote><br><a class='btn trigger' data-action='goto' data-payload='" + note.x + "x" + note.y + "'>Go See</a>", 'alert-info', 10);
                  return note.read = true;
                });
              }
            }
            note.save();
          }
        }
      };

      CUser.prototype.destroy = function() {
        delete allByCid[this.cid];
        delete allBySid[this.sid];
        delete allByUid[this.uid];
        return delete this.nowUser;
      };

      return CUser;

    })();
    return [everyone, CUser];
  };

  noteBodies = {
    overrite: 'wrote over what you wrote. ',
    echo: 'echoed something you wrote. ',
    downrote: 'tried to over write what you wrote. '
  };

  noteHeads = {
    overrite: 'Over Written!',
    echo: 'Echoed',
    downrote: 'Attempted Over Write'
  };

  delay = function(ms, func) {
    return setTimeout(func, ms);
  };

  Array.prototype.filter = function(func) {
    var x, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = this.length; _i < _len; _i++) {
      x = this[_i];
      if (func(x)) {
        _results.push(x);
      }
    }
    return _results;
  };

}).call(this);
