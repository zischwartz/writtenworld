express = require 'express'
nowjs = require 'now'
leaflet = require './leaflet-custom-src.js'
mongoose = require 'mongoose'
connect = require 'connect'
mongoose.connect('mongodb://localhost/mapist')
jade = require('jade')
# less = require('less')
fs = require('fs')

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
  console.log 'this.now=', this.now
  console.log this.user
  # console.log everyauth.user
  sid=decodeURIComponent(this.user.cookie['connect.sid'])
  cUsers[this.user.clientId]={sid:sid}
  console.log this.user.clientId, 'connected'
  console.log 'connected sid: ', sid
  true

nowjs.on 'disconnect', ->
  delete cUsers[this.user.clientId]
  console.log 'removing disconnected user'

everyone.now.setBounds = (bounds) ->
  b = new leaflet.L.Bounds bounds.max, bounds.min
  # console.log b
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
      updates = {cid:cUsers[cid]} #client side is set up to recieve a number of updates, hence this
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
    models.User.findById ownerId, (err, user) ->
      models.writeCellToDb(cellPoint, content, user.personalWorld, ownerId, isOwnerAuth,  props)
  else
    SessionModel.findOne {'sid': sid } , (err, doc) ->
      data = JSON.parse(doc.data)
      ownerId=doc._id
      props.color = data.color
      models.writeCellToDb(cellPoint, content, mainWorldId, ownerId, isOwnerAuth,  props) #userId shouldbe an objectID for consistancy, either session or real user
  
  if this.user.session.color? # if we have it, lets use it. the above won't have it in time to send to other clients
    props.color= this.user.session.color

  toUpdate = getWhoCanSee(cellPoint)
  # console.log cellPoint, content
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
# 
# app.get '/', (req, res) ->
#     res.render 'map_base.jade', { title: 'Mapist' }

app.get '/modals', (req, res) ->
  res.render 'modals.html'

# modalFile = fs.readFileSync('views/include/modal.jade')
# modalTemplate = jade.compile(modalFile.toString('utf8'))

# everyone.now.getModal= (type) ->
#   if type=='colorModal'
#     modalContent=
#       title: "Pick A Color"
#       body: ["Any color. Well, any of these colors. To get custom colors, you need to get echoes."]
#       htmlbody: "<div class='c1 trigger' data-payload='c1' data-action='set' data-type='color'>Color 1 </div> <div class='c2 trigger' data-payload='c2' data-action='set' data-type='color'>Color 2 </div>"
#       apply: "OK, OK!"
#     html= modalTemplate modalContent
#     console.log html
#     this.now.insertInterface(html)
#   return

everyone.now.sendMessage = (heading, message, cssclass="" )->
  html = "<div class='alert fade  #{cssclass} '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>#{heading}</h4>#{message}</div>"
  this.now.insertMessage(html)
  
  
everyone.now.setUserOption = (type, payload) ->
  console.log 'setUserOption', type, payload
  if type = 'color'
    this.user.session.color=payload
    this.user.session.save()
  if this.user.session.auth
    userId = this.user.session.auth.userId
    models.User.findById userId, (err, doc)->
      console.log err if err
      doc.color= payload
      doc.save()
      console.log 'USER COLORCHANGE', doc

models.mongooseAuth.helpExpress(app)

app.listen 3000
