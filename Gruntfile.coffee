
module.exports = (grunt) ->

	grunt.initConfig(
		concat: {}
		uglify: {}
	)

	grunt.registerTask('default', 'Log some stuff.', () ->
		grunt.log.write('Logging some stuff...').ok()
	)