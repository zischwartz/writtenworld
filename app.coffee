express = require 'express'
nowjs = require 'now'
leaflet = require './leaflet-custom-src.js'
mongoose = require 'mongoose'
connect = require 'connect'
mongoose.connect('mongodb://localhost/mapist')
# less = require('less')

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
  # app.use app.router #the above says not to use this.

app.configure 'development', ->
  app.use express.static __dirname+'/public'
  app.set 'view engine', 'jade'
  app.use express.logger({ format: ':method :url' })
  app.set 'view options', { layout: false }
  app.use express.errorHandler {dumpExceptions:true, showStack:true}

mainWorldId = mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001")

everyone = nowjs.initialize app

config = {maxZoom: 18}

cUsers = {} #all of the connected users

nowjs.on 'connect', ->
  console.log this.user
  # console.log everyauth.user
  sid=decodeURIComponent(this.user.cookie['connect.sid'])
  cUsers[this.user.clientId]={sid:sid}
  console.log this.user.clientId, 'connected'
  console.log 'connected sid: ', sid

nowjs.on 'disconnect', ->
  delete cUsers[this.user.clientId]
  console.log 'removing disconnected user'

everyone.now.setBounds = (bounds) ->
  b = new leaflet.L.Bounds bounds.max, bounds.min
  # console.log b
  cUsers[this.user.clientId].bounds = b
  
everyone.now.setSelectedCell = (cellPoint) ->
  cid = this.user.clientId
  cUsers[cid].selected = cellPoint
  toUpdate = getWhoCanSee(cellPoint)
  
  for i of toUpdate
    if i != cid
      updates = {cid:cUsers[cid]} #client side is set up to recieve a number of updates, hence this
      nowjs.getClient i, -> this.now.drawCursors(updates)

everyone.now.writeCell = (cellPoint, content) ->
  # console.log 'this.user', this.user
  cid = this.user.clientId
  sid= decodeURIComponent this.user.cookie['connect.sid']
  SessionModel.findOne {'sid': sid } , (err, doc) ->
    console.log err if err
    ownerId=doc._id
    models.writeCellToDb(cellPoint, content, mainWorldId, ownerId) #userId shouldbe an objectID for consistancy, either session or real user
  
  toUpdate = getWhoCanSee(cellPoint)
  # console.log cellPoint, content
  edits = {}
  for i of toUpdate
    if i !=cid
      edits[cid] = {cellPoint: cellPoint, content: content}
      nowjs.getClient i, -> this.now.drawEdits(edits)
  true

everyone.now.getTile= (absTilePoint, numRows, callback) ->
  models.Cell.where('world', mainWorldId)
    .where('x').gte(absTilePoint.x).lt(absTilePoint.x+numRows) #numrows for both, numcol == numrows
    .where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows) #lt or lte??
    .run (err,docs) =>
      results = {}
      if docs.length
        for c in docs
          results["#{c.x}x#{c.y}"] = c
          # console.log "#{c.x}x#{c.y}"
        callback(results, absTilePoint)
        # console.log 'abstilepoint', absTilePoint
      else
        # console.log 'nope'
        callback(results, absTilePoint)

#utility for the above
getWhoCanSee = (cellPoint) ->
  toUpdate = {}
  for i of cUsers
    if cUsers[i].bounds.contains(cellPoint)
      toUpdate[i] = cUsers[i]
  return toUpdate

app.get '/home', (req, res) ->
    res.render 'home.jade', { title: 'My Site' }

app.get '/test', (req, res) ->
    res.render 'map_base.jade', { title: 'My Site' }



models.mongooseAuth.helpExpress(app)
app.listen 3000
