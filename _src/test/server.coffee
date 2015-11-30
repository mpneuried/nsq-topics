express = require( "express" )
bodyParser = require('body-parser')
morgan = require('morgan')

jsonParser = bodyParser.json()
urlencodedParser = bodyParser.urlencoded({ extended: false })

test = require( "./data" )

class TopicSimulator extends require('events').EventEmitter
	servers: []
	serverPorts: [ 4161, 4163 ]
	
	constructor: ->
		@running = false
		@started = 0
		
		@app = express()
		@app.use( morgan('dev') )
		
		@on( "started", @checkRunning )
		
		@createRoutes()
		@start()
		return
	
	createRoutes: =>
		@app.get "/topics", ( req, res )->
			res.status( 200 ).send( test() )
			return
		
		return
		
	checkRunning: =>
		if @started is @serverPorts.length
			@running = true
			@emit "running", @servers
		return
	
	start: =>
		@started = 0
		_that = @
		for port in @serverPorts
			@servers.push @app.listen port, ->
				port = @address().port
				console.log( "NSQlookupd Simulation listening on port `%s`", port )
				_that.started++
				_that.emit "started", @address()
				return
		return
		
	stop: ( idx = 0 )=>
		if @servers[ idx ]?
			console.log( "NSQlookupd Simulation on port `%s` - SHUTDOWN!", @servers[ idx ].address().port )
			@servers[ idx ].close()
			@servers[ idx ] = null
		return

module.exports = new TopicSimulator()
