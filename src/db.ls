@__DB__ = null
@include = ->
  return @__DB__ if @__DB__

  require! \request

  require! './environment': CONFIG

  require! \minimatch

  require! 'lodash': _

  # At the end, we assign this var to @__DB__
  db = {}

  # Holds the database data that are pulled or pushed from/to backend API
  db.DB = {}

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


  # Helper method to get a sheet_id
  # SheetIds may look like this for example: chat-sheet_id, chat-sheet_id_form, ...
  # and we want to get just the sheet_id
  getSheetId = (sheetId) ->
    sheetIdArr = sheetId.split('-')
    sheetIdIndex = 0
    if sheetIdArr.length > 1
      sheetIdIndex = 1
    sheetId = sheetIdArr[sheetIdIndex].split('_')[0]


  # Define commands that are a replacement for the onces that should be
  # originally used for Redis database
  Commands =
    # Save data to database
    bgsave: (cb) ->
      return unless db.modifications.length > 0

      # Create a a hashtable from modifications
      toBeSaved = {}
      for modification in db.modifications
        if modification.modValue === null
          toBeSaved[modification.modKey] = modification.modValue
        else
          toBeSaved[modification.modKey] = JSON.stringify modification.modValue

      # Updata modified data in the db on every save
      request do
        {
          url: CONFIG.host
          method: "POST",
          agentOptions:
            rejectUnauthorized: false
          json: toBeSaved
        }
        (err, res, body) ->
          return console.error err if err
          return console.error body.error if body.error
          cleanModifications!

      cb?!

    fetchData: (sheetId, cb) ->
      # Get a pure sheetId
      sheetId = getSheetId sheetId

      # Ask for data if any available on backend so we can restore
      # previous session
      request do
        {
          url: CONFIG.host + sheetId
          agentOptions:
            rejectUnauthorized: false
        }
        (err, res) ->
          return console.error err if err

          # Parse data from db
          # From DB we for example get the following object
          # {
          #   "html-<sheet_id>": "html here",
          #   "snapshot-<sheet_id>": "JSON.stringified data here"
          # }
          # This is gonna be in the following data variable
          data = JSON.parse res.body

          unless _.isEmpty data or data.error
            # Parse stringified data from API
            dataToBeAssigned = {}
            for key, value of data
              if data.hasOwnProperty key
                dataToBeAssigned[key] = JSON.parse value

            # Merge received data with current database
            db.DB = _.assign db.DB, dataToBeAssigned

          cb?!

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

  db.updateHtmlRepresentation = (key, html) ->
    addModification "html-#{key}", html, 'updateHtmlRepresentation'
    # HTML representation is updated after all modifications have been pushed
    # to the API so we have to push the HTML representation separately
    db.bgsave!


  @__DB__ = db
