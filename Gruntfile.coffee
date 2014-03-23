
module.exports = (grunt) ->

	grunt.initConfig(
		pkg: grunt.file.readJSON('package.json')
		coffee: {}
		concat: {
			options: {}
			dist: {
				src: ['src/**/*.coffee']
				dest: 'dist/<%= pkg.name %>.coffee'
			}
		}
		uglify: {}
	)

	grunt.loadNpmTasks('grunt-contrib-concat')
	grunt.loadNpmTasks('grunt-contrib-coffee')

	grunt.registerTask('default', ['concat'])