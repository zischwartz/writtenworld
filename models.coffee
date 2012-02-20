mongoose= require 'mongoose'

# NEED TO WRITE EXPORTS and integrate with app.coffee

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

#yeah hardwiring!

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
  color: {type: String, default: ' '}
  isEcho: {type: Boolean, default: false}

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
exports.writeCellToDb = (cellPoint, contents, worldId, ownerId) ->
  exports.Cell
  .findOne({world: worldId, x:cellPoint.x, y: cellPoint.y})
  .populate('current')
  .run (err, cell) ->
      console.log 'BEFORE', cell.current if cell
      console.log err if err
      rite = new Rite({contents: contents, owner:ownerId})
      if not cell
          cell = new exports.Cell {x:cellPoint.x, y:cellPoint.y, contents: contents, world:worldId}
      else if cell.current.contents == contents
          console.log 'its an echo! ', cell.current.contents, ' ', contents
          cell.current.echoes+=1
          cell.current.save (err) -> console.log err if err  
          rite.isEcho = true
      cell.history.push(rite)
      rite.save (err) ->
        cell.current = rite._id if not rite.isEcho
        cell.contents = contents
        cell.save (err) ->console.log err if err
        console.log 'AFTER',  cell.current
  true

mongooseAuth=require('mongoose-auth')
UserSchema = new Schema
  totalRites: {type: Number, default: 0}
  activeRites: {type: Number, default:0}
  totalEchoes: {type: Number, default:0}
 
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
        
exports.User= mongoose.model('User', UserSchema)

exports.mongooseAuth= mongooseAuth
