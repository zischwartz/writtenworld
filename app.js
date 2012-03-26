(function() {
  var SessionModel, app, connect, events, express, jade, models, mongoose, nowjs, nownow, port, sessionStore, util, _ref,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  express = require('express');

  nowjs = require('now');

  connect = require('connect');

  mongoose = require('mongoose');

  mongoose.connect('mongodb://localhost/mapist');

  jade = require('jade');

  events = require('events');

  util = require('util');

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
    console.log('-in development mode-');
    app.use(express.static(__dirname + '/public'));
    app.set('view engine', 'jade');
    app.use(express.logger({
      format: ':method :url'
    }));
    app.set('view options', {
      layout: false
    });
    app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
    return app.set('port', 3000);
  });

  app.configure('production', function() {
    console.log('-in production mode-');
    app.use(express.static(__dirname + '/public'));
    app.set('view engine', 'jade');
    app.use(express.logger({
      format: ':method :url'
    }));
    app.set('view options', {
      layout: false
    });
    app.use(express.errorHandler());
    return app.set('port', 80);
  });

  nownow = require('./nownow.js')(app, SessionModel);

  app.get('/', function(req, res) {
    var worldId;
    worldId = models.mainWorldId;
    return res.render('map_base.jade', {
      title: 'Mapist',
      worldId: worldId
    });
  });

  app.get('/home', function(req, res) {
    var personalWorldId, worlds;
    if (req.loggedIn) {
      personalWorldId = req.user.personalWorld;
      worlds = [];
      return models.World.findById(personalWorldId, function(err, world) {
        worlds.push(world);
        return res.render('home.jade', {
          title: 'Home',
          worlds: worlds
        });
      });
    } else {
      return res.render('home.jade', {
        title: 'Home',
        worlds: worlds
      });
    }
  });

  app.get('/uw/:slug', function(req, res) {
    if (req.loggedIn) {
      return models.World.findOne({
        slug: req.params.slug
      }, function(err, world) {
        if (world.personal) {
          if (world.owner.toString() === req.user._id.toString()) {
            return res.render('map_base.jade', {
              title: world.name,
              worldId: world._id
            });
          } else {
            res.write('error');
            return res.end();
          }
        } else {
          return res.render('map_base.jade', {
            title: world.name
          });
        }
      });
    } else {
      return res.redirect('/login');
    }
  });

  models.mongooseAuth.helpExpress(app);

  port = app.settings.port;

  if (__indexOf.call(process.argv, 'prod') >= 0) {
    console.log('DIRTY PRODUCTION MODE ENABLED');
    port = 80;
  }

  app.listen(port);

  console.log('SCRIBVERSE is running on :');

  console.log(app.address());

  console.log('- - - - - ');

}).call(this);
