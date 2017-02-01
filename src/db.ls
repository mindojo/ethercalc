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


  # Ask for data if any available on backend so we can restore
  # previous sessions
  request.get do
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
        console.log data
        console.log "==> Restored previous session from DB"
      else
        console.log "==> No previous session in DB found"

    # Define commands that are a replacement for the onces that should be
    # originally used for Redis database
    Commands =
      # Save data to database
      bgsave: (cb) ->
        dataToBeDumped = JSON.stringify db.DB,,2

        # Updata data in the db on every save
        # TODO: As the object ID is hardcoded in host, we assume that
        # there is always an object to PUT something into. However this
        # must be changed and we first must check if object even exists
        # and if not, we have to create it and save its ID or something
        # like that.
        request.put do
          CONFIG.host
          { json: { data: dataToBeDumped } }
          (err, res, body) ->
            console.error err if err

        cb?!

      addSpreadsheet: (key) ->
        # First of, get just the key
        key = key.split('_')[0]
        # Find out whether we have this spreadsheet key
        spreadsheets = db.spreadsheets.filter( (spreadsheetKey) -> spreadsheetKey is key )
        # unless we have it, add the spreadsheet key
        unless spreadsheets.length > 0
          db.spreadsheets.push key

      get: (key, cb) -> cb?(null, db.DB[key])

      set: (key, val, cb) -> db.DB[key] = val; cb?!

      exists: (key, cb) -> cb(null, if db.DB.hasOwnProperty(key) then 1 else 0)

      rpush: (key, val, cb) -> (db.DB[key] ?= []).push val; cb?!

      lrange: (key, from, to, cb) -> cb?(null, db.DB[key] ?= [])

      hset: (key, idx, val, cb) -> (db.DB[key] ?= {})[idx] = val; cb?!   # e.g. HSET myhash field1 "Hello"

      hgetall: (key, cb) -> cb?(null, db.DB[key] ?= {})

      hdel: (key, idx) -> delete db.DB[key][idx] if db.DB[key]?; cb?!    # e.g. HDEL myhash field1

      rename: (key, key2, cb) -> db.DB[key2] = delete db.DB[key]; cb?!

      keys: (select, cb) -> cb?(null, Object.keys(db.DB).filter(minimatch.filter(select)))

      del: (keys, cb) ->
        if Array.isArray keys
          for key in keys => delete! db.DB[key]
        else
          delete db.DB[keys]
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
