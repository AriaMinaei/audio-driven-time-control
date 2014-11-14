SingleTrackWithAudioElement = require './SingleTrackWithAudioElement'
SingleTrackWithAudioApi = require './SingleTrackWithAudioApi'

if window.AudioContext? or window.webkitAudioContext?

	module.exports = SingleTrackWithAudioApi

else

	module.exports = SingleTrackWithAudioElement