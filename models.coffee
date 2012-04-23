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
  echoes: 0 #-1
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
  exports.Cell
  .findOne({world: worldId, x:cellPoint.x, y: cellPoint.y})
  .populate('current')
  .run (err, cell) ->
      console.log err if err
      # prepare our rite
      for own key, val of ritePropsDefs
        props[key] = val if not props?[key]

      rite = new Rite({contents: contents, owner:riter, props:props })
      rite.markModified('props')

      cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, world:worldId} if not cell

      if isPersonal # or not  world.echoes 
        cell.history.push(rite)
        cell.current = rite
        rite.save (err) ->
          cell.current = rite._id
          cell.save (err) ->console.log err if err
        return #and lets gtfo

      isAlreadyEchoer=false; isAlreadyDownroter = false
      if cell?.current?.props.echoers and riter in cell?.current?.props.echoers
        isAlreadyEchoer=true; console.log 'ALREADY ECHOER'
      if cell?.current?.props.downroters and riter in cell?.current?.props.downroters
        isAlreadyDownroter=true; console.log 'ALREADY DOWNROTER'
      
      isOwner = riter.toString() == cell.current?.owner.toString()
      isPotentialEcho = cell.current?.contents == rite.contents #change name to potentialEcho
      isLegitEcho = not isOwner and isPotentialEcho  and not isAlreadyEchoer
      isBlank = not cell.current or cell.current?.contents ==  exports.mainWorld.meta.defaultChar #' ' # TODO  woops config.defaultChar()
      isBlankRite = rite.contents == exports.mainWorld.meta.defaultChar
      cEchoes = cell?.current?.props?.echoes
      isLegitDownrote = false #this is a flag, gets flipped in case 6
      
      originalOwner = cell.current?.owner

      cell.history.push(rite)
      # console.log 'isOwner ', isOwner; console.log 'isEcho ', isEcho; console.log 'isLegitEcho ', isLegitEcho; console.log 'isBlank ', isBlank; console.log 'cEchoes ', cEchoes; console.log 'pre-echologic cell.current', cell.current

      doEchoLogic = ->
          if isBlank and isBlankRite #case 0
            console.log 'blank on blank action'
            return true
          if isBlank and not isBlankRite #case 1
            console.log 'WAS CURRENT BLANK, ROTE'
            cell.current = rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) ->console.log err if err
            return true

          if isPotentialEcho and isOwner #case 2
            # Actually stopping this on client side
            console.log 'echoing yourself too much will make you go blind'
            return true
          
          if isOwner and cEchoes<=0 #case 3
            console.log 'OVERROTE SELF'
            cell.current = rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) ->console.log err if err
            return true

          if isOwner and cEchoes > 0 #case 4
            console.log 'DOWNVOTED SELF'
            cell.current.props.echoes-=1
            cell.current.markModified('props')
            cell.current.save (err) ->console.log err if err
            rite.save (err) -> console.log err if err
            return true
                              # just added isblankrite: no echoing blank rites
          if isLegitEcho and not isBlankRite and not isAlreadyEchoer #case 5
            console.log 'LEGIT ECHO YO'
            cell.current.props.echoes+=1
            cell.current.props.echoers.push(riter)
            eindex=cell.current.props.downroters.indexOf(riter); cell.current.props.downroters.splice(eindex,1)
            cell.current.markModified('props')
            cell.current.save (err) -> console.log err if err
            rite.save (err) -> console.log err if err
            return true
          
          # it seems isAlready downroter isn't working...? print it out
          if cEchoes <= 0 and not isOwner and not isAlreadyDownroter #case 6
            console.log 'OVERROTE SOMEONE ELSE'
            cell.current= rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) -> console.log err if err
            return true

          # case 7
          if not isOwner and not isPotentialEcho and not isAlreadyDownroter
            isLegitDownrote = true #flag!
            console.log 'LEGIT DOWNROTE'
            cell.current.props.downroters.push(riter)
            eindex=cell.current.props.echoers.indexOf(riter); cell.current.props.echoers.splice(eindex,1)
            cell.current.props.echoes-=1
            cell.current.markModified('props')
            cell.current.save (err) -> console.log err if err
            rite.save (err) -> console.log err if err
            return true
        
      # Calls the above and returns
      doEchoLogic()

      if isLegitEcho
        console.log 'ADDING AN ECHO TO THAT USER if it exists yo'
        exports.User.findById riter, (err, user)->
          if user
            user.totalRites+=1
            user.save (err) -> console.log err if err
            # TODO add a emit ? or use below

      if isLegitEcho or isLegitDownrote or (cEchoes<=0 and not isOwner)
        exports.User.findById originalOwner, (err, user) ->
          console.log 'trying to send a message'
          if isLegitEcho and user
            console.log 'SENDING echo msg congrats'
            user.totalEchoes+=1
            user.save (err)-> console.log err if err
            user.emit('receivedEcho', rite)
          else if user and not isAlreadyDownroter
            console.log 'SENDING overrite msg boo'
            user.emit('receivedOverRite', rite)
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
