
models= require './models'
nowjs = require 'now'

powers = require './powers'
# async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

module.exports = (app, SessionModel) ->
  everyone = nowjs.initialize app
  # module.everyone = everyone
  bridge = require('./bridge')(everyone, SessionModel)

  everyone.now.setGroup = (currentWorldId) ->
    if currentWorldId
      group = nowjs.getGroup(currentWorldId).addUser(this.user.clientId)
      return
    else
      return false

  nowjs.on 'connect', ->
    this.user.cid = this.user.clientId
    u= new CUser(this.user)
    return

  nowjs.on 'disconnect', ->
    cid = this.user.clientId
    u=CUser.byCid(cid)
    update =
      cid: cid
    getWhoCanSee u.cursor, this.now.currentWorldId, (toUpdate)->
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
    if not this.now.currentWorldId
      return false
    cid = this.user.clientId
    CUser.byCid(cid).cursor = cellPoint
    update =
      cid: cid
      x: cellPoint.x
      y: cellPoint.y
      color: this.user.session.color if this.user.session

    getWhoCanSee cellPoint, this.now.currentWorldId, (toUpdate)->
      for i of toUpdate
        if i != cid #not you
          nowjs.getClient i, ->
            this.now.updateCursors(update)

  everyone.now.writeCell = (cellPoint, content) ->
    if not this.now.currentWorldId
      return false
    currentWorldId = this.now.currentWorldId
    cid = this.user.clientId

    if typeof content isnt 'string'
      for k, v of content
        if k is 'linkurl'
           process.nextTick =>
              models.User.findById CUser.byCid(this.user.cid).uid, (err, doc) =>
                doc.powers.lastLinkOn = new Date
                doc.save()
                this.user.powers.lastLinkOn= new Date
                return
          if not powers.canLink this.user
              this.now.insertMessage "Sorry, 1 Link/Hour", "For now. Sorry." , 'alert-error'
              return false 

    bridge.processRite cellPoint, content, this.user, this.now, currentWorldId, (commandType, rite=false, cellPoint=false, cellProps=false, originalOwner=false)->
      # console.log "CALL BACK! #{commandType} - #{rite} #{cellPoint}"
      getWhoCanSee cellPoint, currentWorldId, (toUpdate)->
        for i of toUpdate
          # if i !=cid # ie not you, removed for my hack 
            if rite # it was a legit rite
              CUser.byCid(cid).addToRiteQueue {x: cellPoint.x, y:cellPoint.y,  world:currentWorldId, rite, commandType, originalOwner}
              nowjs.getClient i, ->
                # console.log i
                this.now.drawRite(commandType, rite, cellPoint, cellProps)
    return true


  everyone.now.getZoomedOutTile= (absTilePoint, numRows, numCols, callback) ->
    if not this.now.currentWorldId
      return false
    models.Cell.where('world', this.now.currentWorldId)
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
    # console.log 'getTile'
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
            # console.log "results"
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
    if not this.now.currentWorldId
      return false
    console.log 'getCloseUsers called'
    closeUsers= []
    cid = this.user.clientId
    aC=CUser.byCid(cid).cursor
    # console.log cUsers[cid]
    # console.log 'ac', aC
    nowjs.getGroup(this.now.currentWorldId).getUsers (users) ->
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

  everyone.now.setServerState = (type, payload) ->
    # console.log 'setUserOption', type, payload
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

  everyone.now.createGeoLink = (cellKey, zoom) ->
    # console.log geoLink
    # b="#{geoLink.lat}:#{geoLink.lng}"
    b= "#{zoom}x#{cellKey}"
    geoLink64 = new Buffer(b).toString('base64')
    this.now.insertMessage('Have a link:', "<a href='/l/#{geoLink64}'>/l/#{geoLink64}</a>")

  # not for initial load, for notifications and such
  # everyone.now.goToGeoLink = (geoLink64) ->
  #   # console.log 'goto GEO'
  #   b=new Buffer(geoLink64, 'base64').toString('ascii')
  #   g= b.split(':')
  #   console.log g
  #   latlng = {x: g[0], y: g[1]}
  #   console.log latlng
    # this.now.mapGoTo(latlng)

  # or with my CUser, and by edit, not rite
  # can I impliment this on CUser  instead....
  # models.User.prototype.on 'receivedEcho', (rite) ->
  #     console.log 'rcvd echo called'
  #     userId= this._id
  #     rite.getOwner (err,u)->
  #       console.log err if err
  #       cid = CUser.byUid(userId)?.cid
  #       if cid
  #         nowjs.getClient cid, ->
  #           if u
  #             this.now.insertMessage 'Echoed!', "#{u.login} echoed what you said!"
  #           else
  #             this.now.insertMessage 'Echoed!', "Someone echoed what you said!"
  #     return true

  # models.User.prototype.on 'receivedOverRite', (rite) ->
  #     console.log 'rcd ovrt called'
  #     userId= this._id
  #     rite.getOwner (err,u)->
  #       console.log err if err
  #       cid=CUser.byUid(userId)?.cid
  #       if cid
  #         nowjs.getClient cid, ->
  #           if u
  #             this.now.insertMessage 'Over Written', "#{u.login} is writing over your cells"
  #           else
  #             this.now.insertMessage 'Over Written', "Someone is writing over your cells."
  #     return true


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
      return allBySid[sid]

    @byUid: (uid) ->
      # console.log 'allbyuid:', allByUid
      return allByUid[uid]

    constructor: (@nowUser) ->
      @cid = @nowUser.clientId
      @sid = decodeURIComponent(@nowUser.cookie['connect.sid'])
      @riteQueue = []
      if nowUser.session?.auth
        @uid= nowUser.session.auth.userId
        models.User.findById @uid, (err, doc) =>
            @login = doc.login
            @nowUser.login = doc.login
            @nowUser.powers = doc.powers
        allByUid[@uid] = this
      else
        # this is neccesary because sids don't presist, but the doc._id should
        SessionModel.findOne {'sid': @sid } , (err, doc) =>
          @uid = doc._id
          @nowUser.soid=doc._id
          allByUid[@uid] = this
      
      allByCid[@cid] = this
      allBySid[@sid] = this
      

    findEdits: (riteQueue) ->
      results=[]
      riteQueue.sort (a,b)->
        if a.y == b.y
          if a.x==b.x
            return a.rite.date - b.rite.date
          else
            return a.x - b.x
        else
          return a.y - b.y

      for i in [0..riteQueue.length-1]
        if riteQueue[i].y == riteQueue[i+1]?.y
          results.push riteQueue[i]
        else if riteQueue[i].y == riteQueue[i-1]?.y #for the last el
          results.push riteQueue[i]
      return results

    addToRiteQueue: (edit) ->
      @riteQueue.push edit
      clearTimeout(@timerId)
      @timerId= delay 1000*5, =>
        results=@findEdits(@riteQueue)
        @riteQueue=[]
        @processEdit results
        return false
    

    processEdit:(results) ->
      console.log 'processEdit'
      s = ''
      toNotify =
        own: [results[0].rite.owner]
        overrite: []
        echo: []
        downrote:[]
      fix = {}
      fixed=[]
      #to get the final state of the edit/each contained cell, i.e. if user made a mistake
      for r in results
        if not fix[r.y] then fix[r.y]={}
        fix[r.y][r.x] =r
        #and since we're already looping through it
        if r.originalOwner
          if r.originalOwner.toString() not in toNotify[r.commandType]
            toNotify[r.commandType].push r.originalOwner.toString()

      for own y, row of fix
        for own x, col of row
          fixed.push col

      fixed.sort (a,b)->
        if a.y == b.y
          return a.x - b.x
        else
          return a.y - b.y
      
      for r in fixed
        s+= r.rite.contents
      # console.log s
      # console.log 'notes: ', toNotify

      for type of toNotify
        for uid in toNotify[type]
          note = new models.Note
            x: results[0].x
            y: results[0].y
            contents: s
            read: if type is 'own' then true else false
            from: results[0].rite.owner
            to: uid
            type: type
          if type isnt 'own'
            if CUser.byUid(uid)
              nowjs.getClient CUser.byUid(uid).cid, ->
                this.now.insertMessage '!!!!', "Someone ____ you!<br><span class='edit'>#{s}</span>"
                note.read = true
          note.save()

      return

    destroy: ->
      delete allByCid[@cid]
      delete allBySid[@sid]
      delete allByUid[@uid]
      delete @nowUser
      # console.log this
      # delete this

  return [everyone, CUser]
# 
# defaultUserPowers= ->
#   powers =
#     jumpDistance:50
    

#this is just a reminder of whats in the model
# defaultRegisteredPowers = ->
#   powers=
#     jumpDistance: 500

delay = (ms, func) -> setTimeout func, ms

Array::filter = (func) -> x for x in @ when func(x)
