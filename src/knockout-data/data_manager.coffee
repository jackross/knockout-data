
kod.dm = (->

	get_changes = ( =>
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
				if rs
					if not rs.is_used()
	#								console.log "[RS] #{rs.rs_type}: Model:#{rs.model()} - Action:#{rs.action()} - ID:#{rs._id()} - accessor:#{rs.accessor.getSubscriptionsCount()}"
						kod.RecordSets.remove(rs)

			used_records = []

			for rs in kod.RecordSets
				if rs.observable()
					if rs.rs_type is 'single'
						used_records.push("#{rs.model()}:#{rs.observable()._id()}")
					else
						for obj in rs.observable()
							used_records.push("#{rs.model()}:#{obj._id()}")

			for model in kod.Cache.keys()
				for _id in kod.Cache[model].keys()
					if used_records.none("#{model}:#{_id}")
						kod.cache_remove(model, _id)
		)

	).every(2500)

	return {
		getData: (model, action, _id, params) ->
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

		getUrl: (url, params) ->
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

		find: (model, action='index', _id=null, params=null) ->
			rs = new kod.RecordSet('multiple', model, action, _id, params)
			kod.RecordSets.push(rs)
			return rs.accessor

		findOne: (model, action='show', _id=null, params=null) ->
			rs = new kod.RecordSet('single', model, action, _id, params)
			kod.RecordSets.push(rs)
			return rs.accessor

		createNew: (model) ->
			rs = new kod.RecordSet('single', model, 'show', null, null, {new_record: true})
			kod.RecordSets.push(rs)
			return rs.accessor
	}
)()