@__DB__ = null
@include = ->
  return @__DB__ if @__DB__

  require! \request

  require! './environment': CONFIG

  require! \minimatch

  # At the end, we assign this var to @__DB__
  db = {}

  # Hold the database that is pulled or pushed from/to backend API
  db.DB = {}

  # Array of spreadsheet keys that are available
  db.spreadsheets = []

  # Array of modifications that have been made since last save to db
  # For example:
  # {
  #   modKey: 'chat-5bmhbf9j7j3h',
  #   modValue: 'something'
  # }
  db.modifications = []

  # Helper method to add modification to the array
  # The newer modification replaces old modification (if there are same keys)
  # @param [String] key - for example 'chat-12345566'
  # @param [Object] value - if undefined, the key should be removed from db (for example del method removes keys)
  addModification = (key, value, type) ->
    modificationIndex = db.modifications.findIndex (modification) -> modification.modKey === key
    if modificationIndex >= 0
      db.modifications[modificationIndex].modValue = value
    else
      db.modifications.push {
        modKey: key
        modValue: value
      }


  cleanModifications = ->
    db.modifications = []


  isObjectEmpty = (obj) ->
    for prop in obj
      if obj.hasOwnProperty prop
        return false
    JSON.stringify(obj) === JSON.stringify({});


  # Ask for data if any available on backend so we can restore
  # previous sessions
  /*request.get do
    CONFIG.host # URL to backend API
    (err, res) ->
      return console.error err if err

      # Parse data from db
      # In DB we have for example the following objects
      # {
      #   "id": 1,
      #   "data": "JSON.stringified data here"
      # }
      # and by sending the request, we receive that particular object
      # and we wanna get its database from data property
      data = JSON.parse res.body .data
      if data
        db.DB = JSON.parse data
        #console.log data
        console.log "==> Restored previous session from DB"
      else
        console.log "==> No previous session in DB found"*/

  # Define commands that are a replacement for the onces that should be
  # originally used for Redis database
  Commands =
    # Save data to database
    bgsave: (cb) ->
      # console.log '\n\nbgsave =================================>'
      return unless db.modifications.length > 0

      console.log '\n\n\nstart modifying... ============================>\n\n'
      for modification in db.modifications
        console.log \modification, modification
      console.log '\n\nend modifying...   ============================>\n\n\n'

      # Create a a hashtable from modifications
      toBeSaved = {}
      for modification in db.modifications
        toBeSaved[modification.modKey] = modification.modValue

      # Updata modified data in the db on every save
      request.put do
        CONFIG.host
        { json: { data: toBeSaved } }
        (err, res, body) ->
          console.error err if err
          cleanModifications! unless err

      cb?!

    addSpreadsheet: (key) ->
      # First of, get just the key
      key = key.split('_')[0]
      # Find out whether we have this spreadsheet key
      spreadsheets = db.spreadsheets.filter( (spreadsheetKey) -> spreadsheetKey is key )
      # unless we have it, add the spreadsheet key
      unless spreadsheets.length > 0
        db.spreadsheets.push key

    fetchData: (sheetId) ->
      # Ask for data if any available on backend so we can restore
      # previous session
      request.get do
        CONFIG.host + sheetId # URL to backend API
        (err, res) ->
          return console.error err if err

          # Parse data from db
          # In DB we have for example the following objects
          # {
          #   "id": 1,
          #   "data": "JSON.stringified data here"
          # }
          # and by sending the request, we receive that particular object
          # and we wanna get its database from data property
          data = JSON.parse res.body

          console.log \data, data
          console.log '=====================================>'

          unless isObjectEmpty data
            delete data.id
            db.DB = Object.assign db.DB, data
            #console.log data
            console.log "==> Restored previous session from DB"
            console.log db.DB
            console.log '=====================================>'
          else
            console.log "==> No previous session in DB found"

    updateHtmlRepresentation: (key, html) ->
      addModification key, html, 'updateHtmlRepresentation'

    get: (key, cb) -> cb?(null, db.DB[key])

    set: (key, val, cb) ->
      db.DB[key] = val
      addModification key, val, 'set'
      cb?!

    exists: (key, cb) -> cb(null, if db.DB.hasOwnProperty(key) then 1 else 0)

    rpush: (key, val, cb) ->
      (db.DB[key] ?= []).push val
      addModification key, db.DB[key], 'rpush'
      cb?!

    lrange: (key, from, to, cb) -> cb?(null, db.DB[key] ?= [])

    hset: (key, idx, val, cb) ->
      (db.DB[key] ?= {})[idx] = val # e.g. HSET myhash field1 "Hello"
      addModification key, db.DB[key], 'hset'
      cb?!

    hgetall: (key, cb) -> cb?(null, db.DB[key] ?= {})

    hdel: (key, idx) ->
      delete db.DB[key][idx] if db.DB[key]?
      addModification key, db.DB[key], 'hdel' if db.DB[key]?
      cb?!    # e.g. HDEL myhash field1

    rename: (key, key2, cb) ->
      db.DB[key2] = delete db.DB[key]
      addModification key, null, 'rename'
      addModification key2, db.DB[key2], 'rename'
      cb?!

    keys: (select, cb) -> cb?(null, Object.keys(db.DB).filter(minimatch.filter(select)))

    del: (keys, cb) ->
      if Array.isArray keys
        for key in keys =>
          delete! db.DB[key]
          addModification key, null, 'del'
      else
        delete db.DB[keys]
        addModification keys, null, 'del'
      cb?!

  db <<<< Commands

  db.multi = (...cmds) ->
    for name of Commands => let name
      cmds[name] = (...args) ->
        @push [name, args]; @
    cmds.results = []
    cmds.exec = !(cb) ->
      | @length
        [cmd, args] = @shift!
        _, result <~! db[cmd](...args)
        @results.push result
        @exec cb
      | otherwise => cb null, @results
    return cmds


  @__DB__ = db
