(function() {
  var CellSchema, ObjectId, Rite, RiteSchema, Schema, UserSchema, WorldSchema, events, mongoose, mongooseAuth, slugGenerator, util;

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
    public: {
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
      return console.log(world);
    } else {
      mainWorld = new exports.World({
        name: 'main',
        personal: false,
        public: true,
        meta: {
          maxZoom: 18,
          minZoom: 10,
          tileSize: {
            x: 192,
            y: 256
          }
        }
      });
      return mainWorld.save(function(err, world) {
        return exports.mainWorldId = world._id;
      });
    }
  });

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
    contents: {
      type: String,
      "default": ' '
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

  exports.writeCellToDb = function(cellPoint, contents, worldId, ownerId, isOwnerAuth, props) {
    if (props == null) props = {};
    exports.Cell.findOne({
      world: worldId,
      x: cellPoint.x,
      y: cellPoint.y
    }).populate('current').run(function(err, cell) {
      var rite;
      if (err) console.log(err);
      rite = new Rite({
        contents: contents,
        owner: ownerId,
        props: props
      });
      if (!cell) {
        cell = new exports.Cell({
          x: cellPoint.x,
          y: cellPoint.y,
          contents: contents,
          world: worldId
        });
      } else if ((cell.current.contents === contents) && (cell.current.owner.toString() !== ownerId)) {
        if (!cell.current.props.echoes) cell.current.props.echoes = 0;
        cell.current.props.echoes += 1;
        cell.current.markModified('props');
        cell.current.save(function(err) {
          if (err) return console.log(err);
        });
        rite.props.isEcho = true;
        rite.markModified('props');
      }
      cell.history.push(rite);
      rite.save(function(err) {
        if (!rite.props.isEcho) cell.current = rite._id;
        return cell.save(function(err) {
          if (err) return console.log(err);
        });
      });
      exports.User.findById(ownerId, function(err, user) {
        if (user) {
          user.totalRites += 1;
          return user.save(function(err) {
            if (err) return console.log(err);
          });
        }
      });
      if (cell.current) {
        return exports.User.findById(cell.current.owner, function(err, user) {
          if (user) {
            if (rite.props.isEcho) {
              user.totalEchoes += 1;
              user.save(function(err) {
                if (err) return console.log(err);
              });
              return user.emit('receivedEcho', rite);
            } else if (user._id.toString() !== ownerId && isOwnerAuth) {
              return user.emit('receivedOverRite', rite);
            }
          }
        });
      }
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
              if (err) return console.log(err);
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

  exports.mongooseAuth = mongooseAuth;

}).call(this);
