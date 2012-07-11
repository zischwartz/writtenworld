// Generated by CoffeeScript 1.3.1
(function() {
  var CellSchema, DEBUG, FeedbackSchema, NoteSchema, ObjectId, Rite, RiteSchema, Schema, UserSchema, WorldSchema, clone, events, mongoose, mongooseAuth, slugGenerator, util,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  DEBUG = true;

  if (__indexOf.call(process.argv, 'prod') >= 0) {
    DEBUG = false;
  }

  util = require('util');

  events = require('events');

  mongoose = require('mongoose');

  mongoose.connect('mongodb://localhost/mapist');

  Schema = mongoose.Schema;

  ObjectId = Schema.ObjectId;

  exports.ObjectIdFromString = mongoose.Types.ObjectId.fromString;

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
    config: {
      maxZoom: {
        type: Number
      },
      minZoom: {
        type: Number
      },
      defZoom: {
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
      },
      ruleSet: {
        type: String
      },
      tileServeUrl: {
        type: String
      },
      props: {
        type: Schema.Types.Mixed,
        "default": {}
      }
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
        config: {
          maxZoom: 20,
          minZoom: 10,
          tileSize: {
            x: 192,
            y: 256
          },
          tileServeUrl: "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png",
          ruleSet: false,
          props: {
            echoes: true
          }
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

  exports.Rite = Rite;

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

  NoteSchema = new Schema({
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
      "default": ''
    },
    read: {
      type: Boolean,
      "default": false
    },
    to: {
      type: Schema.ObjectId
    },
    from: {
      type: Schema.ObjectId
    },
    fromLogin: {
      type: String
    },
    type: {
      type: String
    },
    date: {
      type: Date,
      "default": Date.now
    },
    world: ObjectId,
    cellPoints: [
      {
        x: {
          type: Number
        },
        y: {
          type: Number
        }
      }
    ]
  });

  exports.Note = mongoose.model('Note', NoteSchema);

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
    email: String,
    name: String,
    inactive: {
      type: Boolean,
      "default": true
    },
    initialPos: String,
    powers: {
      jumpDistance: {
        type: Number,
        "default": 500000
      },
      lastLinkOn: {
        type: Date,
        "default": new Date(0)
      }
    }
  });

  UserSchema.plugin(mongooseAuth, {
    everymodule: {
      everyauth: {
        User: function() {
          return exports.User;
        }
      }
    },
    twitter: {
      everyauth: {
        myHostname: DEBUG ? 'http://0.0.0.0:3000' : 'http://writtenworld.org',
        consumerKey: DEBUG ? 'DEIaTcd5DQ7yceARLk6KLA' : 'CaOVgX2g6tJoJCHDoBUVg',
        consumerSecret: DEBUG ? 'NFKIDiVyQpRIXVu0T7nVEIylErrpdPcMFrewAgWDbjM' : 'pwC2JFsI96ApwCqtPwwU1HEqFwOGOAj0PcTmxpOjsfA',
        redirectPath: '/welcome'
      }
    },
    facebook: {
      everyauth: {
        myHostname: DEBUG ? 'http://0.0.0.0:3000' : 'http://writtenworld.org',
        appId: DEBUG ? '166126233512041' : '391056084275527',
        appSecret: DEBUG ? '272b9cb2b28698932dfca93aef9eee47' : '1e8690b4c88153a1626b3851ffe5f557',
        redirectPath: '/welcome'
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
        loginSuccessRedirect: '/welcome',
        registerSuccessRedirect: '/welcome'
      }
    }
  });

  exports.User = mongoose.model('User', UserSchema);

  FeedbackSchema = new Schema({
    contents: {
      type: String,
      "default": ' '
    },
    t: {
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

  clone = function(obj) {
    var flags, key, newInstance;
    if (!(obj != null) || typeof obj !== 'object') {
      return obj;
    }
    if (obj instanceof Date) {
      return new Date(obj.getTime());
    }
    if (obj instanceof RegExp) {
      flags = '';
      if (obj.global != null) {
        flags += 'g';
      }
      if (obj.ignoreCase != null) {
        flags += 'i';
      }
      if (obj.multiline != null) {
        flags += 'm';
      }
      if (obj.sticky != null) {
        flags += 'y';
      }
      return new RegExp(obj.source, flags);
    }
    newInstance = new obj.constructor();
    for (key in obj) {
      newInstance[key] = clone(obj[key]);
    }
    return newInstance;
  };

}).call(this);
