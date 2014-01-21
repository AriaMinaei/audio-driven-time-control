wn = require 'when'
{call} = require 'when/callbacks'

module.exports = class CachedAudio

	self = @

	constructor: (@context, @addr) ->

		@_addrInFs = 'track-' + @addr.replace /([\/\\]+|\.\.)/g, '--'

		@_infoAddrInFs = @_addrInFs + '-info'

		@_loadPromise = do @_load

		@audioData = null

	_isCached: ->

		self._openFs()

		.then (fs) =>

			self
			._getFile(fs.root, @_infoAddrInFs)
			.then (->yes), (->no)

	load: ->

		@_loadPromise

	_load: ->

		@_isCached().then (isCached) =>

			if isCached

				console.log 'cached'

				@_getAudioFromCache().then(@_getReady)

			else

				console.log 'not cached'

				@_loadByXhr().then(@_decode).then(@_getReady).then(@_cache)

	_getReady: (@audioData) =>

		s = @context.createBufferSource()
		s.buffer = @audioData

		s.connect @context.destination

		s.start 0

	_getAudioFromCache: ->

		info = null

		fs = null

		self._openFs().then (_fs) =>

			fs = _fs

			self._getFile(fs.root, @_infoAddrInFs)

		.then (infoFile) =>

			self._readAsText infoFile

		.then (infoJson) =>

			info = JSON.parse infoJson

			self._getFile fs.root, @_addrInFs

		.then (dataFile) =>

			self._readAsArrayBuffer dataFile

		.then (dataBuffer) =>

			intv = new Uint8Array dataBuffer

			originalByteLength = dataBuffer.byteLength

			lastIndex = info.channels.length - 1

			audioBuffer = @context.createBuffer info.numberOfChannels,

				info.length, info.sampleRate

			for startOffset, index in info.channels

				if index isnt lastIndex

					endOffset = info.channels[index + 1]

				else

					endOffset = originalByteLength

				byteLength = endOffset - startOffset

				channelInt = new Uint8Array intv.subarray startOffset, endOffset

				audioBuffer.getChannelData(index).set new Float32Array channelInt.buffer

			audioBuffer

	_loadByXhr: =>

		d = wn.defer()

		req = new XMLHttpRequest

		req.open 'GET', @addr, yes

		req.responseType = 'arraybuffer'

		console.time 'xhr'

		req.addEventListener 'load', (e) ->

			console.timeEnd 'xhr'

			d.resolve req.response

			return

		req.send()

		d.promise

	_decode: (encodedBuffer) =>

		d = wn.defer()

		console.time 'decode'

		@context.decodeAudioData encodedBuffer, (audioData) ->

			console.timeEnd 'decode'

			d.resolve audioData

			return

		, (err) ->

				d.reject "Couldn't decode audio data"

				return

		d.promise

	_cache: =>

		audioData = @audioData

		channels = []

		# assume 10KB of more size
		size = 10 * 1024

		# let's calculate the needed size
		channels = for i in [0...audioData.numberOfChannels]

			c = audioData.getChannelData i

			size += c.byteLength

			c

		# open the fs
		self._openFsWithQuota(size)
		.then (fs) =>

			a = @_writeInfoFile fs, audioData, channels, @addr

			b = @_writeDataFile fs, channels

			wn.join a, b

	_writeDataFile: (fs, channels) ->

		blob = new Blob channels

		self._overwriteFile fs, @_addrInFs, blob

	_writeInfoFile: (fs, audioData, channels, originalAddress) ->

		offset = 0

		info =

			channels: []

			sampleRate: audioData.sampleRate

			length: audioData.length

			numberOfChannels: audioData.numberOfChannels

			duration: audioData.duration

			originalAddress: originalAddress

		for channel in channels

			info.channels.push offset

			offset += channel.byteLength

		info = JSON.stringify info

		console.log 'info', info

		blob = new Blob [info], type: 'text/plain'

		self._overwriteFile fs, @_infoAddrInFs, blob

	@_readAsText: (file) ->

		call(file.file.bind(file))
		.then (file) ->

			d = wn.defer()

			reader = new FileReader

			reader.onloadend = (e) ->

				d.resolve @result

			reader.readAsText file

			d.promise

	@_readAsArrayBuffer: (file) ->

		call(file.file.bind(file))
		.then (file) ->

			d = wn.defer()

			reader = new FileReader

			reader.onloadend = (e) ->

				d.resolve @result

			reader.readAsArrayBuffer file

			d.promise

	@_getFile: (dir, path, flags) ->

		call dir.getFile.bind(dir), path, flags

	@_openFs: (size = 0) ->

		call requestFileSystem, PERSISTENT, size

	@_openFsWithQuota: (size) ->

		finalSpaceNeeded = 0

		call(Storage.queryUsageAndQuota.bind(Storage))
		.then (args) =>

			finalSpaceNeeded = args[0] + size

			# and request more
			call Storage.requestQuota.bind(Storage), finalSpaceNeeded

		.then =>

			@_openFs finalSpaceNeeded

	@_truncateFile: (file, size = 0) ->

		call(file.createWriter.bind(file))
		.then (writer) ->

			d = wn.defer()

			writer.onwriteend = ->

				d.resolve file

			writer.onerror = (e) ->

				d.reject e

			writer.truncate size

			d.promise

	@_writeToFile: (file, blob) ->

		call(file.createWriter.bind(file))
		.then (writer) ->

			d = wn.defer()

			writer.onwriteend = ->

				d.resolve file

			writer.onerror = (e) ->

				console.log 'truncate'
				d.reject e

			writer.write blob

			d.promise

	@_overwriteFile: (fs, path, blob) ->

		call(fs.root.getFile.bind(fs.root), path, {create: yes})
		.then (file) ->

			self._truncateFile file, 0

		.then (file) ->

			self._writeToFile file, blob

Storage = navigator.PersistentStorage || navigator.webkitPersistentStorage
requestFileSystem = requestFileSystem || webkitRequestFileSystem