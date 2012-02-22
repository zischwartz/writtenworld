mongoose= require 'mongoose'

# NEED TO WRITE EXPORTS and integrate with app.coffee

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

WorldSchema = new Schema
  owner: ObjectId
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true}

exports.World = mongoose.model('World', WorldSchema)

RiteSchema = new Schema
  contents: {type: String, default: ' '}
  date: { type: Date, default: Date.now }
  owner: ObjectId
  echoes: {type: Number, default: 0}
  isEcho: {type: Boolean, default: false}
  props: {}

Rite = mongoose.model('Rite', RiteSchema)

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  contents: {type: String, default: ' '}
  # history: [RiteSchema] # a collection of Rites
  current: { type: Schema.ObjectId, ref: 'Rite' }
  history: [{ type: Schema.ObjectId, ref: 'Rite' }]

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.Cell = mongoose.model('Cell', CellSchema)

#userId will either be a session or a real user id
exports.writeCellToDb = (cellPoint, contents, worldId, ownerId, isOwnerAuth, props={}) ->
  console.log 'writing cell with ', contents
  exports.Cell
  .findOne({world: worldId, x:cellPoint.x, y: cellPoint.y})
  .populate('current')
  .run (err, cell) ->
      console.log err if err
      rite = new Rite({contents: contents, owner:ownerId, props:props })
      # console.log 'new rite: ' , rite
      if not cell
          cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, contents: contents, world:worldId}
      else if (cell.current.contents == contents) and (cell.current.owner.toString() != ownerId) and isOwnerAuth
          console.log 'is echo!'
          cell.current.echoes+=1
          cell.current.save (err) -> console.log err if err
          rite.isEcho = true
      cell.history.push(rite)
      rite.save (err) ->
        cell.current = rite._id if not rite.isEcho
        cell.contents = contents
        cell.save (err) ->console.log err if err
      
      exports.User.findById ownerId, (err, user)->
        if user
          user.totalRites+=1
          user.save()

      if rite.isEcho
        exports.User.findById cell.current.owner, (err, user) ->
          if user
            user.totalEchoes+=1
            user.save()
            #put a notify event here
  true


mongooseAuth=require('mongoose-auth')
UserSchema = new Schema
  totalRites: {type: Number, default: 0}
  activeRites: {type: Number, default:0}
  totalEchoes: {type: Number, default:0}
  color: {type: String, default: ''}
  personalWorld: ObjectId

UserSchema.plugin mongooseAuth,
    everymodule:
      everyauth:
        User: -> exports.User
    password:
      # loginWith: 'email'
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
          console.log 'SSSSSSSSUCESSSSSSSS---------'
          # console.log user, data
          personal= new exports.World {personal:true, owner:user._id, name:"#{user.login}'s History" }
          personal.save (err, doc)->
            user.personalWorld = personal._id
            user.save()
          if data.session.redirectTo
            res.writeHead 303, {'Location': data.session.redirectTo}
          else
            res.writeHead 303, {'Location': '/'}  # data.session.redirectTo}
          res.end()

          true

exports.User= mongoose.model('User', UserSchema)

exports.mongooseAuth= mongooseAuth
