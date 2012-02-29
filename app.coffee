express = require 'express'
nowjs = require 'now'
mongoose = require 'mongoose'
connect = require 'connect'
mongoose.connect('mongodb://localhost/mapist')
jade = require('jade')
# less = require('less')

fs = require('fs')
events = require('events')
util = require('util')

leaflet = require './leaflet-custom-src.js'
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
  app.use express.static __dirname+'/public'
  app.set 'view engine', 'jade'
  app.use express.logger({ format: ':method :url' })
  app.set 'view options', { layout: false }
  app.use express.errorHandler {dumpExceptions:true, showStack:true}

mainWorldId = mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001")

everyone = nowjs.initialize app

config = {maxZoom: 18}

cUsers = {} #all of the connected users, by clientId (nowjs)
aUsers = {} #all connected and auth'd users, by actual userId (mongoose _id)

nowjs.on 'connect', ->
  # console.log this.user
  sid=decodeURIComponent(this.user.cookie['connect.sid'])
  if this.user.session?.auth
    cUsers[this.user.clientId]={sid:sid, userId: this.user.session.auth.userId }
    aUsers[this.user.session.auth.userId]={sid:sid,cid: this.user.clientId}
  else
    cUsers[this.user.clientId]={sid:sid}
  console.log this.user.clientId, 'connected clientId: '
  # console.log 'connected sid: ', sid
  true

nowjs.on 'disconnect', ->
  delete cUsers[this.user.clientId]
  if this.user.session?.auth
    delete aUsers[this.user.session.auth.userId]
    console.log 'removing authd disconnected user'
  console.log 'removing disconnected user'

everyone.now.setBounds = (bounds) ->
  b = new leaflet.L.Bounds bounds.max, bounds.min
  cUsers[this.user.clientId].bounds = b

everyone.now.setClientState = (callback) ->
  if this.user.session
    callback(this.user.session)

everyone.now.setSelectedCell = (cellPoint) ->
  cid = this.user.clientId
  cUsers[cid].selected = cellPoint
  toUpdate = getWhoCanSee(cellPoint)
  for i of toUpdate
    if i != cid
      updates = {cid:cUsers[cid]} #client side is set up to recieve a number of updates, hence this being a list
      nowjs.getClient i, -> this.now.drawCursors(updates)

everyone.now.writeCell = (cellPoint, content) ->
  # console.log 'this.user', this.user
  cid = this.user.clientId
  sid= decodeURIComponent this.user.cookie['connect.sid']
  props = {}
  isOwnerAuth = false
  if this.user.session.auth
    isOwnerAuth = true
    ownerId = this.user.session.auth.userId
    props.color = this.user.session.color
    models.writeCellToDb(cellPoint, content, mainWorldId, ownerId, isOwnerAuth,  props)

    # Disabled for testing-
    # this writes to your personal world.
    # models.User.findById ownerId, (err, user) ->
      # models.writeCellToDb(cellPoint, content, user.personalWorld, ownerId, isOwnerAuth,  props)
  else
    SessionModel.findOne {'sid': sid } , (err, doc) ->
      data = JSON.parse(doc.data)
      ownerId=doc._id
      props.color = data.color
      models.writeCellToDb(cellPoint, content, mainWorldId, ownerId, isOwnerAuth,  props) #userId shouldbe an objectID for consistancy, either session or real user
  
  if this.user.session.color? # if we have it, lets use it. the above won't have it in time to send to other clients
    props.color= this.user.session.color

  toUpdate = getWhoCanSee(cellPoint)
  edits = {}
  for i of toUpdate
    if i !=cid
      edits[cid] = {cellPoint: cellPoint, content: content, props:props}
      nowjs.getClient i, -> this.now.drawEdits(edits)
  true

everyone.now.getTile= (absTilePoint, numRows, callback) ->
  models.Cell.where('world', mainWorldId)
    .where('x').gte(absTilePoint.x).lt(absTilePoint.x+numRows) #numrows for both, numcol == numrows
    .where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows) #lt or lte??
    .populate('current')
    .run (err,docs) =>
      results = {}
      if docs.length
        for c in docs
          pCell = {x: c.y, y: c.y, contents: c.current.contents, props: c.current.props}
          results["#{c.x}x#{c.y}"] = pCell #pCell is a processed cell
        callback(results, absTilePoint)
      else
        # console.log 'not found'
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

app.get '/', (req, res) ->
    res.render 'map_base.jade', { title: 'Mapist' }


# everyone.now.sendSystemMessage = (heading, message, cssclass="" )->
  # html = "<div class='alert fade  #{cssclass} '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>#{heading}</h4>#{message}</div>"
  # this.now.insertMessage(html)
  
  
everyone.now.setUserOption = (type, payload) ->
  console.log 'setUserOption', type, payload
  if type = 'color'
    this.user.session.color=payload
    this.user.session.save()
    if this.user.session.auth
      userId = this.user.session.auth.userId
      models.User.findById userId, (err, doc)=>
        console.log err if err
        doc.color= payload
        doc.save()
        console.log 'USER COLORCHANGE', doc
        this.now.insertMessage('hi', 'nice color')



#Moved this here so it can take advantage of nowjs 
models.User.prototype.on 'receivedEcho', (rite) ->
  if aUsers[this._id]
    userId= this._id
    rite.getOwner (err,u)->
      console.log err if err
      nowjs.getClient aUsers[userId].cid, ->
        if u
          this.now.insertMessage 'Echoed!', "#{u.login} echoed what you said!"
        else
          this.now.insertMessage 'Echoed!', "Someone echoed what you said!"
  return true


models.User.prototype.on 'receivedOverRite', (rite) ->
  # console.log 'this: ', this
  if aUsers[this._id]
    userId= this._id
    rite.getOwner (err,u)->
      console.log err if err
      nowjs.getClient aUsers[userId].cid, ->
        if u
          this.now.insertMessage 'Over Written', "Someone called #{u.login} is writing over your cells. Click for more info"
        else
          this.now.insertMessage 'Over Written', "Someone is writing over your cells. Click for more info"
  # else if 
  # console.log rite
  return true

models.mongooseAuth.helpExpress(app)

app.listen 3000
