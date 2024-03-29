
models= require './models'
nowjs = require 'now'

powers = require './powers'
# async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

REDIS_EXPIRE_SECS=600

module.exports = (app, SessionModel, redis_client) ->
  everyone = nowjs.initialize app
  # module.everyone = everyone
  bridge = require('./bridge')(everyone, SessionModel, redis_client)

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
              this.now.insertMessage "Sorry, 1 link per minute", "For now. Sorry." , 'alert-error'
              return false

    bridge.processRite cellPoint, content, this.user, this.now, currentWorldId, (commandType, rite=false, cellPoint=false, cellProps=false, originalOwner=false)->
      if rite
        getWhoCanSee cellPoint, currentWorldId, (toUpdate)->
          for i of toUpdate
            # if rite # it was a legit rite  # if i !=cid # ALSO: ie not you, removed for hacky 'rite to server than to screen'
            CUser.byCid(cid)?.addToRiteQueue {x: cellPoint.x, y:cellPoint.y,  world:currentWorldId, rite, commandType, originalOwner}
            nowjs.getClient i, ->
              this.now.drawRite(commandType, rite, cellPoint, cellProps)
    return true


  everyone.now.getTileAve= (absTilePoint, numRows, numCols, callback) ->
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
              pCell = {x: c.x, y: c.y, contents: c.current.contents, props: c.current.props}#holy crap that said c.y instead of c.x
              results["#{c.x}x#{c.y}"] = pCell #pCell is a processed cell
            # console.log "results"
          callback(results, absTilePoint)
        else
          # console.log 'not found'
          callback(results, absTilePoint)

  #utilities for above 
  getWhoCanSee = (cellPoint, worldId, cb ) ->
    nowjs.getGroup(worldId).getUsers (users) ->
      toUpdate = {}
      if worldId
        for i in users
            if CUser.byCid(i)?.bounds?.contains(cellPoint) # added the ? 
              toUpdate[i] = CUser.byCid(i)
      cb(toUpdate)
  
  everyone.now.getCursors = -> #for initial load. pull, don't push. Above is push
    # console.log 'getcursors called'
    cid=this.user.cid
    bounds = CUser.byCid(cid)?.bounds
    nowjs.getGroup(this.now.currentWorldId).getUsers (users) =>
      for i in users
        cursor=CUser.byCid(i).cursor
        if bounds.contains(cursor) and cid isnt i
          update =
            cid: i
            x: cursor.x
            y: cursor.y
            color: CUser.byCid(i).color
          this.now.updateCursors(update)
    return


  everyone.now.getTileCached= (absTilePoint, numRows, callback) ->
    # console.log 'getTileCached'
    # console.log this.now
    if not this.now.currentWorldId
      return false
    worldId= this.now.currentWorldId.toString()
    results = {}
    if this.now.personalWorldId.toString() is worldId #personal world, don't deal with caching
      # console.log 'personal'
      models.Cell.where('world', this.now.currentWorldId).where('x').gte(absTilePoint.x).lt(absTilePoint.x+numRows).where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows).populate('current').run (err,docs) =>
            for c in docs
              if c.current
                pCell = {x: c.x, y: c.y, contents: c.current.contents, props: c.current.props}#holy crap that said c.y instead of c.x
                results["#{c.x}x#{c.y}"] = pCell #pCell is a processed cell
            callback(results, absTilePoint)
    else #normal world
      key="t:#{worldId}:#{numRows}:#{absTilePoint.x}:#{absTilePoint.y}"
      redis_client.exists key, (err, exists) =>
        if exists
          redis_client.hgetall key, (err, obj)->
            # console.log 'hit', key
            for i of obj
              obj[i] = JSON.parse obj[i]
            callback(obj, absTilePoint)
        else
          # console.log 'miss', key
          models.Cell.where('world', this.now.currentWorldId)
            .where('x').gte(absTilePoint.x).lt(absTilePoint.x+numRows)
            .where('y').gte(absTilePoint.y).lt(absTilePoint.y+numRows)
            .populate('current')
            .run (err,docs) =>
              if docs.length
                for c in docs
                  if c.current
                    pCell = {x: c.x, y: c.y, contents: c.current.contents, props: c.current.props}
                    results["#{c.x}x#{c.y}"] = pCell #pCell is a processed cell
                    redis_client.hmset key, "#{c.x}x#{c.y}", JSON.stringify(pCell)
                    redis_client.expire key, REDIS_EXPIRE_SECS
              else
                redis_client.hset key, '0','0'
                redis_client.expire key, 600
              callback(results, absTilePoint)


  everyone.now.getCloseUsers= (cb)->
    if not this.now.currentWorldId
      return false
    closeUsers= []
    cid = this.user.clientId
    aC=CUser.byCid(cid).cursor
    # console.log cUsers[cid]
    nowjs.getGroup(this.now.currentWorldId).getUsers (users) ->
      for i in users
        uC = CUser.byCidLess(i).cursor #less for security reasons
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
    console.log 'setUserOption', type, payload
    # console.log this.user
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
          # this.now.insertMessage('hi', 'nice color')

  everyone.now.createGeoLink = (cellKey, zoom) ->
    b= "#{zoom}x#{cellKey}"
    geoLink64 = new Buffer(b).toString('base64')
    this.now.insertMessage('Have a link:', "<input type='text' value='writtenworld.org/l/#{geoLink64}' class=span4></input>", 'major' )

  everyone.now.getCellInfo = ->
    if not this.now.currentWorldId
      return false
    worldId=this.now.currentWorldId
    cid=this.user.clientId
    cursor=CUser.byCid(cid).cursor
    console.log cursor, worldId
    models.Cell
      .findOne({x:cursor.x, y:cursor.y, world: worldId})
      .populate('current')
      .exec (err, cell) =>
        console.log err if err
        console.log cell
        if cell.current.props.isLocal then waslocalstring= "was local when they wrote it." else waslocalstring= "was not local when they wrote it"
        models.User.findById cell.current.owner, (err, u) =>
          console.log err if err
          console.log u
          if u then name=u.name else name = 'SomeoneWithoutAnAccount'
          this.now.insertMessage("Written by <b>#{name}</b>", " On #{cell.current.date}. #{name} #{waslocalstring} There have been #{cell.history.length} things written here total")

  class CUser
    allByCid = {}
    allBySid = {}
    allByUid = {}
    
    @byCid: (cid)->
      #just get the essentials
      return allByCid[cid]
    
    # sometimes we pass the whole thing to the client, security, bla
    @byCidLess: (cid) ->
      u= allByCid[cid]
      less = {}
      less.cursor= {x:u.cursor.x,y: u.cursor.y}
      less.cid = cid
      less.login= u.login
      return less

    @bySid: (sid) ->
      return allBySid[sid]

    @byUid: (uid) ->
      # console.log 'allbyuid:', allByUid
      return allByUid[uid]

    constructor: (@nowUser) ->
      @cid = @nowUser.clientId
      @sid = decodeURIComponent(@nowUser.cookie['connect.sid'])
      @riteQueue = []
      @cursor = {}
      if nowUser.session?.auth
        @uid= nowUser.session.auth.userId
        models.User.findById @uid, (err, doc) =>
            console.log err if err
            # console.log doc
            # lets keep calling it login on this side. i really should change it, but this will be so much easier TODO
            @login = doc.name # .login
            @nowUser.login = doc.name # .login
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
      if riteQueue.length is 1
        return riteQueue
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
      # console.log 'processEdit'
      # console.log results
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

        if r.originalOwner #and since we're already looping through it
          if (r.originalOwner.toString() not in toNotify[r.commandType]) and r.originalOwner.toString() isnt toNotify.own[0].toString()
            toNotify[r.commandType].push r.originalOwner.toString()

      cellPoints=[]

      for own y, row of fix
        for own x, col of row
          fixed.push col
          cellPoints.push {x:x, y:y}

      fixed.sort (a,b)->
        if a.y == b.y
          return a.x - b.x
        else
          return a.y - b.y
      
      for i in [0..fixed.length-1]
        s+= fixed[i].rite.contents
        if fixed[i+1] and fixed[i+1]?.y isnt fixed[i].y
          s+='<br>'

      if @login
        login=@login
      else
        # login="Anonymous ##{Math.floor(Math.random()*100)}"
        login="SomeoneWithoutAnAccount "

      for type of toNotify
        for uid in toNotify[type]
          note = new models.Note
            x: results[0].x
            y: results[0].y
            contents: s
            read: if type is 'own' then true else false
            from: results[0].rite.owner
            fromLogin: login
            to: uid
            type: type
            world: results[0].world
            cellPoints: cellPoints 

          if type isnt 'own'
            if CUser.byUid(uid)
              nowjs.getClient CUser.byUid(uid).cid, ->
                # console.log s
                this.now.insertMessage noteHeads[type], "<span class='user'>#{login}</span> #{noteBodies[type]}<br>They wrote: <blockquote>#{s}</blockquote><br><a class='btn trigger' data-action='goto' data-payload='#{note.x}x#{note.y}'>Go See</a>" , 'alert-info', 10
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

noteBodies=
    overrite: 'wrote over what you wrote. '
    echo:  'echoed something you wrote. '
    downrote: 'tried to over write what you wrote. '

noteHeads=
    overrite: 'Over Written!'
    echo:  'Echoed'
    downrote:'Attempted Over Write'
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
