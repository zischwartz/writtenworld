express = require 'express'
nowjs = require 'now'
leaflet = require './leaflet-custom-src.js'
mongoose = require 'mongoose'
connect = require('connect')
mongoose.connect('mongodb://localhost/mapist')

sessionStore = require("connect-mongoose")(connect)

app = express.createServer()

app.configure ->
   app.use express.bodyParser()
   app.use express.cookieParser()
   app.use express.session {secret: 'tshh secret', store : new sessionStore()}
   app.use app.router

app.configure 'development', ->
  app.use express.static __dirname+'/public'
  app.use express.logger({ format: ':method :url' })
  app.use express.errorHandler {dumpExceptions:true, showStack:true}


everyone = nowjs.initialize app

config = {maxZoom: 18}

cUsers = {} #all of the connected users

nowjs.on 'connect', ->
  sid=this.user.cookie['connect.sid']
  cUsers[this.user.clientId]={}
  console.log this.user.clientId, 'connected'
  console.log sid
  console.log 'this.user.session \n', this.user.session
  # this.user.session.name = 'zach'
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
  cid = this.user.clientId
  toUpdate = getWhoCanSee(cellPoint)
  console.log cellPoint, content
  edits = {}
  writeCellToDb(cellPoint, content)
  for i of toUpdate
    if i !=cid
      edits[cid] = {cellPoint: cellPoint, content: content}
      nowjs.getClient i, -> this.now.drawEdits(edits)
  true

everyone.now.getTile= (absTilePoint, numRows, callback) ->
  # sid=this.user.cookie['connect.sid']
  # console.log sid
  CellModel.where('world', mainWorldId)
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


Schema = mongoose.Schema
ObjectId = Schema.ObjectId

mainWorldId = mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001")

WorldSchema = new Schema
  owner: ObjectId
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true}

WorldModel = mongoose.model('World', WorldSchema)

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  contents: {type: String, default: ' '}
  properties: {}

CellSchema.index {world:1, x:1, y:1}, {unique:true}

CellModel = mongoose.model('Cell', CellSchema)

writeCellToDb = (cellPoint, contents) ->
  CellModel.findOne {world: mainWorldId, x:cellPoint.x, y: cellPoint.y}, (err, cell) ->
    if not cell
      cell = new CellModel {x:cellPoint.x, y:cellPoint.y, contents: contents, world: mainWorldId}
      cell.save (err) -> console.log err if err
      console.log 'created  cell!!', cell.x, cell.y
    else
      cell.contents = contents
      cell.save (err) -> console.log err if err
      console.log 'updated cell', cell.x, cell.y

getCellFromDb = (cellPoint) ->
  cellModel.findOne {world: mainWorldId, x:cellPoint.x, y: cellPoint.y}, (err, cell) ->
    console.log 'found', cell

# instance = new WorldModel({personal: false, name:'world'})
# instance.save() # instance.save (err) -> console.log err 
# mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001")
     
# cell = new CellModel {x:1, y:1, world: mongoose.Types.ObjectId.fromString("4f394bd7f4748fd7b3000001")}
# cell.save()
# console.log 'cell', cell

# WorldModel.findOne {name: 'main'}, (err,doc) ->
  # console.log doc

app.listen 3000
