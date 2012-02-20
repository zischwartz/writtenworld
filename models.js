(function() {
  var CellSchema, ObjectId, Rite, RiteSchema, Schema, UserSchema, WorldSchema, mongoose, mongooseAuth;

  mongoose = require('mongoose');

  Schema = mongoose.Schema;

  ObjectId = Schema.ObjectId;

  WorldSchema = new Schema({
    owner: ObjectId,
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
    }
  });

  exports.World = mongoose.model('World', WorldSchema);

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
    echoes: {
      type: Number,
      "default": 0
    },
    color: {
      type: String,
      "default": ' '
    },
    isEcho: {
      type: Boolean,
      "default": false
    }
  });

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

  exports.writeCellToDb = function(cellPoint, contents, worldId, ownerId) {
    exports.Cell.findOne({
      world: worldId,
      x: cellPoint.x,
      y: cellPoint.y
    }).populate('current').run(function(err, cell) {
      var rite;
      if (cell) console.log('BEFORE', cell.current);
      if (err) console.log(err);
      rite = new Rite({
        contents: contents,
        owner: ownerId
      });
      if (!cell) {
        cell = new exports.Cell({
          x: cellPoint.x,
          y: cellPoint.y,
          contents: contents,
          world: worldId
        });
      } else if (cell.current.contents === contents) {
        console.log('its an echo! ', cell.current.contents, ' ', contents);
        cell.current.echoes += 1;
        cell.current.save(function(err) {
          if (err) return console.log(err);
        });
        rite.isEcho = true;
      }
      cell.history.push(rite);
      return rite.save(function(err) {
        if (!rite.isEcho) cell.current = rite._id;
        cell.contents = contents;
        cell.save(function(err) {
          if (err) return console.log(err);
        });
        return console.log('AFTER', cell.current);
      });
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
    password: {
      everyauth: {
        getLoginPath: '/login',
        postLoginPath: '/login',
        loginView: 'login.jade',
        getRegisterPath: '/register',
        postRegisterPath: '/register',
        registerView: 'register.jade',
        loginSuccessRedirect: '/',
        registerSuccessRedirect: '/'
      }
    }
  });

  exports.User = mongoose.model('User', UserSchema);

  exports.mongooseAuth = mongooseAuth;

}).call(this);
