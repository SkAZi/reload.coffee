fs    = require 'fs'
util  = require 'util'
path  = require 'path'
proc  = require 'child_process'
prog  = process.argv.shift()
self  = path.basename process.argv.shift()
args  = process.argv
child = null

# Files to be watched and precompiled
WATCHES =
    '.js'    : null
    '.coffee': (file) -> ["coffee", ["-c", file]]
    #'.json' : null
    #'.sass' : (file) -> ["sass", [file, file.replace(/\.sass$/, ".css")]]
    #'.sql'  : (file) -> ["sqlite3", ["-init", file]]
    #'.c'    : (file) -> ["gcc", [file]]

# Regexp for filetypes
SUPPORTED = (key for key, value of WATCHES).join "|"

WATCH_INTERVAL = 1000


# Precompile function
compile = (file, cb) ->
    type = file.match(/(\.\w+)$/)?[1]
    if WATCHES[type]
        cmp = do () ->
            cmpargs = WATCHES[type](file)
            proc.spawn cmpargs[0], cmpargs[1]

        cmp.on 'exit', cb if cmp? and cb?
    else 
        cb() if cb?


eachWatchedFile = (cb) ->
    proc.exec "find . | grep -P '(#{SUPPORTED})$'", (error, stdout, stderr) ->
        files = stdout.trim().split('\n')
        files_count = files.length
        files.forEach (file) ->
            cb file, files_count


args = args.map (file) ->
    compile(file)
    file.replace /\.coffee$/, '.js'



main = () ->

    if not args.length or args[0] is '--help'
        util.print "\n    #{self} expects at least one argument. Try running #{self} like this:"
        util.print "\n    > node #{self} [app.js]\n"
        util.print "\n    (You may want to check out http://github.com/johnflesch/reload.js/blob/master/README.md)\n\n"
        return 

    # If the node instance already exists, kill it so we can restart
    child.kill() if child?.pid
    
    # Spawn a new instance of 'node'
    child = proc.spawn prog, args

    # Display STDOUT, STDERR and EXIT
    child.stdout.on 'data', (data) -> util.print data
    child.stderr.on 'data', (data) -> util.print data
    child.stderr.on 'exit', (code, signal) ->
        util.debug "[#{self}] Child process exited with code (#{code}), and signal (#{signal})"

    # Watch all the "js" and "coffee" files in our application for changes.
    eachWatchedFile (file) ->
        fs.unwatchFile file
        fs.watchFile file, interval: WATCH_INTERVAL, (curr, prev) ->
            if curr.mtime.valueOf() > prev.mtime.valueOf()
                if /\.js$/.test file
                    util.debug "[#{self}] #{file} has changed. Restarting!"
                    main.call()
                else 
                    util.debug "[#{self}] #{file} has changed. Recompiling..."
                    compile file


# Precompile all scripts
util.debug "[#{self}] Compiling project..."

compile_counter = 0
eachWatchedFile (file, files_count) ->

    # Compile each
    compile file, () ->

        # Count when compiled
        if files_count == ++compile_counter

            # Then start project
            util.debug "[#{self}] Starting #{args[0]}"
            main()
