express = require 'express'
nowjs = require 'now'
connect = require 'connect'

mongoose = require 'mongoose'
mongoose.connect('mongodb://localhost/mapist')
jade = require('jade')

# fs = require('fs')
events = require('events')
util = require('util')

models= require './models.js'

[sessionStore, SessionModel] = require("./mongoose-session.js")(connect) #my edited version returns the model as well because looks weren't working through the get() interface

app = express.createServer()

app.configure ->
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session {secret: 'tshh secret', store : new sessionStore()}
  app.use express.favicon(__dirname + '/public/favicon.ico')
  # app.use express.compiler { src: __dirname + '/public', enable: ['less', 'coffeescript'] }
  app.use models.mongooseAuth.middleware()
  # app.use app.router #mongooseAuth says not to use this.

app.configure 'development', ->
  console.log '-in development mode-'
  app.use express.static __dirname+'/public'
  app.set 'view engine', 'jade'
  app.use express.logger({ format: ':method :url' })
  app.set 'view options', { layout: false }
  app.use express.errorHandler {dumpExceptions:true, showStack:true}
  app.set 'port', 3000

app.configure 'production', ->
  console.log '-in production mode-'
  app.use express.static __dirname+'/public'
  app.set 'view engine', 'jade'
  app.use express.logger({ format: ':method :url' })
  app.set 'view options', { layout: false }
  app.use express.errorHandler()
  app.set 'port', 80

nownow = require('./nownow.js')(app, SessionModel)

app.get '/', (req, res) ->
  worldId = models.mainWorldId
  res.render 'map_base.jade', { title: 'Mapist', worldId: worldId }

app.get '/home', (req, res) ->
  if req.loggedIn
    personalWorldId= req.user.personalWorld
    worlds = []
    models.World.findById  personalWorldId ,(err,world) ->
      worlds.push world
      res.render 'home.jade', { title: 'Home', worlds: worlds}
  else
      res.render 'home.jade', { title: 'Home', worlds: worlds}

app.get '/uw/:slug', (req, res)->
  if req.loggedIn
    models.World.findOne {slug: req.params.slug},(err,world) ->
      if world.personal
        if world.owner.toString() is req.user._id.toString()
          res.render 'map_base.jade', {title: world.name, worldId: world._id}
        else
          res.write 'error'
          res.end()
      else #it's not personal/private
        res.render 'map_base.jade', {title: world.name}
  else
    #first add a message saying you gota login
    res.redirect('/login')

models.mongooseAuth.helpExpress(app)

app.listen(app.settings.port)


