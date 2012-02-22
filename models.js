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
    isEcho: {
      type: Boolean,
      "default": false
    },
    props: {}
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

  exports.writeCellToDb = function(cellPoint, contents, worldId, ownerId, isOwnerAuth, props) {
    if (props == null) props = {};
    console.log('writing cell with ', contents);
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
      } else if ((cell.current.contents === contents) && (cell.current.owner.toString() !== ownerId) && isOwnerAuth) {
        console.log('is echo!');
        cell.current.echoes += 1;
        cell.current.save(function(err) {
          if (err) return console.log(err);
        });
        rite.isEcho = true;
      }
      cell.history.push(rite);
      rite.save(function(err) {
        if (!rite.isEcho) cell.current = rite._id;
        cell.contents = contents;
        return cell.save(function(err) {
          if (err) return console.log(err);
        });
      });
      exports.User.findById(ownerId, function(err, user) {
        if (user) {
          user.totalRites += 1;
          return user.save();
        }
      });
      if (rite.isEcho) {
        return exports.User.findById(cell.current.owner, function(err, user) {
          if (user) {
            user.totalEchoes += 1;
            return user.save();
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
    personalWorld: ObjectId
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
        registerSuccessRedirect: '/',
        respondToRegistrationSucceed: function(res, user, data) {
          var personal;
          console.log('SSSSSSSSUCESSSSSSSS---------');
          personal = new exports.World({
            personal: true,
            owner: user._id,
            name: "" + user.login + "'s History"
          });
          personal.save(function(err, doc) {
            user.personalWorld = personal._id;
            return user.save();
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
