
models= require './models'
nowjs = require 'now'

# async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

module.exports = (app, SessionModel) ->
  everyone = nowjs.initialize app
  
  bridge = require('./bridge')(everyone, SessionModel)

  everyone.now.setCurrentWorld = (currentWorldId) ->
    if currentWorldId
      group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId)
      this.now.currentWorldId = currentWorldId
    else
      this.now.currentWorldId = false

  # These are problematic, but we never iterate through them, just look ups
  cUsers = {} #all of the connected users, by clientId (nowjs)
  aUsers = {} #all connected and auth'd users, by actual userId (mongoose _id)
  # should use redis for these. maybe?

  nowjs.on 'connect', ->
    nowUser = this.user
    # u= new CUser(nowUser)
    sid=decodeURIComponent(this.user.cookie['connect.sid'])
    cid = this.user.clientId

    # z=CUser.byCid(this.user.clientId)
    if this.user.session?.auth
      userId = this.user.session.auth.userId
      cUsers[cid]={sid:sid, userId: userId, login: this.user.login }
      aUsers[userId]={sid:sid,cid: cid}
       
      models.User.findById userId, (err, doc) ->
        cUsers[cid]={sid:sid, userId: userId, login: doc.login }
        aUsers[userId]={sid:sid,cid: cid, login: doc.login}
        nowUser.login = doc.login
    else
      cUsers[cid]={sid:sid}
      SessionModel.findOne {'sid': sid } , (err, doc) =>
        data = JSON.parse(doc.data)
        cUsers[cid]={sid:sid, userId: doc._id}
        this.user.soid=doc._id
    true

  nowjs.on 'disconnect', ->
    console.log 'disconenect -----------------'
    delete cUsers[this.user.clientId]
    if this.user.session?.auth
      delete aUsers[this.user.session.auth.userId]
      console.log 'removing authd disconnected user'
    console.log 'removing disconnected user'

  everyone.now.setBounds = (bounds) ->
    b = new leaflet.L.Bounds bounds.max, bounds.min
    cUsers[this.user.clientId].bounds = b

  everyone.now.setClientStateFromServer = (callback) ->
    if this.user.session
      callback(this.user.session)

  everyone.now.setSelectedCell = (cellPoint) ->
    if not this.now.currentWorldId
      return false
    cid = this.user.clientId
    cUsers[cid].selected = cellPoint
    user = this.user
    getWhoCanSee cellPoint, this.now.currentWorldId, (toUpdate)->
      for i of toUpdate
        if i != cid #not you
          update = cUsers[cid]
          update.color = user.session.color if user.session
          update.cid = cid
          nowjs.getClient i, -> this.now.drawCursors(update)

  everyone.now.writeCell = (cellPoint, content) ->
    if not this.now.currentWorldId
      return false
    currentWorldId = this.now.currentWorldId
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

  everyone.now.getTile= (absTilePoint, numRows, callback) ->
    if not this.now.currentWorldId
      return false
    models.Cell.where('world', this.now.currentWorldId)
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
      # console.log 'worldId', worldId # console.log 'cellPoint', cellPoint
      if worldId
        for i in users
            # console.log '   bounds',  cUsers[i].bounds
            if cUsers[i]?.bounds?.contains(cellPoint) # added the ? 
              toUpdate[i] = cUsers[i]
      cb(toUpdate)

  everyone.now.getCloseUsers= (cb)->
    if not this.now.currentWorldId
      return false
    console.log 'getCloseUsers called'
    # console.log this.user
    closeUsers= []
    cid = this.user.clientId
    aC=cUsers[cid].selected
    # console.log cUsers[cid]
    # console.log 'ac', aC
    nowjs.getGroup(this.now.currentWorldId).getUsers (users) ->
      for i in users
        uC = cUsers[i].selected
        distance = Math.sqrt((aC.x-uC.x)*(aC.x-uC.x)+(aC.y-uC.y)*(aC.y-uC.y))
        # console.log "i: #{i}"
        # console.log "cid: #{cid}"
        console.log distance
        if distance < 1000 and (i isnt cid)
          u = {}
          u[key] = value for own key,value of cUsers[i]
          u.distance = distance
          if cUsers[i].login
            u.login= cUsers[i].login
          closeUsers.push(u)
      cb(closeUsers)
    true


  everyone.now.submitFeedback = (f, t) ->
    this.now.insertMessage 'Thanks', 'We appreciate your feedback'
    feedback = new models.Feedback({contents: f, t:t})
    feedback.save (err) -> console.log err if err

  everyone.now.setUserOption = (type, payload) ->
    console.log 'setUserOption', type, payload
    if type = 'color'
      cid=this.user.clientId
      cUsers[cid].color= payload
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



  class CUser
    allByCid = {}
    allBySid = {}
    allByUid = {}
    
    @byCid: (cid)->
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
      else
        SessionModel.findOne {'sid': @sid } , (err, doc) =>
          @uid = doc._id
          @nowUser.soid=doc._id
      
      allByCid[@cid] = this
      allBySid[@sid] = this
      allByUid[@uid] = this
      
      # console.log allByCid
    destructor: ->
      delete allByCid[@cid]
      delete allBySid[@sid]
      delete allByUid[@uid]
      delete @nowUser
      # delete this

  exports.CUser = CUser



  return true 
  # return everyone
