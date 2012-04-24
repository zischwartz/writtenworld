util = require('util')
events = require('events')

mongoose= require 'mongoose'
mongoose.connect('mongodb://localhost/mapist')

Schema = mongoose.Schema
ObjectId = Schema.ObjectId



WorldSchema = new Schema
  owner: ObjectId
  ownerlogin: {type: String}
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true} #a personal history world
  public: {type: Boolean, default: false}  # 
  slug: { type: String, lowercase: true, trim: true }
  meta:
    maxZoom: {type: Number}
    minZoom: {type: Number}
    defaultChar: {type: String, default: ' '}
    tileSize:           #in pixels
      x: {type: Number}
      y: {type: Number}

  props: {type:Schema.Types.Mixed, default:{} }

slugGenerator= (options) ->
  options = options || {}
  key = options.key || 'name'
  return slugGenerator= (schema)->
    schema.path(key).set (v) ->
      this.slug = v.toLowerCase().replace(/[^a-z0-9]/g, '').replace(/-+/g, '')
      return v
    
WorldSchema.plugin slugGenerator()

exports.World = mongoose.model('World', WorldSchema)

exports.World.findOne {name: 'main'}, (err, world)->
  if world
    exports.mainWorldId = world._id
    exports.mainWorld = world
    console.log ' Found main world'
  else
    console.log ' Could not find main world...'
    mainWorld = new exports.World
      name: 'main'
      personal: false
      public: true
      meta:
        maxZoom:18
        minZoom: 10
        tileSize:
          x: 192
          y: 256
      props:
        echoes: true

    mainWorld.save (err, world) ->
      console log err if err
      console.log ' So we created the main world'
      exports.mainWorldId = world._id
      exports.mainWorld

ritePropsDefs=
  echoes: -1
  echoers: []
  downroters: []

RiteSchema = new Schema
  contents: {type: String, default: ' '} #conig TODO
  date: { type: Date, default: Date.now }
  owner: ObjectId
  props: {type:Schema.Types.Mixed, default:{} }

RiteSchema.methods.getOwner= (cb)->
  return this.db.model('User').findById(this.owner).run(cb)

Rite = mongoose.model('Rite', RiteSchema)

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  # contents: {type: String, default: ' '}
  current: { type: Schema.ObjectId, ref: 'Rite' }
  history: [{ type: Schema.ObjectId, ref: 'Rite' }]

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.Cell = mongoose.model('Cell', CellSchema)

exports.writeCellToDb = (cellPoint, contents, worldId, riter, isOwnerAuth, isPersonal, props={}) ->
  # prepare our rite
  for own key, val of ritePropsDefs
    if not props?[key]
      if key=='echoers' or key=='downroters'
        props[key]=[]
      else
        props[key] = val
  rite = new Rite({contents: contents, owner:riter, props:props })
  rite.markModified('props')

  exports.Cell
  .findOne({world: worldId, x:cellPoint.x, y: cellPoint.y})
  .populate('current')
  .run (err, cell) ->
      console.log err if err

      cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, world:worldId} if not cell

      cell.history.push(rite)

      if isPersonal # or not  world.echoes 
        cell.current = rite
        rite.save (err) ->
          cell.current = rite._id
          cell.save (err) ->console.log err if err
        console.log 'personal, lets gtfo'
        return #and lets gtfo

      isAlreadyEchoer=false; isAlreadyDownroter = false; i=-1; alreadyDownPos= -1; alreadyEchoPos=-1; #hacktastic, because indexof doesn't work with mongoose objectIds
      if cell?.current?.props.echoers
        for e in cell?.current?.props.echoers
          i+=1
          if e.toString()==riter.toString()
            isAlreadyEchoer = true
            alreadyEchoPos= i
            console.log "already echoer!!! #{alreadyEchoPos}"
      if cell?.current?.props.downroters
        for d in cell?.current?.props.downroters
          i+=1
          if d.toString()==riter.toString()
            isAlreadyDownroter = true
            alreadyDownPos=i
            console.log "already downroter!!! #{alreadyDownPos}"
      isPotentialEcho = cell.current?.contents == rite.contents
      isLegitEcho = isPotentialEcho  and not isAlreadyEchoer
      isBlankCurrent = not cell.current or cell.current?.contents ==  exports.mainWorld.meta.defaultChar #' ' # TODO  woops config.defaultChar()
      isBlankRite = rite.contents == exports.mainWorld.meta.defaultChar
      cEchoes = cell?.current?.props?.echoes

      isLegitDownrote = false #this is a flag, gets flipped in case 6
       
      doEchoLogic = ->
        normalRite = (cell, rite, riter) ->
          rite.props.echoes+=1
          rite.props.echoers.push(riter)
          rite.save (err) ->
            cell.current= rite._id
            cell.save()
          
        echoIt = (cell, rite, riter) ->
          cell.current.props.echoes+=1
          cell.current.props.echoers.push(riter)
          if isAlreadyDownroter
            cell.current.props.downroters.splice(alreadyDownPos, 1)
          rite.save()
          cell.current.markModified('props')
          cell.current.save (err) -> console.log err if err
          return

        downroteIt = (cell, rite, riter) ->
          cell.current.props.echoes-=1
          cell.current.props.downroters.push(riter)
          if isAlreadyEchoer
            cell.current.props.echoers.splice(alreadyEchoPos, 1)
          rite.save()
          cell.current.markModified('props')
          cell.current.save (err) -> console.log err if err
          return

        overriteIt = (cell, rite, riter) ->
          rite.props.echoes+=1
          rite.props.echoers.push(riter)
          rite.save (err) ->
            cell.current = rite._id
            cell.save (err) -> console.log err if err
          return

        if isBlankCurrent
          console.log 'blank, just write'
          normalRite(cell, rite, riter)
          return true
        if isPotentialEcho and isAlreadyEchoer
          console.log 'Echoing yourself too much will make you go blind'
          return false
        if isAlreadyDownroter and not isPotentialEcho
          console.log 'FU, you cannot downrote again'
          return false
        else
          if isLegitEcho
            console.log 'Legit echo, cool'
            echoIt(cell, rite, riter)
            return true
          else # downrote/overrite
            if cEchoes<=0
              overriteIt(cell, rite, riter)
              # just rite, remove from echoers
              console.log 'legit overrite'
              return true
            else if cEchoes>=1
                if isAlreadyEchoer
                  if cEchoes ==1
                    overriteIt(cell, rite, riter)
                    console.log 'overrite something you echoed!'
                  else
                    downroteIt(cell, rite, riter)
                    console.log 'downroting something you echoed!'
                  return true
                else
                  console.log 'legit downrote'
                  downroteIt(cell, rite, riter)
                  return true
                  #remove, incr etc

          
        
      # Calls the above and returns
      doEchoLogic()
      console.log '-----------'
      # if isLegitEcho
      #   console.log 'ADDING AN ECHO TO THAT USER if it exists yo'
      #   exports.User.findById riter, (err, user)->
      #     if user
      #       user.totalRites+=1
      #       user.save (err) -> console.log err if err
      #       # TODO add a emit ? or use below

      # if isLegitEcho or isLegitDownrote or (cEchoes<=0 and not isOwner)
      #   exports.User.findById originalOwner, (err, user) ->
      #     console.log 'trying to send a message'
      #     if isLegitEcho and user
      #       console.log 'SENDING echo msg congrats'
      #       user.totalEchoes+=1
      #       user.save (err)-> console.log err if err
      #       user.emit('receivedEcho', rite)
      #     else if user and not isAlreadyDownroter
      #       console.log 'SENDING overrite msg boo'
      #       user.emit('receivedOverRite', rite)
  return true


mongooseAuth=require('mongoose-auth')
UserSchema = new Schema
  totalRites: {type: Number, default: 0}
  activeRites: {type: Number, default:0}
  totalEchoes: {type: Number, default:0}
  color: {type: String, default: ''}
  personalWorld: ObjectId
  email: String

UserSchema.plugin mongooseAuth,
    everymodule:
      everyauth:
        User: -> exports.User
    password:
      # loginWith: 'email',
      extraParams:
         email: String
      everyauth:
        getLoginPath: '/login'
        postLoginPath: '/login'
        loginView: 'login.jade'
        getRegisterPath: '/register'
        postRegisterPath: '/register'
        registerView: 'register.jade'
        loginSuccessRedirect: '/'
        registerSuccessRedirect: '/'

        respondToRegistrationSucceed: (res, user, data) ->
          # console.log user, data
          personal= new exports.World {personal:true, owner:user._id, name:"#{user.login}'s History", ownerlogin: user.login }
          personal.save (err, doc)->
            user.personalWorld = personal._id
            user.save (err) -> console.log err if err
          if data.session.redirectTo
            res.writeHead 303, {'Location': data.session.redirectTo}
          else
            res.writeHead 303, {'Location': '/'}  # data.session.redirectTo}
          res.end()

          true


exports.User= mongoose.model('User', UserSchema)


FeedbackSchema = new Schema
  contents: {type: String, default: ' '}

exports.Feedback = mongoose.model('Feedback', FeedbackSchema)


#UTILITY
# Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

Array::filter = (func) -> x for x in @ when func(x)

# 
# exports.User.prototype.on 'receivedEcho', (rite) ->
#   console.log 'GOT AN ECHO EVENT !!!!!!!!!!!!!!!!!!!!!!!!!!!ADSFADSFASDFASDFADF'
#   console.log 'this: ', this
#   console.log details
#   return true


# rite = new Rite({contents: contents, owner:ownerId, props:props })

# aUser = new exports.User
# aUser.prototype = new events.EventEmitter

# util.inherits(exports.User, events.EventEmitter)
# console.log 'aUser! ',  aUser
# console.log util.inspect exports.User, true, 2, true

# console.log util.inspect exports.User, true, 2, true

exports.mongooseAuth= mongooseAuth
