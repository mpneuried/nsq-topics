should = require('should')
_difference = require('lodash/difference')

NsqTopics = require( "../." )

test = require( "./data" )

nsqTopics = null
topicSimulator = null

CNF =
	lookupdHTTPAddresses: []
	lookupdPollInterval: .5
	topicFilter: null

_testArray = ( inp, pred )->
	inp.length.should.equal( pred.length )
	
	for _t in pred when _t not in inp
		asrt = new should.Assertion(_t)
		asrt.params =
			operator: "be in `#{ inp.join( '`, `' ) }`"
		asrt.fail()
		
	return
	
_setAddresses = ( servers )->
	for server in servers
		CNF.lookupdHTTPAddresses.push server.address().address + ":" + server.address().port
	return

describe "----- hyperrequest TESTS -----", ->

	before ( done )->
		topicSimulator = require( "./server" )
		
		if topicSimulator.running
			_setAddresses( topicSimulator.servers )
			nsqTopics = new NsqTopics( CNF )
			done()
			return
		
		topicSimulator.on "running", ( servers )->
			# wait until simulation server is running
			_setAddresses( servers )
			nsqTopics = new NsqTopics( CNF )
			done()
			return
		return

	after ( done )->		
		done()
		process.exit(0)
		return

	describe 'Main Tests', ->

		# Implement tests cases here
		it "initial value", ( done )->
			nsqTopics.list ( err, result )->
				throw err if err
				
				_testArray( result, test.list() )

				done()
				return
			return
		
		it "add a topic", ( done )->
			nsqTopics.list ( err, result )->
				throw err if err
				
				_before = test.list()
				_testArray( result, _before )
				
				_topicsDiff = []
				
				_check = ( topic )->
					_topicsDiff.should.containEql( topic )
					nsqTopics.removeListener( "add", _check )
					done()
					return
					
				# listen to the add event
				nsqTopics.on( "add", _check )
				
				# step to the next test
				_topicsDiff = _difference( test.next().list(), _before )
				
				return
			return
		
		it "add two topics - listen to `add`", ( done )->
			nsqTopics.list ( err, result )->
				throw err if err
				
				
				_before = test.list()
				_testArray( result, _before )
				
				_topicsDiff = []
				
				count = 2
				_test = ->
					if count <= 0
						done()
						nsqTopics.removeAllListeners()
					return
				
				_check = ( topic )->
					_topicsDiff.should.containEql( topic )
					count--
					_test()
					return
					
				# listen to the add event
				nsqTopics.on( "add", _check )
				
				# step to the next test
				_topicsDiff = _difference( test.next().list(), _before )
				
				return
			return
		
		it "add two topics - listen to `change`", ( done )->
			nsqTopics.list ( err, result )->
				throw err if err
				
				
				_before = test.list()
				_after = []

				_check = ( topics )->
					_testArray( topics, _after )
					nsqTopics.removeAllListeners()
					done()
					return
					
				# listen to the add event
				nsqTopics.on( "change", _check )
					
				_after = test.next().list()
				
				return
			return
		
		it "remove a topic", ( done )->
			
			
			_topicsDiff = []
			
			_check = ( topic )->
				_topicsDiff.should.containEql( topic )
				nsqTopics.removeAllListeners()
				done()
				return
				
			# listen to the add event
			nsqTopics.on( "remove", _check )
			
			# step to the next test
			_before = test.list()
			_topicsDiff = _difference( _before, test.next().list() )
				
			return
		
		it "remove two topics - listen to `remove`", ( done )->

			_before = test.list()
			
			_topicsDiff = []
			
			count = 2
			_test = ->
				count--
				if count <= 0
					done()
					nsqTopics.removeAllListeners()
				return
			
			_check = ( topic )->
				_topicsDiff.should.containEql( topic )
				_test()
				return
				
			# listen to the add event
			nsqTopics.on( "remove", _check )
			
			# step to the next test
			_topicsDiff = _difference( _before, test.next().list() )

			return
		
		it "remove two topics - listen to `change`", ( done )->

			_before = test.list()
			_after = []

			_check = ( topics )->
				_testArray( topics, _after )
				nsqTopics.removeAllListeners()
				done()
				return
				
			# listen to the add event
			nsqTopics.on( "change", _check )
				
			_after = test.next().list()
			
			return
		
		it "add and remove topics", ( done )->

			_before = test.list()
			_after = []
			
			count = 5
			_test = ->
				count--
				if count <= 0
					nsqTopics.list ( err, result )->
						throw err if err
						_testArray( result, _after )
						done()
						nsqTopics.removeAllListeners()
						return
				return
			
			_checkAdd = ( topic )->
				_topicsAdd.should.containEql( topic )
				_test()
				return
			
			_checkRemove = ( topic )->
				_topicsRem.should.containEql( topic )
				_test()
				return
			
			_checkChange = ( topics )->
				_testArray( topics, _after )
				_test()
				return
				
			# listen to the add event
			nsqTopics.on( "remove", _checkRemove )
			nsqTopics.on( "add", _checkAdd )
			nsqTopics.on( "change", _checkChange )
			
			# step to the next test
			_after = test.next().list()
			_topicsRem = _difference( _before, _after )
			_topicsAdd = _difference( _after, _before )

			return
		
		it "add filter", ( done )->
			
			_before = test.list()
			_topicsDiff = []
			
			count = 2
			_test = ->
				count--
				if count <= 0
					nsqTopics.removeAllListeners()
					
					nsqTopics.on "remove", ( topic )->
						topic.should.startWith('_')
						nsqTopics.removeAllListeners()
						done()
						return
					
					# add a filter to hide topic staring with "_"
					nsqTopics.filter ( topic )->
						return topic[0] isnt "_"
						
				return
			
			_check = ( topic )->
				_topicsDiff.should.containEql( topic )
				_test()
				return
				
			# listen to the add event
			nsqTopics.on( "add", _check )
			
			# step to the next test
			_topicsDiff = _difference( test.next().list(), _before )
			
			return
			
		it "remove filter", ( done )->
			nsqTopics.on "add", ( topic )->
				topic.should.startWith('_')
				nsqTopics.removeAllListeners()
				done()
				return
			
			# add a filter to hide topic staring with "_"
			nsqTopics.filter( null )
			return
			
		it "regex filter", ( done )->
			regexp = /^_|_$/ig
			
			count = test.len() - 2
			_test = ->
				count--
				if count <= 0
					done()
					nsqTopics.removeAllListeners()
				return
				
			nsqTopics.on "remove", ( topic )->
				topic.should.not.match(regexp)
				_test()
				return
			
			# add a filter to hide topic staring with "_"
			nsqTopics.filter( regexp )
			return
			
		it "set array filter", ( done )->
			@timeout( 6000 )
			count = test.len() - 1
			_test = ->
				count--
				if count <= 0
					nsqTopics.removeAllListeners()
					
					_before = test.list()
					
					nsqTopics.on "add", ( topic )->
						console.log topic
						throw new Error( "Should not called!" )
						return
					
					test.next()
					
					_final = ->
						nsqTopics.removeAllListeners()
						done()
						return
					
					setTimeout( _final, 4000 )
				return
				
			nsqTopics.on "add", ( topic )->
				_test()
				return
				
			nsqTopics.on "change", ( topics )->
				_testArray( topics, test.list()  )
				_test()
				return
			
			# add a filter to hide topic staring with "_"
			_arFilter = test.list()
			nsqTopics.filter( _arFilter )
			return
		
		it "try invalid filter", ( done )->
			( ->
				nsqTopics.filter( 42 )
			).should.throw( Error, { name: "EINVALIDFILTER" })
			done()
			return
		
		it "one lookup server down", ( done )->
			
			#reset filter
			nsqTopics.on "change", ->
				
				nsqTopics.removeAllListeners()
				
				topicSimulator.stop(0)
				
				setTimeout( ->
					# listen to the add event
					nsqTopics.on "add", ( topic )->
						_topicsDiff.should.containEql( topic )
						nsqTopics.removeAllListeners()
						done()
						return
					
					# step to the next test
					_before = test.list()
					_topicsDiff = _difference( test.next().list(), _before )
				
				, 1000 )
				return
				
			nsqTopics.filter( null )
			return
			
		it "all lookup servers down ... error event", ( done )->
			@timeout( 3000 )
			# listen to the add event
			nsqTopics.on "error", ( err )->
				console.log('err', err.name);
				
				should.exist( err )
				err.should.have.property( "name" )
				err.name.should.equal( "EUNAVAILIBLE" )
				done()
				return
			
			topicSimulator.stop(1)
			return
			
		return
	return



	
