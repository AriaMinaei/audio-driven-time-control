Emitter = require 'utila/lib/Emitter'

module.exports = class SingleTrackWithAudioElement extends Emitter

	constructor: ->

		# the emitter
		super

		@t = 0.0

		@duration = 0.0

		@_el = null

		@_isReady = no

		@_isPlaying = no

		@_offset = 0.0

	set: (source) ->

		if @_el?

			throw Error "Another track is already set"

		if typeof source is 'string'

			@_el = document.createElement 'audio'

			@_el.src = source

		else

			@_el = source

		@_el.addEventListener 'canplaythrough', => do @_receiveCanPlayThrough
		@_el.addEventListener 'pause', => do @_receivePause
		@_el.addEventListener 'play', => do @_receivePlay

		@_el

	setOffset: (offset) ->

		@_offset = +offset

	_receiveCanPlayThrough: ->

		return if @_isReady

		@_el.currentTime = @t / 1000.0

		@duration = @_el.duration * 1000.0

		@_emit 'duration-change'

		@_isReady = yes

		@_emit 'ready-state-change'

		return

	_receivePlay: ->

		@_isPlaying = yes

		@_emit 'play'

	_receivePause: ->

		@_isPlaying = no

		@_emit 'pause'

	maximizeDuration: ->

	isPlaying: ->

		@_isPlaying

	isReady: ->

		@_isReady

	tick: ->

		return unless @_isPlaying

		@t = @_elementTimeToTime(@_el.currentTime)

		@_emit 'tick', @t

		return

	_elementTimeToTime: (et) ->

		(et * 1000.0) - @_offset

	seekTo: (t) ->

		@t = t

		if @_isReady

			@_el.currentTime = @_timeToElementTime(t)

		@_emit 'tick', @t

		return

	_timeToElementTime: (t) ->

		(t + @_offset) / 1000.0

	togglePlay: ->

		if @_isPlaying

			do @pause

		else

			do @play

	play: ->

		return if @_isPlaying

		@_el.play()

		return

	pause: ->

		return unless @_isPlaying

		@_el.pause()

		return

	mute: ->

		@_el?.volume = 0

	unmute: ->

		@_el?.volume = 1