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
    mainWorld.save (err, world) ->
      console log err if err
      console.log ' So we created the main world'
      exports.mainWorldId = world._id

ritePropsDefs=
  echoes: 0 #-1
  echoers: []
  downroters: []
console.log ritePropsDefs

RiteSchema = new Schema
  contents: {type: String, default: ' '} #conig TODO
  date: { type: Date, default: Date.now }
  owner: ObjectId
  props: {type:Schema.Types.Mixed, default:{} }
  # props: {type:Schema.Types.Mixed, default:ritePropsDefs} #{} }

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

exports.writeCellToDb = (cellPoint, contents, worldId, riter, isOwnerAuth, props={}) ->
    #userId will either be a session or a real user id # console.log "writing cell ownerId is : #{ownerId}"
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
      # console.log rite

      cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, world:worldId} if not cell

      # console.log 'ownerId', riter
      # console.log 'ccownId', cell.current?.owner.toString()
      isOwner = riter.toString() == cell.current?.owner.toString()
      isEcho = cell.current?.contents == rite.contents #change name to potentialEcho
      isLegitEcho = not isOwner and isEcho # and not isAnEchoer 
      isBlank = not cell.current or cell.current?.contents == ' ' # TODO  woops config.defaultChar()
      cEchoes = cell?.current?.props?.echoes
      isLegitDownrote = false #this is a flag, gets flipped in case 6
      # TODO check if in echoers, downroters,
      
      cell.history.push(rite) #should work even though i'm changing the rite later, it's a reference...right?

      console.log 'isOwner ', isOwner; console.log 'isEcho ', isEcho; console.log 'isLegitEcho ', isLegitEcho; console.log 'isBlank ', isBlank; console.log 'cEchoes ', cEchoes; console.log 'pre-echologic cell.current', cell.current
      console.log '------------------------------------------------------------'
      # console.log 'rite', rite

      doEchoLogic = ->
          # case 1
          if isBlank
            console.log 'WAS BLANK, ROTE'
            cell.current = rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) ->console.log err if err
            return true

          #case 2
          if isEcho and isOwner
            # I'm actually stopping this on client side
            console.log 'echoing yourself too much will make you go blind'
            return true
          
          # case 3
          if isOwner and cEchoes<=0
            console.log 'OVERWROTE SELF'
            cell.current = rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) ->console.log err if err
            return true

          # case 4
          if isOwner and cEchoes > 0
            console.log 'DOWNVOTED SELF'
            cell.current.props.echoes-=1
            cell.current.markModified('props')
            cell.current.save (err) ->console.log err if err
            cell.save (err) -> console.log err if err
            rite.save (err) -> console.log err if err
            return true

          #case 5
          if isLegitEcho
            console.log 'LEGIT ECHO YO'
            cell.current.props.echoes+=1
            cell.current.markModified('props')
            cell.current.save (err) -> console.log err if err
            # rite.save (err) ->
            #   console.log err if err
            #   cell.save (err) ->console.log err if err
            #   console.log cell.current.props
           
            #add to echoers #and downroters if thats there
            return true
          
          # case 6
          if cEchoes <= 0 and not isOwner
            console.log 'OVERROTE SOMEONE ELSE'
            cell.current= rite
            rite.save (err) ->
              cell.current = rite._id
              cell.save (err) -> console.log err if err
            return true

          # case 7
          if not isOwner and not isEcho #and not a downroter
            isLegitDownrote = true #flag!
            console.log 'legit downrote'
            cell.current.props.echoes-=1
            cell.current.markModified('props')
            cell.current.save (err) -> console.log err if err
            rite.save (err) -> console.log err if err
            # add to downroters
              #and echoers if thats there
            return true
        
      # calls the above and returns
      doEchoLogic()

      # console.log cell.current, 'current, after doechologic'

      if isLegitEcho
        exports.User.findById riter, (err, user)->
          if user
            user.totalRites+=1
            user.save (err) -> console.log err if err

      if isLegitEcho or isLegitDownrote
        #make this cUser based instead
        exports.User.findById cell.current.owner, (err, user) ->
          if isLegitEcho and user
            # if rite.props.isEcho
            user.totalEchoes+=1
            user.save (err)-> console.log err if err
            user.emit('receivedEcho', rite)
          else if isLegitDownrote and user
          # else if user._id.toString() != ownerId and isOwnerAuth
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
