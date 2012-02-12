express = require 'express'
nowjs = require 'now'
leaflet = require './leaflet-custom-src.js'

app = express.createServer()

app.configure ->
   app.use express.bodyParser()
   app.use app.router

app.configure 'development', ->
  app.use express.static __dirname+'/public'
  app.use express.errorHandler {dumpExceptions:true, showStack:true}

everyone = nowjs.initialize app

connectedUsers = {}

nowjs.on 'connect', ->
  connectedUsers[this.user.clientId]={}
  console.log this.user.clientID, 'connected'

nowjs.on 'disconnect', ->
  delete connectedUsers[this.user.clientId]
  console.log 'removing disconnected user'

everyone.now.setBounds = (bounds) ->
  b = new leaflet.L.Bounds bounds.max, bounds.min
  console.log 'bounds are', b

everyone.now.setSelected = (cellPoint) ->
  console.log 'setselected'
  connectedUsers[this.user.clientId].selected = cellPoint
  for i of  connectedUsers
    console.log i, 'iii'


app.listen 3000
