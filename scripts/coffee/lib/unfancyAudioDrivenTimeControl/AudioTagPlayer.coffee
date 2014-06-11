wn = require 'when'

module.exports = class AudioTagPlayer

	constructor: (@timeControl, @address, @from = 0.0) ->

		@_el = document.createElement 'audio'

		@_el.src = @address

		@timeControl._waitForUpdate do @_ready

		@context = @timeControl.context

		@_destination = @timeControl.node

		@duration = 0.0

		@to = 0.0

	_ready: =>

		d = wn.defer()

		resolved = no

		@_el.addEventListener 'canplaythrough', =>

			return if resolved

			resolved = yes

			@duration = @_el.duration * 1000.0

			@to = @from + @duration

			d.resolve()

			return

		d.promise

	setPosition: (from) ->

		@from = parseFloat from

		@to = @from + @duration

		@timeControl._waitForUpdate null

		@

	_queue: (t) ->

		do @_unqueue

		localT = @_toLocalT t

		if localT >= 0

			@_el.currentTime = localT / 1000.0

			@_el.play()

		else

			@_el.currentTime = 0

			@_el.play()

		return

	_unqueue: ->

		@_el.pause()

		return

	_shouldUnqueue: (t) ->

		@_toLocalT(t) > @duration

	_toLocalT: (t) ->

		t - @from

	mute: ->

		@_el.volume = 0

	unmute: ->

		@_el.volume = 1