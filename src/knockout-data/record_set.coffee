
class kod.RecordSet
	constructor: (rs_type, model, action, _id=null, params=null, options={}) ->

		@rs_type = rs_type
		@model = if ko.isObservable(model) then model else ko.observable(model)
		@action = if ko.isObservable(action) then action else ko.observable(action)
		@_id = if ko.isObservable(_id) then _id else ko.observable(_id)
		@params = if ko.isObservable(params) then params else ko.observable(params)
		@new_record = options['new_record'] ? false
		@parent_model = options['parent_model'] ? null

		@loaded = ko.observable(false)

		@controller = ko.computed(->
			return kod.tabelize(@model())
		, @)

		@rs_id = ko.computed(->
			return md5("#{@rs_type} #{@model()} #{@action()} #{@_id()} #{@params}")
		, @)

		@rest_url = ko.computed(->
			@params() # manually add dependency
			return kod.get_url(@model(), @action(), @_id())
		, @).extend(notify: 'always')

		@rest_url.subscribe(=>
			kod.load_initial_recordset(@)
		)

		if @rs_type is 'single'
			@observable = ko.observable()
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
#					console.log "#{@model()}-#{@action()}-#{@_id()} READ USED=#{@is_used()}"
#					kod.RecordSets.push(@) if kod.RecordSets.none(@) and @is_used()
				if !@loaded() and !@new_record
					kod.load_initial_recordset(@)
				else if @new_record
					@loaded(true)
					@observable(new Models[@model()])
				return @observable()
			deferEvaluation: true
		)

		@subscribers = =>
			return @accessor.getSubscriptionsCount()

		@is_used = =>
			if @parent_model
				if @parent_model._model_name and @parent_model._id()
					if kod.cache_contains(@parent_model._model_name, @parent_model._id())
						return true
			return @subscribers() > 0
