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
  app.use express.session {secret: 'tshh secret', store : new sessionStore()}
  app.use express.favicon(__dirname + '/public/img/favicon.ico')
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
  initialWorldId = models.mainWorldId
  if req.loggedIn
    personalWorldId = req.user.personalWorld
    console.log req.user
    availableColors = powers.getAvailableColors req.user.totalEchoes
    canLink = powers.canLink req.user
  else
    personalWorldId = null
    availableColors = powers.unregisteredColors()
    canLink=false
  res.render 'map_base.jade',
    title: 'Written World'
    mainWorldId: models.mainWorldId
    initialWorldId:models.mainWorldId
    personalWorldId:personalWorldId
    worldSpec: JSON.stringify(models.mainWorld.config)
    availableColors: availableColors
    isPersonal: false
    isAuth: req.loggedIn
    initialPos: JSON.stringify options.initialPos ? false


app.get '/', (req, res) ->
  render_world(req,res)

app.get '/l/:l', (req, res) ->
  # console.log 'loc based!!'
  b=new Buffer(req.params.l, 'base64').toString('ascii')
  g= b.split ':'
  console.log g
  render_world(req, res, {initialPos:{x:g[0], y:g[1]}})

app.get '/home', (req, res) ->
  if req.loggedIn
    personalWorldId= req.user.personalWorld
    worlds = []
    models.World.findById  personalWorldId ,(err,world) ->
      worlds.push world
      res.render 'home.jade', { title: 'Home', worlds: worlds}
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
          res.render 'map_base.jade',
            title: world.name
            initialWorldId: world._id
            mainWorldId: models.mainWorldId
            personalWorldId: world._id
            worldSpec: JSON.stringify(world.config)
            availableColors : powers.getAvailableColors req.user.totalEchoes
            isAuth: req.loggedIn
            isPersonal: true
          # res.write 'error'
          # res.end()
      else #it's not personal/private
        res.render 'map_base.jade', {title: world.name}
  else
    #first add a message saying you gota login
    res.redirect('/login')


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


# processEdits = ->
#  if riteQueue.length
#    seed= riteQueue.pop()
#    models.findEdits seed, [], (edit)->
#     console.log 'edits: '
#     for c in edit
#       console.log c.current.contents
#     # console.log edit
#  process.nextTick(processEdits)

# processEdits()

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
