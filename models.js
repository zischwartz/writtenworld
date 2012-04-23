// Generated by CoffeeScript 1.3.1
(function() {
  var CellSchema, FeedbackSchema, ObjectId, Rite, RiteSchema, Schema, UserSchema, WorldSchema, events, mongoose, mongooseAuth, ritePropsDefs, slugGenerator, util,
    __hasProp = {}.hasOwnProperty;

  util = require('util');

  events = require('events');

  mongoose = require('mongoose');

  mongoose.connect('mongodb://localhost/mapist');

  Schema = mongoose.Schema;

  ObjectId = Schema.ObjectId;

  WorldSchema = new Schema({
    owner: ObjectId,
    ownerlogin: {
      type: String
    },
    name: {
      type: String,
      unique: true
    },
    created: {
      type: Date,
      "default": Date.now
    },
    personal: {
      type: Boolean,
      "default": true
    },
    "public": {
      type: Boolean,
      "default": false
    },
    slug: {
      type: String,
      lowercase: true,
      trim: true
    },
    meta: {
      maxZoom: {
        type: Number
      },
      minZoom: {
        type: Number
      },
      defaultChar: {
        type: String,
        "default": ' '
      },
      tileSize: {
        x: {
          type: Number
        },
        y: {
          type: Number
        }
      }
    },
    props: {
      type: Schema.Types.Mixed,
      "default": {}
    }
  });

  slugGenerator = function(options) {
    var key;
    options = options || {};
    key = options.key || 'name';
    return slugGenerator = function(schema) {
      return schema.path(key).set(function(v) {
        this.slug = v.toLowerCase().replace(/[^a-z0-9]/g, '').replace(/-+/g, '');
        return v;
      });
    };
  };

  WorldSchema.plugin(slugGenerator());

  exports.World = mongoose.model('World', WorldSchema);

  exports.World.findOne({
    name: 'main'
  }, function(err, world) {
    var mainWorld;
    if (world) {
      exports.mainWorldId = world._id;
      exports.mainWorld = world;
      return console.log(' Found main world');
    } else {
      console.log(' Could not find main world...');
      mainWorld = new exports.World({
        name: 'main',
        personal: false,
        "public": true,
        meta: {
          maxZoom: 18,
          minZoom: 10,
          tileSize: {
            x: 192,
            y: 256
          }
        },
        props: {
          echoes: true
        }
      });
      return mainWorld.save(function(err, world) {
        if (err) {
          console(log(err));
        }
        console.log(' So we created the main world');
        exports.mainWorldId = world._id;
        return exports.mainWorld;
      });
    }
  });

  ritePropsDefs = {
    echoes: -1,
    echoers: [],
    downroters: []
  };

  RiteSchema = new Schema({
    contents: {
      type: String,
      "default": ' '
    },
    date: {
      type: Date,
      "default": Date.now
    },
    owner: ObjectId,
    props: {
      type: Schema.Types.Mixed,
      "default": {}
    }
  });

  RiteSchema.methods.getOwner = function(cb) {
    return this.db.model('User').findById(this.owner).run(cb);
  };

  Rite = mongoose.model('Rite', RiteSchema);

  CellSchema = new Schema({
    world: ObjectId,
    x: {
      type: Number,
      required: true,
      min: 0
    },
    y: {
      type: Number,
      required: true,
      min: 0
    },
    current: {
      type: Schema.ObjectId,
      ref: 'Rite'
    },
    history: [
      {
        type: Schema.ObjectId,
        ref: 'Rite'
      }
    ]
  });

  CellSchema.index({
    world: 1,
    x: 1,
    y: 1
  }, {
    unique: true
  });

  exports.Cell = mongoose.model('Cell', CellSchema);

  exports.writeCellToDb = function(cellPoint, contents, worldId, riter, isOwnerAuth, isPersonal, props) {
    var key, rite, val;
    if (props == null) {
      props = {};
    }
    for (key in ritePropsDefs) {
      if (!__hasProp.call(ritePropsDefs, key)) continue;
      val = ritePropsDefs[key];
      if (!(props != null ? props[key] : void 0)) {
        if (key === 'echoers' || key === 'downroters') {
          props[key] = [];
        } else {
          props[key] = val;
        }
      }
    }
    rite = new Rite({
      contents: contents,
      owner: riter,
      props: props
    });
    rite.markModified('props');
    exports.Cell.findOne({
      world: worldId,
      x: cellPoint.x,
      y: cellPoint.y
    }).populate('current').run(function(err, cell) {
      var alreadyDownPos, alreadyEchoPos, cEchoes, d, doEchoLogic, e, i, isAlreadyDownroter, isAlreadyEchoer, isBlankCurrent, isBlankRite, isLegitDownrote, isLegitEcho, isPotentialEcho, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
      if (err) {
        console.log(err);
      }
      if (!cell) {
        cell = new exports.Cell({
          x: cellPoint.x,
          y: cellPoint.y,
          world: worldId
        });
      }
      cell.history.push(rite);
      if (isPersonal) {
        cell.current = rite;
        rite.save(function(err) {
          cell.current = rite._id;
          return cell.save(function(err) {
            if (err) {
              return console.log(err);
            }
          });
        });
        console.log('personal, lets gtfo');
        return;
      }
      isAlreadyEchoer = false;
      isAlreadyDownroter = false;
      i = -1;
      alreadyDownPos = -1;
      alreadyEchoPos = -1;
      if (cell != null ? (_ref = cell.current) != null ? _ref.props.echoers : void 0 : void 0) {
        _ref2 = cell != null ? (_ref1 = cell.current) != null ? _ref1.props.echoers : void 0 : void 0;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          e = _ref2[_i];
          i += 1;
          if (e.toString() === riter.toString()) {
            isAlreadyEchoer = true;
            alreadyEchoPos = i;
            console.log("already echoer!!! " + alreadyEchoPos);
          }
        }
      }
      if (cell != null ? (_ref3 = cell.current) != null ? _ref3.props.downroters : void 0 : void 0) {
        _ref5 = cell != null ? (_ref4 = cell.current) != null ? _ref4.props.downroters : void 0 : void 0;
        for (_j = 0, _len1 = _ref5.length; _j < _len1; _j++) {
          d = _ref5[_j];
          i += 1;
          if (d.toString() === riter.toString()) {
            isAlreadyDownroter = true;
            alreadyDownPos = i;
            console.log("already downroter!!! " + alreadyDownPos);
          }
        }
      }
      isPotentialEcho = ((_ref6 = cell.current) != null ? _ref6.contents : void 0) === rite.contents;
      isLegitEcho = isPotentialEcho && !isAlreadyEchoer;
      isBlankCurrent = !cell.current || ((_ref7 = cell.current) != null ? _ref7.contents : void 0) === exports.mainWorld.meta.defaultChar;
      isBlankRite = rite.contents === exports.mainWorld.meta.defaultChar;
      cEchoes = cell != null ? (_ref8 = cell.current) != null ? (_ref9 = _ref8.props) != null ? _ref9.echoes : void 0 : void 0 : void 0;
      isLegitDownrote = false;
      doEchoLogic = function() {
        var downroteIt, echoIt, normalRite, overriteIt;
        normalRite = function(cell, rite, riter) {
          rite.props.echoes += 1;
          rite.props.echoers.push(riter);
          return rite.save(function(err) {
            cell.current = rite._id;
            return cell.save();
          });
        };
        echoIt = function(cell, rite, riter) {
          cell.current.props.echoes += 1;
          cell.current.props.echoers.push(riter);
          if (isAlreadyDownroter) {
            cell.current.props.downroters.splice(alreadyDownPos, 1);
          }
          rite.save();
          cell.current.markModified('props');
          cell.current.save(function(err) {
            if (err) {
              return console.log(err);
            }
          });
        };
        downroteIt = function(cell, rite, riter) {
          cell.current.props.echoes -= 1;
          cell.current.props.downroters.push(riter);
          if (isAlreadyEchoer) {
            cell.current.props.echoers.splice(alreadyEchoPos, 1);
          }
          rite.save();
          cell.current.markModified('props');
          cell.current.save(function(err) {
            if (err) {
              return console.log(err);
            }
          });
        };
        overriteIt = function(cell, rite, riter) {
          rite.props.echoes += 1;
          rite.props.echoers.push(riter);
          rite.save(function(err) {
            cell.current = rite._id;
            return cell.save(function(err) {
              if (err) {
                return console.log(err);
              }
            });
          });
        };
        if (isBlankCurrent) {
          console.log('blank, just write');
          normalRite(cell, rite, riter);
          return true;
        }
        if (isPotentialEcho && isAlreadyEchoer) {
          console.log('Echoing yourself too much will make you go blind');
          return false;
        }
        if (isAlreadyDownroter && !isPotentialEcho) {
          console.log('FU, you cannot downrote again');
          return false;
        } else {
          if (isLegitEcho) {
            console.log('Legit echo, cool');
            echoIt(cell, rite, riter);
            return true;
          } else {
            if (cEchoes <= 0) {
              overriteIt(cell, rite, riter);
              console.log('legit overrite');
              return true;
            } else if (cEchoes >= 1) {
              if (isAlreadyEchoer) {
                if (cEchoes === 1) {
                  overriteIt(cell, rite, riter);
                } else {
                  downroteIt(cell, rite, riter);
                }
                console.log('yr downroting something you echoed. crazy');
                return true;
              } else {
                console.log('legit downrote');
                downroteIt(cell, rite, riter);
                return true;
              }
            }
          }
        }
      };
      doEchoLogic();
      return console.log('-----------');
    });
    return true;
  };

  mongooseAuth = require('mongoose-auth');

  UserSchema = new Schema({
    totalRites: {
      type: Number,
      "default": 0
    },
    activeRites: {
      type: Number,
      "default": 0
    },
    totalEchoes: {
      type: Number,
      "default": 0
    },
    color: {
      type: String,
      "default": ''
    },
    personalWorld: ObjectId,
    email: String
  });

  UserSchema.plugin(mongooseAuth, {
    everymodule: {
      everyauth: {
        User: function() {
          return exports.User;
        }
      }
    },
    password: {
      extraParams: {
        email: String
      },
      everyauth: {
        getLoginPath: '/login',
        postLoginPath: '/login',
        loginView: 'login.jade',
        getRegisterPath: '/register',
        postRegisterPath: '/register',
        registerView: 'register.jade',
        loginSuccessRedirect: '/',
        registerSuccessRedirect: '/',
        respondToRegistrationSucceed: function(res, user, data) {
          var personal;
          personal = new exports.World({
            personal: true,
            owner: user._id,
            name: "" + user.login + "'s History",
            ownerlogin: user.login
          });
          personal.save(function(err, doc) {
            user.personalWorld = personal._id;
            return user.save(function(err) {
              if (err) {
                return console.log(err);
              }
            });
          });
          if (data.session.redirectTo) {
            res.writeHead(303, {
              'Location': data.session.redirectTo
            });
          } else {
            res.writeHead(303, {
              'Location': '/'
            });
          }
          res.end();
          return true;
        }
      }
    }
  });

  exports.User = mongoose.model('User', UserSchema);

  FeedbackSchema = new Schema({
    contents: {
      type: String,
      "default": ' '
    }
  });

  exports.Feedback = mongoose.model('Feedback', FeedbackSchema);

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

  exports.mongooseAuth = mongooseAuth;

}).call(this);
