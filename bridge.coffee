models= require './models'
nowjs = require 'now'

async = require './lib/async.js'
leaflet = require './lib/leaflet-custom-src.js'

# otherWorlds = require './otherworlds'
redis={}

module.exports = (everyone, SessionModel, redis_client) ->
  redis=redis_client

  processRite = (cellPoint, contents, nowUser, nowThis, currentWorldId, callback) ->
    cid = nowUser.clientId
    sid= decodeURIComponent nowUser.cookie['connect.sid']
    color= nowUser.session?.color

    if typeof contents isnt 'string'
      extras=contents
      contents= extras.contents
      delete extras.contents
  
    # If user has an account and is logged in
    if nowUser.session.auth
      personalWorld = models.ObjectIdFromString(nowThis.personalWorldId)
      riter=nowUser.session.auth.userId
      rite = new models.Rite({contents: contents, owner:riter, props:{echoers:[], isLocal: nowThis.isLocal, echoes:-1, downroters:[], color: color}})
      if extras
        for k,v of extras
          rite.props[k]=v

      models.Cell .findOne({world: personalWorld, x:cellPoint.x, y: cellPoint.y}) .populate('current')
      .run (err, cell) ->
          console.log err if err
          cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world:personalWorld} if not cell
          cell.history.push(rite)
          rite.save (err) ->
            cell.current= rite._id
            cell.save()
      if nowThis.personalWorldId.toString() is currentWorldId  #check if they're already in their own world (heh)
        # console.log 'was actually writing directly to yr world, so skip the echo behavior below'
        callback('normalRite', rite, cellPoint)
        return
    # Not logged in
    else
      riter = nowUser.soid #session object id

    models.Cell
    .findOne({world: currentWorldId, x:cellPoint.x, y: cellPoint.y})
    .populate('current')
    .run (err, cell) ->
        console.log err if err

        if not cell or not cell.current
          # console.log 'no cell or blank cell'
          cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world:currentWorldId}
          already= {echoer: false, downroter: false, downPos:-1, echoPos: -1}

        if cell and cell.current
          already = determineStatus(cell, riter)
       
        logic=
          blankCurrently : not cell?.current or cell?.current?.contents == models.mainWorld.config.defaultChar #TODO make this a config
          blankRite: contents == models.mainWorld.config.defaultChar
          potentialEcho : cell?.current?.contents == contents
          cEchoes : cell?.current?.props?.echoes
          riteToHistory: true #flag
          already: already

        logic.legitEcho = logic.potentialEcho and not already.echoer
        logic.legitDownrote= not logic.blankCurrently and not logic.potentialEcho and not already.downroter
        originalOwner = cell.current?.owner

        # debug = ' '
        # for k, v of logic
        #  debug+="#{k} : #{v}  .  "
        
        rite = new models.Rite({contents: contents, owner:riter, props:{isLocal:nowThis.isLocal, echoers:[], echoes:-1, downroters:[], color: color}})
        if extras
          for k,v of extras
            rite.props[k]=v
        # console.log debug

        if logic.blankCurrently
          # console.log 'Blank, just write'
          normalRite(cell, rite, riter, logic)
          callback('normalRite', rite, cellPoint)
        else if logic.potentialEcho and logic.already.echoer
          # console.log 'Echoing yourself too much will make you go blind'
          logic.riteToHistory=false
          callback('alreadyEchoed')
        else if logic.already.downroter and not logic.potentialEcho
          # console.log 'You cannot downrote again '
          logic.riteToHistory=false
          callback('alreadyDownroted')
        else if logic.legitEcho
            # console.log 'Legit echo, cool'
            echoIt(cell, rite, riter, logic)
            callback('echo', rite, cellPoint, cell.current.props, originalOwner)
        else if logic.cEchoes<=0
            # console.log 'Legit overrite, there were no echoes'
            overriteIt(cell, rite, riter, logic) # this changes c.current to the rite
            callback('overrite', rite, cellPoint, cell.current.props, originalOwner)
        else if logic.cEchoes>=1
            if not logic.already.echoer
              # console.log 'Legit Downrote'
              downroteIt(cell, rite, riter, logic)
              callback('downrote', rite, cellPoint, cell.current.props, originalOwner)
            else if logic.already.echoer
              if logic.cEchoes ==1
                # console.log 'Overrite something you echoed!'
                overriteIt(cell, rite, riter, logic)
                callback('overrite', rite, cellPoint, cell.current.props, originalOwner)
              else
                # console.log 'Downroting something you echoed!'
                downroteIt(cell, rite, riter, logic)
                callback('downrote', rite, cellPoint, cell.current.props, originalOwner)
        else
          console.log 'WELL SHIT THIS SHOULDNT HAVE HAPPENED'
        
        if logic.riteToHistory
          cell.history.push(rite)
          cell.save()
          models.User.findById riter, (err, user)->
            if user
              user.totalRites+=1
              user.save (err) -> console.log err if err

        if originalOwner and  (logic.legitEcho or logic.legitDownrote)
          models.User.findById originalOwner, (err, user) ->
            if user and logic.legitEcho
              user.totalEchoes+=1
              user.save (err)-> console.log err if err

  # END processRite


  # Externally Accessible
  module.processRite = processRite
  
  return module


# Helpers for processRite
determineStatus = (cell, riter) ->
  isAlreadyEchoer=false; isAlreadyDownroter = false; i=-1; alreadyDownPos= -1; alreadyEchoPos=-1; 
    #hacktastic, because indexof doesn't work with mongoose objectIds
  if cell?.current?.props.echoers
    for e in cell?.current?.props.echoers
      i+=1
      if e.toString()==riter.toString()
        isAlreadyEchoer = true
        alreadyEchoPos= i
  if cell?.current?.props.downroters
    for d in cell?.current?.props.downroters
      i+=1
      if d.toString()==riter.toString()
        isAlreadyDownroter = true
        alreadyDownPos=i
  return {echoer: isAlreadyEchoer, downroter: isAlreadyDownroter, echoPos:alreadyEchoPos, downPos: alreadyDownPos}

normalRite = (cell, rite, riter, logic) ->
  rite.props.echoes+=1
  rite.props.echoers.push(riter)
  writeToRedis(cell, rite)
  rite.save (err) ->
    cell.current= rite._id
    cell.save()
  
echoIt = (cell, rite, riter, logic) ->
  cell.current.props.echoes+=1
  writeToRedis(cell)
  cell.current.props.echoers.push(riter)
  if logic.already.downroter
    cell.current.props.downroters.splice(logic.already.downPos, 1)
  rite.save()
  cell.current.markModified('props')
  cell.current.save (err) -> console.log err if err
  return

downroteIt = (cell, rite, riter, logic) ->
  cell.current.props.echoes-=1
  cell.current.props.downroters.push(riter)
  if logic.already.echoer
    cell.current.props.echoers.splice(logic.already.echoPos, 1)
  writeToRedis(cell)
  rite.save()
  cell.current.markModified('props')
  cell.current.save (err) -> console.log err if err
  return

overriteIt = (cell, rite, riter, logic) ->
  rite.props.echoes+=1
  rite.props.echoers.push(riter)
  writeToRedis(cell, rite)
  rite.save (err) ->
    cell.current = rite._id
    cell.save (err) -> console.log err if err
  return


writeToRedis = (cell, rite=false)->
    # console.log 'WRITE TO REDIS'
    # console.log cell
    if rite
      # console.log 'rite', rite
      contents= rite.contents
      props= rite.props
    else
      contents = cell.current.contents
      props= cell.current.props

    cellPoint=cell
    currentWorldId= cell.world.toString()
    numRC=16
    tilePoint = {x:Math.floor(cellPoint.x/numRC)*numRC, y: Math.floor(cellPoint.y/numRC)*numRC}
    key="t:#{currentWorldId}:#{numRC}:#{tilePoint.x}:#{tilePoint.y}"
    numRC=8
    tilePoint2 = {x:Math.floor(cellPoint.x/numRC)*numRC, y: Math.floor(cellPoint.y/numRC)*numRC}
    key2="t:#{currentWorldId}:#{numRC}:#{tilePoint2.x}:#{tilePoint2.y}"
    #this is dumb, but neccesary for now if i want to cache whole tiles, until i think of a better way
    pCell = {x: cellPoint.x, y: cellPoint.y, contents: contents, props: props}
    # console.log key2
    # console.log pCell
    ppCell= JSON.stringify(pCell)
    redis.hmset key, "#{cellPoint.x}x#{cellPoint.y}", ppCell
    redis.hmset key2, "#{cellPoint.x}x#{cellPoint.y}", ppCell
    redis.expire key, 600
    redis.expire key2, 600

# Utility 
Array::filter = (func) -> x for x in @ when func(x)
