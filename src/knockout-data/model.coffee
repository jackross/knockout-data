
class kod.Model

	_fields: {}
	_default_field: Object.extended(
		field_type: "String"
		saveable: true
		default: null
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
			values[key] = @_fields[key]['default'] unless values[key]?
			@[key] = ko.observable(values[key])
			@[key].remote_value = ko.observable(values[key])
			@[key].is_dirty = ko.computed(=>
				@[key].remote_value() != @[key]() and @[key]() != null
			)
		)

		@_is_dirty = ko.computed(=>
			for key in @_fields.keys()
				unless ko.isObservable(@[key])
					throw "FIELD '#{key}' ON MODEL '#{@_model_name}' WAS OVERWRITTEN!!!"
				if @[key].is_dirty()
					return true
			return false
		)

		@_set_clean = =>
			@_fields.keys((obj)=>
				@[obj].remote_value(@[obj]())
			)

		@_revert = =>
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

		@_has_many = (model, action='index', _id=null, params=null) ->
			rs = new kod.RecordSet('multiple', model, action, _id, params, {parent_model: @})
			kod.RecordSets.push(rs)
			return rs.accessor

		@_belongs_to = (model, action='show', _id=null, params=null) ->
			rs = new kod.RecordSet('single', model, action, _id, params, {parent_model: @})
			kod.RecordSets.push(rs)
			return rs.accessor
