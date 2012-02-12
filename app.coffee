express = require 'express'
nowjs = require 'now'
leaflet = require './leaflet-custom-src.js'

app = express.createServer()

app.configure ->
   app.use express.bodyParser()
   app.use app.router

app.configure 'development', ->
  app.use express.static __dirname+'/public'
  app.use express.logger({ format: ':method :url' })
  app.use express.errorHandler {dumpExceptions:true, showStack:true}

everyone = nowjs.initialize app

connectedUsers = {}

nowjs.on 'connect', ->
  connectedUsers[this.user.clientId]={}
  console.log this.user.clientId, 'connected'

nowjs.on 'disconnect', ->
  delete connectedUsers[this.user.clientId]
  console.log 'removing disconnected user'

everyone.now.setBounds = (bounds) ->
  b = new leaflet.L.Bounds bounds.max, bounds.min
  # console.log b
  connectedUsers[this.user.clientId].bounds = b
  
everyone.now.setSelected = (cellPoint) ->
  cid = this.user.clientId
  toUpdate = {}
  connectedUsers[cid].selected = cellPoint
  for i of connectedUsers
    if connectedUsers[i].bounds.contains(cellPoint)
      if i != cid
        toUpdate[i] = connectedUsers[i]
  
  for i of toUpdate
    updates = {cid:connectedUsers[cid]}
    nowjs.getClient i, -> this.now.drawCursors(updates)


app.listen 3000
