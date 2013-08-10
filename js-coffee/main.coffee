zs = require './js/zetasizer.js'
gui = require 'nw.gui'
path = require 'path'

resize_func = ->
	$('.viewports').css {height: $(window).height(), width: $(window).width()}
	$('#slides').css {width: $('.viewports').width()*$('li','#slides').length}
	$('li','#slides').css {width: $('.viewports').width()}
	$('#dropzone p').css {'line-height': $('#dropzone p').height()+'px'}
	$('#records').css {'height': ($('.viewports').height()-70) + 'px'}

gen_record = (data) ->
	rst = ''
	for item in data
		tmp_itemkeys = Object.keys item
		tmpl = '<tr id="record-'+item.ID+'" rel="type-'+item.type+'">'
		tmpl += '<td class="sel">'
		tmpl += '<input type="checkbox" id="chk-'+item.ID+'" class="r_chk" value="'+item.ID+'" />'
		tmpl += '</td><td class="name">'
		tmpl += item.name
		tmpl += '</td><td class="date">'
		tmp_date = new Date(item.date)
		tmpl += tmp_date.getDate() + '/' + (tmp_date.getMonth()+1) + '/' + tmp_date.getFullYear() + ' ' + tmp_date.getHours() + ":"+ tmp_date.getMinutes()
		tmpl += '</td><td class="info">'
		tmpl += 'Type: <strong>'+item.type+'</strong>; '
		if item.type is 'size'
			tmp_dias = []
			dia_keys = ['numberMean', 'intensityMean', 'volumeMean']
			for key in dia_keys
				dia_title = switch key
					when 'numberMean' then '(number)'
					when 'intensityMean' then '(intensity)'
					when 'volumeMean' then '(volume)'
				if key in tmp_itemkeys and item[key]
					tmp_dias.push item[key] + " nm " + dia_title
			if tmp_dias.length
				tmpl += "Mean diameter: " + tmp_dias.join('; ') + '.'
		else if item.type is 'zeta'
			tmp_pot = []
			dia_keys = ['zetaPotential', 'mobility', 'conductivity']
			for key in dia_keys
				if key in tmp_itemkeys and item[key]
					switch key
						when 'zetaPotential'
							tmp_pot.push 'Zeta Potential: ' + item[key] + ' mV'
						when 'mobility'
							tmp_pot.push 'Mobility: ' + item[key] + ' µmcm/Vs'
						when 'conductivity'
							tmp_pot.push 'Conductivity: ' + item[key] + ' mS/cm'
			if tmp_pot.length
				tmpl += tmp_pot.join('; ')+'.'
		tmpl += '</td><td class="ope"><div class="export-sel" id="export-sel-'+item.ID+'">'
		tmp_ope = []
		if item.type is 'size'
			for key in ['numbers', 'intensities', 'volumes']
				if key in tmp_itemkeys and item[key] isnt null and item[key].length
					tmp_ope.push '<input class="ope_checkbox size-'+key+'" type="checkbox" rel="size-'+key+'" name="size-'+key+'" id="size-'+key+'-'+item.ID+'" value="'+item.ID+'" /><label for="size-'+key+'-'+item.ID+'">'+key+'</label>'
			if tmp_ope.length
				tmpl += tmp_ope.join("<br />")
		else if item.type is 'zeta'
			if 'intensities' in tmp_itemkeys and item['intensities'] isnt null and 'zetaPotentials' in tmp_itemkeys and item['zetaPotentials'] and item.intensities.length is item.zetaPotentials.length
				tmpl += '<input class="ope_checkbox zeta-intensities" type="checkbox" rel="zeta-intensities" name="zeta-intensities" id="zeta-intensities-'+item.ID+'" value="'+item.ID+'" /><label for="zeta-intensities-'+item.ID+'">zeta potentials</label>'
		tmpl += '</div>'
		tmpl += '<input type="hidden" class="ITEMCFG" id="ITEMCFG-'+item.ID+'" name="ITEMCFG" value="" />'
		tmpl += '</td></tr>'
		rst += tmpl
	return rst


$(window).on 'dragover', (e) ->
	e.preventDefault()
	return false

$(window).on 'drop', (e) ->
	e.preventDefault()
	return false



$(window).resize ->
	resize_func()

$(window).load ->
	resize_func()
	window['records'] = []

	$('.external-link').click (e) ->
		e.preventDefault()
		gui.Shell.openExternal $(this).attr('href')
	$('.start-over').click (e) ->
		window['records'] = []
		e.preventDefault()
		$('#slides').animate {left: 0}, 300, 'swing'

	$('.record-sel-btn').click (e) ->
		e.preventDefault()
		records = $('#record-table')
		switch $(this).prop('rel')
			when 'all'
				$('.r_chk', records).prop('checked', true).change()

			when 'size'
				$('.r_chk', records).prop('checked', false).change()
				$('.r_chk', 'tr[rel=type-size]').prop('checked', true).change()
			when 'size-number'
				$('.r_chk', records).prop('checked', false).change()
				$('.size-numbers').prop('checked', true).change()
			when 'size-intensity'
				$('.r_chk', records).prop('checked', false).change()
				$('.size-intensities').prop('checked', true).change()
			when 'size-volume'
				$('.r_chk', records).prop('checked', false).change()
				$('.size-volumes').prop('checked', true).change()
			when 'zeta'
				$('.r_chk', records).prop('checked', false).change()
				$('.r_chk', 'tr[rel=type-zeta]').prop('checked', true).change()
			when 'none'
				$('.r_chk', records).prop('checked', false).change()
	
	$('#generate-data').click (e)->
		e.preventDefault()
		range = []
		$('.ITEMCFG').each ->
			range.push $(this).val() if $(this).val()
		return false unless range.length
		mode = $('.radio-export:checked').val()
		unless mode in zs.supportModes
			mode = 'merged'
		zs.exportData window.records, mode, range, (err, files) ->
			$('#slides').animate {left: "-200%"}, 300, 'swing', ->
				window['gen_files'] = files				

	$('#reveal-in-finder').click (e) ->
		e.preventDefault()
		dst_folders = []
		for $f in window.gen_files
			$p = path.dirname $f
			if dst_folders.indexOf($p) is -1
				dst_folders.push $p
				gui.Shell.showItemInFolder $f


	# drag and drop
	dz = $('#dropzone p')
	dz.on 'dragover', ->
		$('#dropzone').addClass 'hover'

	dz.on 'dragend', ->
		$('#dropzone').removeClass 'hover'

	dz.on 'dragleave', ->
		$('#dropzone').removeClass 'hover'

	dz.on 'drop', (e) ->
		e.preventDefault()
		$('#dropzone').removeClass 'hover'
		orig_dropzone_text = $('#dropzone p').html()
		$('#dropzone p').html 'Analyzing, please wait...'		
		
		succ = true
		files = e.originalEvent.dataTransfer.files
		file_list = []
		for file in files
			file_list.push file.path.toString()
		# emulating data here
		# $.getJSON 'js/a.json', (data) ->
		zs.parseData file_list, (data) ->
			if data is null
				succ = false
			else
				window.records = data
				$('#record-table').html gen_record(data)
				
				record_no = $('tr', '#record-table').length
				$('#data-length').html record_no  + if record_no is 1 then " record" else " records" + " found (Size: "+$('tr[rel=type-size]', '#record-table').length+"; Zeta: "+$('tr[rel=type-zeta]', '#record-table').length+")."
				makeCMD = (id) ->
					cmd = ""
					record = $('#record-'+id)
					if $('.r_chk', record).prop('checked')
						cmd += id.toString()
						$('.ope_checkbox', record).each ()->
							if this.checked
								switch $(this).attr('rel')
									when 'size-numbers' then cmd += 'n'
									when 'size-intensities' then cmd += 'i'
									when 'size-volumes' then cmd += 'v'
									when 'zeta-intensities' then cmd += 'z'
									else
										console.log $(this)
					$('#ITEMCFG-'+id).val cmd


				$('.r_chk').on 'change', (e) ->
					id = $(this).val()
					$('.ope_checkbox', '#export-sel-'+id).prop 'checked', this.checked
					$('#record-'+id).toggleClass 'selected', this.checked
					makeCMD id

				$('.ope_checkbox').on 'change', (e) ->
					id = $(this).val()
					should_check = false
					$('.ope_checkbox', '#record-'+id).each ()->
						should_check = true if this.checked
					$('.r_chk', '#record-'+id).prop 'checked', should_check
					$('#record-'+id).toggleClass 'selected', should_check
					makeCMD id

				$('#slides').animate {left: "-100%"}, 300, 'swing', ->
					$('#dropzone p').html orig_dropzone_text

			if not succ
				$('#slides').animate {left: "-300%"}, 300, 'swing', ->
					$('#dropzone p').html orig_dropzone_text

		return false;
