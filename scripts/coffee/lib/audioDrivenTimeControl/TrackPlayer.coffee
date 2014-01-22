module.exports = class TrackPlayer

	constructor: (@timeControl, @track, @from = 0.0) ->

		@timeControl._waitForUpdate do @_ready

		@context = @timeControl.context

		@_destination = @timeControl.node

		@duration = 0.0

		@to = 0.0

		@audioData = null

		@_currentSource = null

	_ready: =>

		@track.load().then =>

			@audioData = @track.audioData

			@duration = @audioData.duration * 1000.0

			@to = @from + @duration

			return

	setPosition: (from) ->

		@from = parseFloat from

		@timeControl._waitForUpdate null

		@

	_queue: (t) ->

		localT = @_toLocalT t

		@_currentSource = @context.createBufferSource()

		@_currentSource.buffer = @audioData

		@_currentSource.connect @_destination

		offset = 0

		if localT > 0

			offset = localT / 1000.0

		wait = 0

		if localT < 0

			wait = @context.currentTime - localT / 1000.0

		@_currentSource.start wait, offset

	_unqueue: ->

		@_currentSource.stop 0

	_shouldUnqueue: (t) ->

		@_toLocalT(t) > @duration

	_toLocalT: (t) ->

		t - @from