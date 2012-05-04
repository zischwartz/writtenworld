models= require './models'
nowjs = require 'now'

async = require './lib/async.js'
leaflet = require './lib/leaflet-custom-src.js'


module.exports = (everyone, SessionModel) ->

  processRite = (cellPoint, contents, nowUser, currentWorldId, callback) ->
    # nowUser is this.user within  everyone.now
    cid = nowUser.clientId
    sid= decodeURIComponent nowUser.cookie['connect.sid']
    
    color= nowUser.session?.color
    # console.log 'color', color
    getOut=false
    # If user has an account and is logged in
    if nowUser.session.auth
      riter=nowUser.session.auth.userId
      models.User.findById riter, (err, user) ->
        # if user.personalWorld.toString() isnt currentWorldId  #check if they're already in their own world (heh)
          # console.log 'write to their world' #write to personal world here
          models.Cell .findOne({world: user.personalWorld, x:cellPoint.x, y: cellPoint.y}) .populate('current')
          .run (err, cell) ->
              console.log err if err
              cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world:user.personalWorld} if not cell
              rite = new models.Rite({contents: contents, owner:riter, props:{echoers:[], echoes:-1, downroters:[], color: color}})
              cell.history.push(rite)
              rite.save (err) ->
                cell.current= rite._id
                cell.save()
              if user.personalWorld.toString() is currentWorldId  #check if they're already in their own world (heh)
                console.log 'was actually writing directly to yr world, so skip the echo behavior below'
                getOut=true
                return 
       if getOut
         return
    else # Not logged in
      riter = nowUser.soid #session object id

    models.Cell
    .findOne({world: currentWorldId, x:cellPoint.x, y: cellPoint.y})
    .populate('current')
    .run (err, cell) ->
        console.log err if err

        if not cell or not cell.current
          # console.log 'no cell or blank cell'
          cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world:currentWorldId}
          [already, alreadyPos] = [false, -1]

        if cell and cell.current
          # console.log 'cell found w/ current'
          # console.log determineStatus(cell, riter)
          [already, alreadyPos] = determineStatus(cell, riter)
       
        #todo load the world, outside of this function, it its not main or personal
        logic=
          blankCurrently : not cell?.current or cell?.current?.contents == models.mainWorld.config.defaultChar #TODO make this a config
          blankRite: contents == models.mainWorld.config.defaultChar
          potentialEcho : cell?.current?.contents == contents
          cEchoes : cell?.current?.props?.echoes
          already: already #echoer or downroter --string
          alreadyPos: alreadyPos
          riteToHistory: true #flag

        logic.legitEcho = already != 'echoer' and logic.potentialEcho
        logic.legitDownrote= not logic.blankCurrently and not logic.potentialEcho and already != 'downroter'
        originalOwner = cell.current?.owner

        debug = ' '
        for k, v of logic
         debug+="#{k} : #{v}  .  "
        
        rite = new models.Rite({contents: contents, owner:riter, props:{echoers:[], echoes:-1, downroters:[], color: color}})
        console.log ' '
        # console.log ' '
        # console.log 'riter ', riter
        # console.log debug

        if logic.blankCurrently
          console.log 'Blank, just write'
          normalRite(cell, rite, riter, logic)
          callback('normalRite', rite, cellPoint)
        else if logic.potentialEcho and logic.already == 'echoer'
          console.log 'Echoing yourself too much will make you go blind'
          logic.riteToHistory=false
          callback('alreadyEchoed')
        else if logic.already=='downroter' and not logic.potentialEcho
          console.log 'You cannot downrote again '
          logic.riteToHistory=false
          callback('alreadyDownroted')
        else if logic.legitEcho
            console.log 'Legit echo, cool'
            echoIt(cell, rite, riter, logic)
            callback('echo', rite, cellPoint, cell.current.props)
        else if logic.cEchoes<=0
            console.log 'Legit overrite, there were no echoes'
            overriteIt(cell, rite, riter, logic) # this changes c.current to the rite
            callback('overrite', rite, cellPoint, cell.current.props)
        else if logic.cEchoes>=1
            console.log '.'
            if logic.already isnt 'echoer'
              console.log 'Legit Downrote'
              downroteIt(cell, rite, riter, logic)
              callback('downrote', rite, cellPoint, cell.current.props)
            else if logic.already == 'echoer'
              if logic.cEchoes ==1
                console.log 'Overrite something you echoed!'
                overriteIt(cell, rite, riter, logic)
                callback('overrite', rite, cellPoint, cell.current.props)
              else
                console.log 'Downroting something you echoed!'
                downroteIt(cell, rite, riter, logic)
                callback('downrote', rite, cellPoint, cell.current.props)
        else
          console.log 'WELL SHIT THIS SHOULDNT HAVE HAPPENED'
        
        if logic.riteToHistory
          cell.history.push(rite)
          cell.save()
          models.User.findById riter, (err, user)->
            if user
              user.totalRites+=1
              user.save (err) -> console.log err if err

        # make CUser based? TODO
        console.log getOut
        if originalOwner and  (logic.legitEcho or logic.legitDownrote) and not getOut
          models.User.findById originalOwner, (err, user) ->
            if user and logic.legitEcho
              user.totalEchoes+=1
              user.save (err)-> console.log err if err
              user.emit('receivedEcho', rite)
            if user and logic.legitDownrote and originalOwner.toString() isnt riter.toString()
              user.emit('receivedOverRite', rite)

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
        # console.log "already echoer!!! #{alreadyEchoPos}"
        return ['echoer', i]
  if cell?.current?.props.downroters
    for d in cell?.current?.props.downroters
      i+=1
      if d.toString()==riter.toString()
        isAlreadyDownroter = true
        alreadyDownPos=i
        # console.log "already downroter!!! #{alreadyDownPos}"
        return ['downroter', i]
  # console.log 'returning false from determine status'
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
