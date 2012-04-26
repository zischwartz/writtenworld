models= require './models'
nowjs = require 'now'

async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

module.exports = (everyone, SessionModel) ->

  processRite = (cellPoint, contents, nowUser, currentWorldId, callback) ->
    # nowUser is this.user within  everyone.now
    # console.log 'processRite Called !!!!!', nowUser

    cid = nowUser.clientId
    sid= decodeURIComponent nowUser.cookie['connect.sid']
    
    color= nowUser.session?.color
    console.log 'color', color

    # If user has an account and is logged in
    if nowUser.session.auth
      riter=nowUser.session.auth.userId
      models.User.findById riter, (err, user) ->
        if user.personalWorld.toString() isnt currentWorldId  #check if they're already in their own world (heh)
          console.log 'write to their world' #write to personal world here
    else # Not logged in
      riter = nowUser.soid #session object id

    models.Cell
    .findOne({world: currentWorldId, x:cellPoint.x, y: cellPoint.y})
    .populate('current')
    .run (err, cell) ->
        console.log err if err

        if not cell or not cell.current
          console.log 'no cell or blank cell'
          cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world:currentWorldId}
          [already, alreadyPos] = [false, -1]

        if cell and cell.current
          console.log 'cell found w/ current'
          console.log determineStatus(cell, riter)
          [already, alreadyPos] = determineStatus(cell, riter)
        
        logic=
          blankCurrently : not cell?.current or cell?.current?.contents == models.mainWorld.meta.defaultChar #TODO make this a config
          blankRite: contents == models.mainWorld.meta.defaultChar
          potentialEcho : cell?.current?.contents == contents
          cEchoes : cell?.current?.props?.echoes
          already: already #echoer or downroter --string
          alreadyPos: alreadyPos
          riteToHistory: true #flag

        logic.legitEcho = already != 'echoer' and logic.potentialEcho
        logic.legitDownrote= not logic.blankCurrently and not logic.potentialEcho and already != 'downroter'
        # for k, v of logic
        #  console.log "#{k} : #{v}"
        # console.log ' '
        
        rite = new models.Rite({contents: contents, owner:riter, props:{echoers:[], echoes:-1, downroters:[], color: color}})

        if logic.blankCurrently
          console.log 'Blank, just write'
          normalRite(cell, rite, riter, logic)
          callback('normalRite', rite, cellPoint)
        else if logic.potentialEcho and logic.already == 'echoer'
          logic.riteToHistory=false
          console.log 'Echoing yourself too much will make you go blind'
          callback('alreadyEchoed')
        else if logic.already=='downroter' and not logic.potentialEcho
          logic.riteToHistory=false
          callback('alreadyDownroted')
          console.log 'You cannot downrote again '
        else if logic.legitEcho
            console.log 'Legit echo, cool'
            callback('echo', rite, cellPoint)
            echoIt(cell, rite, riter, logic)
        else if logic.cEchoes<=0
            callback('overrite', rite, cellPoint)
            overriteIt(cell, rite, riter, logic) # this changes c.current to the rite
            console.log 'Legit overrite, there were no echoes'
        else if logic.cEchoes>=1
            if logic.already == 'echoer'
              if logic.cEchoes ==1
                callback('overrite', rite, cellPoint)
                overriteIt(cell, rite, riter, logic)
                console.log 'overrite something you echoed!'
              else
                callback('downrote', rite, cellPoint)
                downroteIt(cell, rite, riter, logic)
                console.log 'downroting something you echoed!'
            else if not logic.already == 'downroter' #not neccesary, for readability
              callback('downrote', rite, cellPoint)
              console.log 'legit downrote'
              downroteIt(cell, rite, riter, logic)
        else
          console.log 'well shit this shouldnt have happened'
        
        if logic.riteToHistory
          cell.history.push(rite)
          cell.save()
          console.log 'cell saved at the end yo'
  # end processRite

            
  broadcastRite= ->
    console.log 'broadcastrite called'



  # Externally Accessible
  module.processRite = processRite
  module.broadcastRite = broadcastRite
  
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
        console.log "already echoer!!! #{alreadyEchoPos}"
        return ['echoer', i]
  if cell?.current?.props.downroters
    for d in cell?.current?.props.downroters
      i+=1
      if d.toString()==riter.toString()
        isAlreadyDownroter = true
        alreadyDownPos=i
        console.log "already downroter!!! #{alreadyDownPos}"
        return ['downroter', i]
  console.log 'returning false from determine status'
  return [false, -1]

normalRite = (cell, rite, riter, logic) ->
  rite.props.echoes+=1
  rite.props.echoers.push(riter)
  rite.save (err) ->
    cell.current= rite._id
    cell.save()
  
echoIt = (cell, rite, riter, logic) ->
  cell.current.props.echoes+=1
  cell.current.props.echoers.push(riter)
  if logic.already=='downroter'
    cell.current.props.downroters.splice(logic.alreadyPos, 1)
  rite.save()
  cell.current.markModified('props')
  cell.current.save (err) -> console.log err if err
  return

downroteIt = (cell, rite, riter, logic) ->
  cell.current.props.echoes-=1
  cell.current.props.downroters.push(riter)
  if logic.already=='echoer'
    cell.current.props.echoers.splice(logic.alreadyPos, 1)
  rite.save()
  cell.current.markModified('props')
  cell.current.save (err) -> console.log err if err
  return

overriteIt = (cell, rite, riter, logic) ->
  rite.props.echoes+=1
  rite.props.echoers.push(riter)
  rite.save (err) ->
    cell.current = rite._id
    cell.save (err) -> console.log err if err
  return

# Utility 
Array::filter = (func) -> x for x in @ when func(x)
