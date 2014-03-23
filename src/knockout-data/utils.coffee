
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

kod.cache_contains = (model, id) ->
	if kod.Cache[model]?[id]?
		return true
	else
		return false

kod.load_initial_recordset = (rs) ->
	if rs.rs_type is 'single'
		rs.observable(new Models[rs.model()])
		rs.observable()._id.subscribe((id)=>
			console.log "ID changed: #{id}"
			rs._id(id) unless rs._id()
			rs.new_record = false
		)
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