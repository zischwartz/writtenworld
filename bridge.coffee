models= require './models.js'
nowjs = require 'now'

async = require './lib/async.js'

leaflet = require './lib/leaflet-custom-src.js'

module.exports = (everyone, SessionModel) ->

  processRite = (cellPoint, contents, nowUser, currentWorldId) ->
    # nowUser is this.user with everyone.now
    console.log 'processRite Called !!!!!', nowUser

    cid = nowUser.clientId
    sid= decodeURIComponent nowUser.cookie['connect.sid']
    
    # If user has an account and is logged in
    if nowUser.session.auth
      riter=nowUser.session.auth.userId
      models.User.findById riter, (err, user) ->
        if user.personalWorld.toString() isnt currentWorldId  #check if they're already in their own world (heh)
          console.log 'write to their world'
          #write to personal world here
    # Not logged in
    else
      riter = nowUser.soid #session object id

    # serially do echo logic
    models.Cell
    .findOne({world: currentWorldId, x:cellPoint.x, y: cellPoint.y})
    .populate('current')
    .run (err, cell) ->
        console.log err if err

        if not cell or not cell.current
          #simple case: lets skip the below
          console.log 'no cell or blank cell'

        if cell and cell.current
          console.log 'cell found w/ current'
          [already, alreadyPos] = determineStatus(cell, riter)
        
        logic=
          blankCurrently : not cell?.current or cell?.current?.contents == models.mainWorld.meta.defaultChar #TODO make this a config
          blankRite: contents == models.mainWorld.meta.defaultChar
          potentialEcho : cell?.current?.contents == contents
          legitEcho : @potentialEcho and already != 'echoer'
          cEchoes : cell?.current?.props?.echoes
          legitDownrote: not @blankCurrently and not @potentialEcho and already != 'downroter'
          already: already? #echoer or downroter --string
          alreadyPos: alreadyPos?

        for k, v of logic
         console.log "#{k} : #{v}"
        console.log ' '
        
        if logic.blankCurrently
          console.log 'blank, just write'
          normalRite(cell, rite, riter, logic)
          return true
        if logic.potentialEcho and logic.already == 'echoer'
          console.log 'Echoing yourself too much will make you go blind'
          return false
        if logic.already=='downroter' and not logic.potentialEcho
          console.log 'FU, you cannot downrote again'
          return false
        else
          if logic.legitEcho
            console.log 'Legit echo, cool'
            echoIt(cell, rite, riter, logic)
            return true
          else # downrote/overrite
            if logic.cEchoes<=0
              overriteIt(cell, rite, riter, logic)
              # just rite, remove from echoers
              console.log 'legit overrite'
              return true
            else if logic.cEchoes>=1
                if logic.already == 'echoer'
                  if logic.cEchoes ==1
                    overriteIt(cell, rite, riter, logic)
                    console.log 'overrite something you echoed!'
                  else
                    downroteIt(cell, rite, riter, logic)
                    console.log 'downroting something you echoed!'
                  return true
                else
                  console.log 'legit downrote'
                  downroteIt(cell, rite, riter, logic)
                  return true
        
  
  # externally accessible
  module.test = -> console.log 'TESTY test test'
  
  module.processRite = processRite


  return module


# Helpers
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
