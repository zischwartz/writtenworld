mongoose= require 'mongoose'
util = require('util')
events = require('events')

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

WorldSchema = new Schema
  owner: ObjectId
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true}
  slug: { type: String, lowercase: true, trim: true }

slugGenerator= (options) ->
  options = options || {}
  key = options.key || 'name'
  return slugGenerator= (schema)->
    schema.path(key).set (v) ->
      this.slug = v.toLowerCase().replace(/[^a-z0-9]/g, '').replace(/-+/g, '')
      return v
    
WorldSchema.plugin slugGenerator()

exports.World = mongoose.model('World', WorldSchema)


RiteSchema = new Schema
  contents: {type: String, default: ' '}
  date: { type: Date, default: Date.now }
  owner: ObjectId
  # props: {}
  # echoes: {type: Number, default: 0}
  # isEcho: {type: Boolean, default: false}
  props: {type:Schema.Types.Mixed, default:{} } # This default is failing.

Rite = mongoose.model('Rite', RiteSchema)

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  contents: {type: String, default: ' '}
  current: { type: Schema.ObjectId, ref: 'Rite' }
  history: [{ type: Schema.ObjectId, ref: 'Rite' }]

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.Cell = mongoose.model('Cell', CellSchema)

#userId will either be a session or a real user id
exports.writeCellToDb = (cellPoint, contents, worldId, ownerId, isOwnerAuth, props={}) ->
  # console.log 'writing cell with ', contents
  exports.Cell
  .findOne({world: worldId, x:cellPoint.x, y: cellPoint.y})
  .populate('current')
  .run (err, cell) ->
      console.log err if err
      rite = new Rite({contents: contents, owner:ownerId, props:props })
      # console.log 'new rite: ' , rite
      # console.log 'cell: ', cell
      if not cell
          # console.log 'no cell, creating one'
          cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, contents: contents, world:worldId}
      else if (cell.current.contents == contents) and (cell.current.owner.toString() != ownerId) and isOwnerAuth
          # console.log 'is echo! cell.current:  ', cell.current
          # cell.current.echoes+=1
          if not cell.current.props.echoes
            cell.current.props.echoes = 0
          cell.current.props.echoes+=1
          cell.current.markModified('props')
          cell.current.save (err) -> console.log err if err
          # rite.isEcho = true
          rite.props.isEcho = true
          rite.markModified('props')
          # console.log 'cell.current= ', cell.current
      cell.history.push(rite)
      rite.save (err) ->
        # cell.current = rite._id if not rite.isEcho
        cell.current = rite._id if not rite.props.isEcho
        # cell.contents = contents
        cell.save (err) ->console.log err if err
      
      exports.User.findById ownerId, (err, user)->
        if user
          user.totalRites+=1
          user.save (err) -> console.log err if err

      if rite.props.isEcho
        exports.User.findById cell.current.owner, (err, user) ->
          if user
            user.totalEchoes+=1
            user.save (err)-> console.log err if err
            user.emit('receivedEcho', rite)
            #put a notify event here
            # console.log 'INSPECT'
            # console.log util.inspect user, true, 2, true
  true


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
          personal= new exports.World {personal:true, owner:user._id, name:"#{user.login}'s History" }
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


exports.User.prototype.on 'receivedEcho', (details) ->
  console.log 'GOT AN ECHO EVENT !!!!!!!!!!!!!!!!!!!!!!!!!!!ADSFADSFASDFASDFADF'
  console.log 'this: ', this
  console.log details
  return true


# rite = new Rite({contents: contents, owner:ownerId, props:props })

# aUser = new exports.User
# aUser.prototype = new events.EventEmitter

# util.inherits(exports.User, events.EventEmitter)
# console.log 'aUser! ',  aUser
# console.log util.inspect exports.User, true, 2, true

# console.log util.inspect exports.User, true, 2, true

exports.mongooseAuth= mongooseAuth
