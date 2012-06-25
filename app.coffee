express = require 'express'
nowjs = require 'now'
connect = require 'connect'

if 'prod' in process.argv
  DEBUG= false
else
  DEBUG= true

console.log 'DEBUG? ', DEBUG

require 'coffee-script'

mongoose = require 'mongoose'
mongoose.connect('mongodb://localhost/mapist')
jade = require('jade')

fs = require('fs')
events = require('events')
util = require('util')

models= require './models'
powers = require './powers'

assetManager = require('connect-assetmanager')
root = __dirname + '/public'

assetManagerGroups =
  'js' :
    route: /\/assets\/js\/application\.js/
    path: root + '/js/'
    dataType: 'javascript'
    debug: DEBUG
    files: [
      'libs/jquery.min.js'
      'libs/watch_shim.js'
      'libs/colorpicker.js'
      'libs/bootstrap-collapse.js'
      'libs/bootstrap-dropdown.js'
      'libs/bootstrap-modal.js'
      'libs/bootstrap-transition.js'
      'libs/bootstrap-alert.js'
      'libs/bootstrap-tooltip.js'
      'libs/dotimeout.js'
      'libs/jquery.jrumble.min.js'
      # 'libs/JSLitmus.js'
      'leaflet-src.js'
      'config_client.js'
      'geo.js'
      'layer.js'
      'world.js'
      ]

assetsManagerMiddleware = assetManager(assetManagerGroups)

[sessionStore, SessionModel] = require("./lib/mongoose-session.js")(connect) #my edited version returns the model as well because looks weren't working through the get() interface

app = express.createServer()

app.configure ->
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session {secret: 'tshh secret', store : new sessionStore(), maxAge:new Date(Date.now()+3600000*24*30)}
  app.use express.favicon(__dirname + '/public/favicon.ico')
  app.use assetsManagerMiddleware
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
  app.set 'port', 3000
  # app.set 'port', 80

[nownow, CUser] = require('./nownow')(app, SessionModel)

  
render_world = (req, res, options={}) ->
  #for specific and personal worlds
  if not options.world
    initialWorldId = models.mainWorldId
    worldSpec=models.mainWorld.config
  else
    initialWorldId = options.world._id
    worldSpec = options.world.config

  if req.loggedIn
    personalWorldId = req.user.personalWorld
    availableColors = powers.getAvailableColors req.user.totalEchoes
    canLink = powers.canLink req.user
  else
    personalWorldId = null
    availableColors = powers.unregisteredColors()
    canLink=false

  res.render 'map_base.jade',
    title: 'Written World'
    mainWorldId: models.mainWorldId
    initialWorldId: initialWorldId
    personalWorldId:personalWorldId
    worldSpec: JSON.stringify(worldSpec)
    availableColors: availableColors
    isPersonal: options.world?.personal ? false
    isAuth: req.loggedIn
    initialPos: options.initialPos ? false
    unreadNotes: options.unreadNotes ? 0

app.get '/', (req, res) ->
  if req.loggedIn
    models.Note.count {to: req.user._id, read:false}, (err, noteNum) ->
      console.log noteNum
      render_world(req,res, {unreadNotes:noteNum})
  else
    render_world(req,res)

app.get '/l/:l', (req, res) ->
  b=new Buffer(req.params.l, 'base64').toString('ascii')
  render_world(req, res, {initialPos:b})

app.get '/wid/:id' , (req, res) ->
    models.World.findById req.params.id,(err,world) ->
      if world
        if world.personal
          res.redirect("/uw/#{world.slug}")
        else
          res.redirect("/")
      else
        res.redirect("/")

app.get '/uw/:slug', (req, res)->
  if req.loggedIn
    models.World.findOne {slug: req.params.slug},(err,world) ->
      if world.personal
        if world.owner.toString() is req.user._id.toString()
          render_world(req, res, {world: world})
      else #it's not personal/private
        render_world(req, res, {world: world._id,})
        # res.render 'map_base.jade', {title: world.name}
  else
    #first add a message saying you gota login
    res.redirect('/login')

app.get '/notes/:type?', (req, res) ->
  if req.loggedIn
      type = req.params.type
      if not type
        models.Note.where('type').or([ {from:req.user._id}, {to: req.user._id}]).sort('date', -1).run (err,notes) ->
          res.render 'include/notes.jade', { title: 'Notes', notes}
      else
        models.Note.where('type', type).or([ {from:req.user._id}, {to: req.user._id}]).sort('date', -1).run (err,notes) ->
          res.render 'include/notes.jade', { title: 'Notes', notes}

# PAGES
app.get '/home', (req, res) ->
  if req.loggedIn
    personalWorldId= req.user.personalWorld
    worlds = []
    models.World.findById  personalWorldId ,(err,world) ->
      worlds.push world
      models.Note.find().or([ {from:req.user._id}, {to: req.user._id}]).sort('date', -1).run (err,notes) ->
        res.render 'home.jade', { title: 'Home', worlds: worlds, notes}
  else
      res.render 'home.jade', { title: 'Home', worlds: worlds}

app.get '/about', (req, res) ->
  res.render 'about.jade', { title: 'About'}


app.get '/secretfeedback' , (req, res) ->
  models.Feedback.find (err, feedbacks)->
    res.render 'table.jade', {things:feedbacks}

app.get '/secretreset11' , (req, res) ->
  # console.log req.user
  if req.user?.login == 'zach'
    msg =[
      'Warning!'
      "The server is about to reset. Either we're fixing a bug or adding a feature. You may have to refresh or reload the page to keep writing. Sorry/ Thanks!"
      'major alert-danger'
      25]
    nownow.now.insertMessage msg[0], msg[1], msg[2], msg[3] 
    res.render 'about.jade', { title: 'About'}
  else
    res.render 'about.jade', { title: 'About'}


# a whole new world
# app.get '/:slug', (req, res)->
#     models.World.findOne {slug: req.params.slug},(err,world) ->
#       if world
#         if not world.personal
#             res.render 'map_base.jade',
#               title: world.name
#               initialWorldId: world._id
#               mainWorldId: models.mainWorldId
#               personalWorldId: null
#               worldSpec: JSON.stringify(world.config)


models.mongooseAuth.helpExpress(app)

port = app.settings.port
if 'prod' in process.argv
  console.log ' PRODUCTION MODE ENABLED'
  port = 80
  # disabled in favor of iptables
  
app.listen(port)

console.log 'process.env.node_env:'
console.log process.env.NODE_ENV
console.log 'app.settings.env:'
console.log app.settings.env

console.log 'SCRIBVERSE is running on :'
console.log app.address()
console.log '- - - - - '
