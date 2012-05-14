
models= require './models'
nowjs = require 'now'

# async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

module.exports = (app, SessionModel) ->
  everyone = nowjs.initialize app
  # module.everyone = everyone
  bridge = require('./bridge')(everyone, SessionModel)

  everyone.now.setCurrentWorld = (currentWorldId, personalWorldId) ->
    this.user.personalWorldId = personalWorldId
    if currentWorldId
      group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId)
      this.user.currentWorldId=currentWorldId
    else
      this.user.currentWorldId=false

    # if currentWorldId != models.mainWorldId.toString() and currentWorldId != personalWorldId
    #   console.log 'NOT MAIN, NOT PERSONAL'
    #   this.user.specialWorld = true
    #   models.World.findById currentWorldId, (err, world) =>
    #     this.user.specialWorldName= world.name

  nowjs.on 'connect', ->
    this.user.cid = this.user.clientId
    u= new CUser(this.user)
    return

  nowjs.on 'disconnect', ->
    cid = this.user.clientId
    u=CUser.byCid(cid)
    update =
      cid: cid
    getWhoCanSee u.cursor, this.user.currentWorldId, (toUpdate)->
      for i of toUpdate
          nowjs.getClient i, ->
            this.now.updateCursors(update)
    u.destroy()
    return

  everyone.now.setBounds = (bounds) ->
    if not bounds
      return false
    b = new leaflet.L.Bounds bounds.max, bounds.min
    CUser.byCid(this.user.cid).bounds=b

  everyone.now.setClientStateFromServer = (callback) ->
    if this.user.session
      callback(this.user.session)

  everyone.now.setCursor = (cellPoint) ->
    if not this.user.currentWorldId
      return false
    cid = this.user.clientId
    CUser.byCid(cid).cursor = cellPoint
    update =
      cid: cid
      x: cellPoint.x
      y: cellPoint.y
      color: this.user.session.color if this.user.session

    getWhoCanSee cellPoint, this.user.currentWorldId, (toUpdate)->
      for i of toUpdate
        if i != cid #not you
          nowjs.getClient i, ->
            this.now.updateCursors(update)

  everyone.now.writeCell = (cellPoint, content) ->
    if not this.user.currentWorldId
      return false
    currentWorldId = this.user.currentWorldId
    cid = this.user.clientId

    bridge.processRite cellPoint, content, this.user, currentWorldId, (commandType, rite=false, cellPoint=false, cellProps=false)->
      # console.log "CALL BACK! #{commandType} - #{rite} #{cellPoint}"
      getWhoCanSee cellPoint, currentWorldId, (toUpdate)->
        for i of toUpdate
          # if i !=cid # ie not you, removed for my hack 
            if rite # it was a legit rite
              nowjs.getClient i, ->
                this.now.drawRite(commandType, rite, cellPoint, cellProps)
    return true


  everyone.now.getZoomedOutTile= (absTilePoint, numRows, numCols, callback) ->
    if not this.user.currentWorldId
      return false
    models.Cell.where('world', this.user.currentWorldId)
      .where('x').gte(absTilePoint.x).lt(absTilePoint.x+numCols)
      .where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows)
      .count (err,count) =>
        if count
          density= count/(numRows*numCols)
          results= {density: density}
        else
          results= {density: 0}
        callback(results, absTilePoint)

  everyone.now.getTile= (absTilePoint, numRows, callback) ->
    if not this.user.currentWorldId
      return false
    models.Cell.where('world', this.user.currentWorldId)
      .where('x').gte(absTilePoint.x).lt(absTilePoint.x+numRows)
      .where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows)
      .populate('current')
      .run (err,docs) =>
        results = {}
        if docs.length
          for c in docs
            if c.current
              pCell = {x: c.y, y: c.y, contents: c.current.contents, props: c.current.props}
              results["#{c.x}x#{c.y}"] = pCell #pCell is a processed cell
            # console.log results
          callback(results, absTilePoint)
        else
          # console.log 'not found'
          callback(results, absTilePoint)

  #utility for above 
  getWhoCanSee = (cellPoint, worldId, cb ) ->
    nowjs.getGroup(worldId).getUsers (users) ->
      toUpdate = {}
      if worldId
        for i in users
            if CUser.byCid(i)?.bounds?.contains(cellPoint) # added the ? 
              toUpdate[i] = CUser.byCid(i)
      cb(toUpdate)

  everyone.now.getCloseUsers= (cb)->
    if not this.user.currentWorldId
      return false
    console.log 'getCloseUsers called'
    closeUsers= []
    cid = this.user.clientId
    aC=CUser.byCid(cid).cursor
    # console.log cUsers[cid]
    # console.log 'ac', aC
    nowjs.getGroup(this.user.currentWorldId).getUsers (users) ->
      for i in users
        uC = CUser.byCid(i).cursor
        distance = Math.sqrt((aC.x-uC.x)*(aC.x-uC.x)+(aC.y-uC.y)*(aC.y-uC.y))
        if distance < 1000 and (i isnt cid)
          u = {}
          u[key] = value for own key,value of CUser.byCid(i)
          u.distance = distance
          # if cUsers[i].login
            # u.login= cUsers[i].login
          closeUsers.push(u)
      cb(closeUsers)
    true


  everyone.now.submitFeedback = (f, t) ->
    this.now.insertMessage 'Thanks', 'We appreciate your feedback'
    feedback = new models.Feedback({contents: f, t:t})
    feedback.save (err) -> console.log err if err

  everyone.now.setUserOption = (type, payload) ->
    console.log 'setUserOption', type, payload
    if type == 'color'
      cid=this.user.clientId
      CUser.byCid(cid).color= payload
      this.user.session.color=payload
      this.user.session.save()
      if this.user.session.auth
        userId = this.user.session.auth.userId
        models.User.findById userId, (err, doc)=>
          console.log err if err
          doc.color= payload
          doc.save()
          # console.log 'USER COLORCHANGE', doc
          this.now.insertMessage('hi', 'nice color')

  # can I impliment this on CUser  instead....
  models.User.prototype.on 'receivedEcho', (rite) ->
      console.log 'rcvd echo called'
      userId= this._id
      rite.getOwner (err,u)->
        console.log err if err
        cid = CUser.byUid(userId)?.cid
        if cid
          nowjs.getClient cid, ->
            if u
              this.now.insertMessage 'Echoed!', "#{u.login} echoed what you said!"
            else
              this.now.insertMessage 'Echoed!', "Someone echoed what you said!"
      return true

  models.User.prototype.on 'receivedOverRite', (rite) ->
      console.log 'rcd ovrt called'
      userId= this._id
      rite.getOwner (err,u)->
        console.log err if err
        cid=CUser.byUid(userId)?.cid
        if cid
          nowjs.getClient cid, ->
            if u
              this.now.insertMessage 'Over Written', "#{u.login} is writing over your cells"
            else
              this.now.insertMessage 'Over Written', "Someone is writing over your cells."
      return true


  class CUser
    allByCid = {}
    allBySid = {}
    allByUid = {}
    
    @byCid: (cid)->
      return allByCid[cid]
    
    # sometimes we pass the whole thing to the client, security, bla
    @byCidFull: (cid) ->
      return allByCid[cid]
    
    @bySid: (sid) ->
      return allBy[sid]

    @byUid: (uid) ->
      return allByUid[uid]

    constructor: (@nowUser) ->
      @cid = @nowUser.clientId
      @sid = decodeURIComponent(@nowUser.cookie['connect.sid'])
      if nowUser.session?.auth
        @uid= nowUser.session.auth.userId
        models.User.findById @uid, (err, doc) =>
            @login = doc.login
            @nowUser.login = doc.login
            @nowUser.powers = doc.powers
            @nowUser.session?.powers = doc.powers
      else
        SessionModel.findOne {'sid': @sid } , (err, doc) =>
          @uid = doc._id
          @nowUser.soid=doc._id
          @nowUser.powers = defaultUserPowers()
          @nowUser.session?.powers = defaultUserPowers()
      
      allByCid[@cid] = this
      allBySid[@sid] = this
      allByUid[@uid] = this
      

    destroy: ->
      delete allByCid[@cid]
      delete allBySid[@sid]
      delete allByUid[@uid]
      delete @nowUser
      # console.log this
      # delete this

  exports.CUser = CUser

  # return true
  return everyone

defaultUserPowers= ->
  powers =
    jumpDistance:50
    

#this is just a reminder of whats in the model
# defaultRegisteredPowers = ->
#   powers=
#     jumpDistance: 500
