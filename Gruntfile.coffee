
module.exports = (grunt) ->

	grunt.initConfig(
		pkg: grunt.file.readJSON('package.json')
		concat: {
			options: {}
			dist: {
				src: ['src/**/*.coffee']
				dest: 'dist/<%= pkg.name %>.coffee'
			}
		}
		coffee: {
			compile: {
				files: {
					'dist/<%= pkg.name %>.js': 'dist/<%= pkg.name %>.coffee'
				}
			}
		}
		uglify: {
			options: {
				banner: '/*! <%= pkg.name %> <%= grunt.template.today("dd-mm-yyyy") %> */\n'
			},
			dist: {
				files: {
					'dist/<%= pkg.name %>.min.js': ['dist/<%= pkg.name %>.js']
				}
			}
		}
	)

	grunt.loadNpmTasks('grunt-contrib-concat')
	grunt.loadNpmTasks('grunt-contrib-coffee')
	grunt.loadNpmTasks('grunt-contrib-uglify')

	grunt.registerTask('default', ['concat', 'coffee', 'uglify'])