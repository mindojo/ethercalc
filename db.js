// Generated by LiveScript 1.5.0
(function(){
  var slice$ = [].slice;
  this.__DB__ = null;
  this.include = function(){
    var request, CONFIG, minimatch, db, addModification, Commands;
    if (this.__DB__) {
      return this.__DB__;
    }
    request = require('request');
    CONFIG = require('./environment');
    minimatch = require('minimatch');
    db = {};
    db.DB = {};
    db.spreadsheets = [];
    db.modifications = [];
    addModification = function(key, value){
      var modificationIndex;
      modificationIndex = db.modifications.findIndex(function(modification){
        return deepEq$(modification.modKey, key, '===');
      });
      if (modificationIndex >= 0) {
        return db.modifications[modificationIndex] = value;
      } else {
        return db.modifications.push({
          modKey: key,
          modValue: value
        });
      }
    };
    request.get(CONFIG.host, function(err, res){
      var data;
      if (err) {
        return console.error(err);
      }
      data = JSON.parse(res.body).data;
      if (data) {
        db.DB = JSON.parse(data);
        return console.log("==> Restored previous session from DB");
      } else {
        return console.log("==> No previous session in DB found");
      }
    }, Commands = {
      bgsave: function(cb){
        var dataToBeDumped, i$, ref$, len$, modification;
        dataToBeDumped = JSON.stringify(db.DB, void 8, 2);
        console.log('\n\n\nstart modifying... ============================>\n\n');
        for (i$ = 0, len$ = (ref$ = db.modifications).length; i$ < len$; ++i$) {
          modification = ref$[i$];
          console.log('modification', modification);
        }
        console.log('\n\nend modifying...   ============================>\n\n\n');
        request.put(CONFIG.host, {
          json: {
            data: dataToBeDumped
          }
        }, function(err, res, body){
          if (err) {
            return console.error(err);
          }
        });
        return typeof cb == 'function' ? cb() : void 8;
      },
      addSpreadsheet: function(key){
        var spreadsheets;
        key = key.split('_')[0];
        spreadsheets = db.spreadsheets.filter(function(spreadsheetKey){
          return spreadsheetKey === key;
        });
        if (!(spreadsheets.length > 0)) {
          return db.spreadsheets.push(key);
        }
      },
      get: function(key, cb){
        return typeof cb == 'function' ? cb(null, db.DB[key]) : void 8;
      },
      set: function(key, val, cb){
        db.DB[key] = val;
        addModification(key, val);
        return typeof cb == 'function' ? cb() : void 8;
      },
      exists: function(key, cb){
        return cb(null, db.DB.hasOwnProperty(key) ? 1 : 0);
      },
      rpush: function(key, val, cb){
        var ref$, ref1$;
        ((ref1$ = (ref$ = db.DB)[key]) != null
          ? ref1$
          : ref$[key] = []).push(val);
        addModification(key, db.DB[key]);
        return typeof cb == 'function' ? cb() : void 8;
      },
      lrange: function(key, from, to, cb){
        var ref$, ref1$;
        return typeof cb == 'function' ? cb(null, (ref1$ = (ref$ = db.DB)[key]) != null
          ? ref1$
          : ref$[key] = []) : void 8;
      },
      hset: function(key, idx, val, cb){
        var ref$, ref1$;
        ((ref1$ = (ref$ = db.DB)[key]) != null
          ? ref1$
          : ref$[key] = {})[idx] = val;
        addModification(key, db.DB[key]);
        return typeof cb == 'function' ? cb() : void 8;
      },
      hgetall: function(key, cb){
        var ref$, ref1$;
        return typeof cb == 'function' ? cb(null, (ref1$ = (ref$ = db.DB)[key]) != null
          ? ref1$
          : ref$[key] = {}) : void 8;
      },
      hdel: function(key, idx){
        if (db.DB[key] != null) {
          delete db.DB[key][idx];
        }
        if (db.DB[key] != null) {
          addModification(key, db.DB[key]);
        }
        return typeof cb == 'function' ? cb() : void 8;
      },
      rename: function(key, key2, cb){
        var ref$, ref1$;
        db.DB[key2] = (ref1$ = (ref$ = db.DB)[key], delete ref$[key], ref1$);
        addModification(key, false);
        addModification(key2, db.DB[key2]);
        return typeof cb == 'function' ? cb() : void 8;
      },
      keys: function(select, cb){
        return typeof cb == 'function' ? cb(null, Object.keys(db.DB).filter(minimatch.filter(select))) : void 8;
      },
      del: function(keys, cb){
        var i$, len$, key;
        if (Array.isArray(keys)) {
          for (i$ = 0, len$ = keys.length; i$ < len$; ++i$) {
            key = keys[i$];
            delete db.DB[key];
            addModification(key, false);
          }
        } else {
          delete db.DB[keys];
          addModification(keys, false);
        }
        return typeof cb == 'function' ? cb() : void 8;
      }
    }, importAll$(db, Commands), db.multi = function(){
      var cmds, res$, i$, to$, name;
      res$ = [];
      for (i$ = 0, to$ = arguments.length; i$ < to$; ++i$) {
        res$.push(arguments[i$]);
      }
      cmds = res$;
      for (name in Commands) {
        (fn$.call(this, name));
      }
      cmds.results = [];
      cmds.exec = function(cb){
        var ref$, cmd, args, this$ = this;
        switch (false) {
        case !this.length:
          ref$ = this.shift(), cmd = ref$[0], args = ref$[1];
          db[cmd].apply(db, slice$.call(args).concat([function(_, result){
            this$.results.push(result);
            this$.exec(cb);
          }]));
          break;
        default:
          cb(null, this.results);
        }
      };
      return cmds;
      function fn$(name){
        cmds[name] = function(){
          var args, res$, i$, to$;
          res$ = [];
          for (i$ = 0, to$ = arguments.length; i$ < to$; ++i$) {
            res$.push(arguments[i$]);
          }
          args = res$;
          this.push([name, args]);
          return this;
        };
      }
    });
    return this.__DB__ = db;
  };
  function deepEq$(x, y, type){
    var toString = {}.toString, hasOwnProperty = {}.hasOwnProperty,
        has = function (obj, key) { return hasOwnProperty.call(obj, key); };
    var first = true;
    return eq(x, y, []);
    function eq(a, b, stack) {
      var className, length, size, result, alength, blength, r, key, ref, sizeB;
      if (a == null || b == null) { return a === b; }
      if (a.__placeholder__ || b.__placeholder__) { return true; }
      if (a === b) { return a !== 0 || 1 / a == 1 / b; }
      className = toString.call(a);
      if (toString.call(b) != className) { return false; }
      switch (className) {
        case '[object String]': return a == String(b);
        case '[object Number]':
          return a != +a ? b != +b : (a == 0 ? 1 / a == 1 / b : a == +b);
        case '[object Date]':
        case '[object Boolean]':
          return +a == +b;
        case '[object RegExp]':
          return a.source == b.source &&
                 a.global == b.global &&
                 a.multiline == b.multiline &&
                 a.ignoreCase == b.ignoreCase;
      }
      if (typeof a != 'object' || typeof b != 'object') { return false; }
      length = stack.length;
      while (length--) { if (stack[length] == a) { return true; } }
      stack.push(a);
      size = 0;
      result = true;
      if (className == '[object Array]') {
        alength = a.length;
        blength = b.length;
        if (first) {
          switch (type) {
          case '===': result = alength === blength; break;
          case '<==': result = alength <= blength; break;
          case '<<=': result = alength < blength; break;
          }
          size = alength;
          first = false;
        } else {
          result = alength === blength;
          size = alength;
        }
        if (result) {
          while (size--) {
            if (!(result = size in a == size in b && eq(a[size], b[size], stack))){ break; }
          }
        }
      } else {
        if ('constructor' in a != 'constructor' in b || a.constructor != b.constructor) {
          return false;
        }
        for (key in a) {
          if (has(a, key)) {
            size++;
            if (!(result = has(b, key) && eq(a[key], b[key], stack))) { break; }
          }
        }
        if (result) {
          sizeB = 0;
          for (key in b) {
            if (has(b, key)) { ++sizeB; }
          }
          if (first) {
            if (type === '<<=') {
              result = size < sizeB;
            } else if (type === '<==') {
              result = size <= sizeB
            } else {
              result = size === sizeB;
            }
          } else {
            first = false;
            result = size === sizeB;
          }
        }
      }
      stack.pop();
      return result;
    }
  }
  function importAll$(obj, src){
    for (var key in src) obj[key] = src[key];
    return obj;
  }
}).call(this);
