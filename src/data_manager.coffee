$ ->

	window.kod = {}

	kod.RecordSets = Array.create()
	kod.Cache = Object.extended()

	class kod.DataManager

		constructor: ->

			@get_changes = ( =>

				$.ajax(
					'/rest_api/record_changes'
				).then((response)=>

					response = Object.extended(response)

					changed_records = response.reject('deleted')
					deleted_records = response['deleted']

					dirty_controllers = changed_records.keys().unique()

					for controller in dirty_controllers
						model = kod.modelize(controller)
						for record in changed_records[controller]
							if obj = kod.cache_get(model, record)
								obj._merge_clean(record)
							else
								obj = kod.cache_put(model, record)

					#Remove Deleted Records
					for record in deleted_records
						dirty_controllers.push(record.controller)
						kod.cache_remove(kod.modelize(record.controller), record.id)

					#Synchronize Dirty RecordSets that are multiples
					for controller in dirty_controllers
						for rs in kod.RecordSets.findAll((i)-> i.rs_type is 'multiple' and  i.controller() is controller)
							rs.resync()

					#Remove Unused RecordSets
					for rs in kod.RecordSets
						if rs and rs.is_used() == false
							kod.RecordSets.remove(rs)

					used_records = []

					for rs in kod.RecordSets
						if rs.rs_type is 'single'
							used_records.push(rs.observable())
						else
							for obj in rs.observable()
								used_records.push(obj)

					for model in kod.Cache.keys()
						for _id in kod.Cache[model].keys()
							if used_records.none(kod.Cache[model][_id])
								kod.cache_remove(model, _id)
				)

			).every(2000)

			@getData = (model, action, _id, params) ->
				action ?= null
				_id ?= null
				params ?= null
				observable = ko.observableArray()

				$.ajax(
					url: kod.get_url(model, action, _id)
					method: 'get'
					data: @params
				).then((data)=>
					observable(data)
				)

				return observable


			@getUrl = (url, params) ->
				params ?= null
				url = "/rest_api#{url}"
				observable = ko.observableArray()

				$.ajax(
					url: url
					method: 'get'
					data: @params
				).then((data)=>
					observable(data)
				)

				return observable

			@find = (model, action='index', _id=null, params=null) ->
				rs = new kod.RecordSet('multiple', model, action, _id, params)
				kod.RecordSets.push(rs)
				return rs.accessor

			@findOne = (model, action='show', _id=null, params=null) ->
				rs = new kod.RecordSet('single', model, action, _id, params)
				kod.RecordSets.push(rs)
				return rs.accessor

			@createNew = (model) ->
				rs = new kod.RecordSet('single', model, 'show', null, null, true)
				kod.RecordSets.push(rs)
				return rs.accessor

	kod.dm = new kod.DataManager

	class kod.Model

		_fields: {}
		_default_field: Object.extended(
			field_type: "String"
			saveable: true
		)

		constructor: (values={}) ->

			@_model_name = @.constructor.name
			@_controller_name = @_model_name.pluralize().underscore().toLowerCase()
			@_id = ko.observable(values['_id'])
			@_errors = ko.observableArray()

			#Apply defaults to fields
			@_fields.keys((key)=>
				@_fields[key] = Object.extended(@_fields[key])
				@_fields[key].merge(@_default_field, false, false)
			)

			@_fields.keys((key)=>
				values[key] = '' unless values[key] != null
				@[key] = ko.observable(values[key])
				@[key].remote_value = ko.observable(values[key])
				@[key].is_dirty = ko.computed(=>
					@[key].remote_value() != @[key]() and @[key]() != null
				)
			)

			@_is_dirty = ko.computed(=>
				is_dirty = false
				@_fields.keys((obj)=>
					if @[obj].is_dirty()
						is_dirty = true
				)
				return is_dirty
			)

			@_set_clean = =>
				@_fields.keys((obj)=>
					@[obj].remote_value(@[obj]())
				)

			@_reset = =>
				@_fields.keys((obj)=>
					@[obj](@[obj].remote_value())
				)

			@_check_errors = (response) =>
				if Object.has(response, 'meta') and Object.has(response.meta, 'errors')
					@_errors(response.meta.errors)

			@_merge_clean = (new_data) =>
				@_id(new_data['_id'])
				@_fields.keys((key)=>
					if @[key].is_dirty() == false
						@[key](new_data[key])
						@[key].remote_value(new_data[key])
					else
						console.log "#{key} is dirty!!"
						@[key].remote_value(new_data[key])
				)

			@_savable_fields = =>
				saveable_fields = Object.extended(@_fields.findAll((k, v)=> v.saveable)).keys()
				Object.select(@, saveable_fields)

			@_fields_only = =>
				Object.select(@, @_fields.keys().add("_id"))

			@_save = =>
				data = {}
				data[@_controller_name] = ko.toJS(@_savable_fields())
				if @_id()
					rest_url = "/rest_api/#{@_controller_name}/#{@_id()}"
					rest_method = 'put'
				else
					rest_url = "/rest_api/#{@_controller_name}/"
					rest_method = 'post'
				$.ajax(
					url: rest_url
					method: rest_method
					data: data
				).then( (data) =>
					data = Object.extended(data)
					@_check_errors(data)
					@_merge_clean(data[@_controller_name].first())
					kod.cache_put_model(@)
					@_set_clean()
				)

			@_delete = =>
				rest_url = kod.get_url(@_model_name, "destroy", @_id())
				$.ajax(
					url: rest_url
					method: "DELETE"
				).then( (data) =>
					console.log "#{@_model_name}:#{@_id()} - Destroyed"
				)

	class kod.RecordSet
		constructor: (rs_type, model, action, _id=null, params=null, new_record=false) ->

			@rs_type = rs_type
			@model = if ko.isObservable(model) then model else ko.observable(model)
			@action = if ko.isObservable(action) then action else ko.observable(action)
			@_id = if ko.isObservable(_id) then _id else ko.observable(_id)
			@params = if ko.isObservable(params) then params else ko.observable(params)
			@new_record = new_record

			@loaded = ko.observable(false)

			@controller = ko.computed(->
				return kod.tabelize(@model())
			, @)

			@rest_url = ko.computed(->
				@params() # manually add dependency
				return kod.get_url(@model(), @action(), @_id())
			, @).extend(notify: 'always')

			@rest_url.subscribe(=>
				kod.load_initial_recordset(@)
			)

			if @rs_type is 'single'
				@observable = ko.observable(new Models[@model()])
				@observable()._id.subscribe((id)=>
					console.log "ID changed: #{id}"
					@_id(id) unless @_id()
					@new_record = false
				)
			else
				@observable = ko.observableArray()
				@resync = =>
					$.ajax(
						url: @rest_url()
						method: 'get'
						data: @params()
					).then(
						(data) =>
							obj_list = []
							for obj in data[@controller()]
								obj = kod.cache_put(@model(), obj)
								obj_list.push(obj)
							for obj in obj_list
								if @observable().none(obj)
									@observable.push(obj)
							for obj in @observable()
								if obj_list.none(obj)
									@observable.remove(obj)
					)

			@accessor = ko.computed(
				read: =>
					if !@loaded() and !@new_record
						kod.load_initial_recordset(@)
					return @observable()
				deferEvaluation: true
			)

			@subscribers = =>
				return @accessor.getSubscriptionsCount()

			@is_used = =>
				return @subscribers() > 0

	kod.rest_path = "/rest_api"

	kod.new_key = ->
		return md5("#{Date.now()}#{Math.random()}")

	kod.get_endpoint = (model, action, _id, params) ->
		return md5("#{model} #{action} #{_id} #{JSON.stringify(params)}")

	kod.get_url = (model, action, _id) ->
		url = ""
		controller = @tabelize(model)
		if action is "index" or action is null
			url = "/#{controller}"
		else if action is "show" or action is "destroy"
			url = "/#{controller}/#{_id}"
		else
			if _id
				url = "/#{controller}/#{_id}/#{action}"
			else
				url = "/#{controller}/#{action}"
		return "#{kod.rest_path}#{url}"

	kod.tabelize = (model) ->
		return model.pluralize().underscore().toLowerCase()

	kod.modelize = (controller) ->
		return controller.camelize().singularize().capitalize()

	kod.cache_put = (model, record) ->
		unless kod.Cache.has(model)
			kod.Cache[model] = Object.extended()

		unless Object.isObject(record)
			throw "record must be object"

		obj = null
		if kod.Cache[model].has(record._id)
			obj = kod.Cache[model][record._id]
			obj._merge_clean(record)
		else
			obj = kod.Cache[model][record._id] = new Models[model](record)
		return obj

	kod.cache_put_model = (model) ->
		unless kod.Cache.has(model._model_name)
			kod.Cache[model._model_name] = Object.extended()

		return kod.Cache[model._model_name][model._id()] = model

	kod.cache_get = (model, record) ->
		unless kod.Cache.has(model)
			kod.Cache[model] = Object.extended()

		if Object.isString(record)
			key = "#{record}"
		else if Object.isObject(record)
			key = "#{record._id}"
		else
			throw "record must be object or string"
		if kod.Cache[model].has(key)
			return kod.Cache[model][key]
		else
			return false

	kod.cache_remove = (model, record) ->
		unless kod.Cache.has(model)
			kod.Cache[model] = Object.extended()

		if Object.isString(record)
			key = "#{record}"
		else if Object.isObject(record)
			key = "#{record._id}"
		else
			throw "record must be object or string"
		if kod.Cache[model].has(key)
			delete kod.Cache[model][key]
			return true
		else
			return false

	kod.load_initial_recordset = (rs) ->
		if rs.rs_type is 'single'
			if rs._id()
				if obj = kod.cache_get(rs.model(), rs._id())
					rs.observable(obj)
					return
			$.ajax(
				url: rs.rest_url()
				method: 'get'
				data: rs.params()
			).then(
				(data) =>
					obj = null
					data[kod.tabelize(rs.model())].forEach((record)=>
						obj = kod.cache_put(rs.model(), record)
					)
					rs.observable(obj)
			)
		else
			$.ajax(
				url: rs.rest_url()
				method: 'get'
				data: rs.params()
			).then(
				(data) =>
					obj_list = []
					data[kod.tabelize(rs.model())].forEach((record)=>
						obj = kod.cache_put(rs.model(), record)
						obj_list.push(obj)
					)
					rs.observable(obj_list)
			)
		rs.loaded(true)