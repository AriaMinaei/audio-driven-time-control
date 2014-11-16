Emitter = require 'utila/lib/Emitter'

module.exports = class SingleTrackWithAudioApi extends Emitter

	constructor: (@id, destination = new AudioContext) ->

		# the emitter
		super

		# setup the audio stuff
		if destination.context?

			@context = destination.context

		else

			@context = destination

			destination = @context.destination

		@node = @context.createGain()

		@node.connect destination

		@_currentSource = null

		@_actualT = 0.0

		@_lastWindowTime = 0.0

		@duration = 0.0

		@_trackDuration = 0.0

		@_requestedDuration = 0.0

		@_waitBeforePlay = 50

		@_isReady = no

		@_isPlaying = no

		@_isSet = no

		@_offset = 0.0

	setOffset: (offset) ->

		@_offset = +offset

	set: (source) ->

		throw Error "Another track is already set" if @_isSet

		@_isSet = yes

		req = @req = new XMLHttpRequest

		req.open 'GET', source, true

		req.responseType = 'arraybuffer'

		req.send()

		req.addEventListener 'load', =>

			@context.decodeAudioData req.response, success, failure

		success = (decoded) =>

			@decodedBuffer = decoded

			do @_getReady

		failure = =>

			console.error "Unable to decode audio data"

	_getReady: ->

		return if @_isReady

		@_trackDuration = @decodedBuffer.duration * 1000.0

		do @_updateDuration

		@_isReady = yes

		@_emit 'ready-state-change'

		return

	_updateDuration: ->

		newDuration = Math.max @_requestedDuration, @_trackDuration

		if newDuration isnt @duration

			@duration = newDuration

			@_emit 'duration-change'

	maximizeDuration: (duration) ->

		@_requestedDuration = duration

		do @_updateDuration

	isPlaying: ->

		@_isPlaying

	isReady: ->

		@_isReady

	_actualTToUserT: (actualT) ->

		actualT + @_offset

	_userTToActualT: (userT) ->

		userT - @_offset

	_setT: (actual) ->

		@_actualT = actual

		@t = @_actualTToUserT actual

	tick: ->

		return unless @_isPlaying

		currentWindowTime = performance.now()

		@_setT @_actualT + currentWindowTime - @_lastWindowTime

		@_lastWindowTime = currentWindowTime

		if @_actualT > @duration

			do @pause

			@seekTo 0.0

			return

		@_emit 'tick', @t

		return

	play: ->

		return if @_isPlaying

		do @_play if @_isReady

		return

	togglePlay: ->

		if @_isPlaying

			do @pause

		else

			do @play

	pause: ->

		return unless @_isPlaying

		do @_unqueue

		@_isPlaying = no

		@_emit 'pause'

		return

	seekTo: (t) ->

		t = @_userTToActualT t

		if @_isPlaying

			wasPlaying = yes

			do @pause

		if t > @duration then t = @duration

		if t < 0 then t = 0.0

		@_setT t

		@_emit 'tick', @t

		if wasPlaying

			do @play

		return

	seek: (amount) ->

		@seekTo @t + amount

	_play: ->

		return if @_actualT > @duration

		@_lastWindowTime = performance.now()

		@_actualT -= @_waitBeforePlay

		do @_queue

		@_isPlaying = yes

		@_emit 'play'

	_queue: ->

		localT = @_actualT

		@_currentSource = @context.createBufferSource()

		@_currentSource.buffer = @decodedBuffer

		@_currentSource.connect @node

		offset = 0

		if localT > 0

			offset = localT / 1000.0

		wait = 0

		if localT < 0

			wait = @context.currentTime - localT / 1000.0

		@_currentSource.start wait, offset

	_unqueue: ->

		@_currentSource.stop 0

AudioContext = window.AudioContext || window.webkitAudioContext