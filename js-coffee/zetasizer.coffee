fs = require 'fs'
path = require 'path'
crypto = require 'crypto'

async = require 'async'

SIZE_DISTRIBUTION_MAX = 70
ZETA_DISTRIBUTION_MAX = 81

supportModes = ['merged', 'separate', 'permeasurement']
supportOpes = {
	n: {name: 'Size distribution by Number ', table_header: 'Number (%)', sname: 'size-number', type: 'size', requireField: 'numbers'},
	i: {name: 'Size distribution by Intensity', table_header: 'Intensity (%)', sname: 'size-intensity', type: 'size', requireField: 'volumes'},
	v: {name: 'Size distribution by Volume', table_header: 'Volume (%)', sname: 'size-volume', type: 'size', requireField: 'intensities'},
	z: {name: 'Zeta potential Distribution', table_header: 'Intensity', sname: 'zeta', type: 'zeta', requireField: 'intensities'}
}
outputPath = ''

zs_records = []

parseData = (files, cb) ->
	# if typeof files isnt 'array'
	# 	files = [files]
	zs_records = []
	async.each files, parseDataSingle, (err) ->
		if err
			console.error err
			cb null
		else
			if zs_records.length
				cb zs_records
			else
				cb null

parseDataSingle = (file, cb) ->
	file = file.toString() if typeof file isnt 'string'
	fs.exists file, (exists) ->
		if not exists
			console.error "File #{file} not found."
			cb "file #{file} not found"
		else
			outputPath = path.dirname file
			fs.readFile file, (err, data) ->
				if err
					console.error err
					cb err
				else
					lines = data.toString().replace(/\r\n/g,'\n').split('\n')
					th = lines.shift()
					# now let's see what we have
					fields = th.split('\t')
					idf = (fieldname) ->
						return fields.indexOf(fieldname)
					getcol = (row, fieldname) ->
						if idf(fieldname) isnt -1
							return row[idf(fieldname)]
						else
							return null
					ID = 0
					for line in lines
						record = {}
						row = line.split('\t')
						ID++
						r_type = getcol row, 'Type'
						r_type = r_type.toLowerCase() if r_type
						if r_type not in ['size', 'zeta'] then continue
						record['ID'] = ID
						record['type'] = r_type
						record['name'] = getcol row, 'Sample Name'
						record['swVersion'] = getcol row, 'S/W Version'
						record['serialNumber'] = getcol row, 'Serial Number'
						record['date'] = getcol row, 'Measurement Date and Time'

						if record.date isnt null
							record.date = Date.parse(record.date)
						switch record.type
							when 'size'
								record['numberMean'] = parseFloat(getcol row, 'Number Mean (d.nm)')
								record['intensityMean'] = parseFloat(getcol row, 'Intensity Mean (d.nm)')
								record['volumeMean'] = parseFloat(getcol row, 'Volume Mean (d.nm)')
								record['zAverage'] = parseFloat(getcol row, 'Z-Average (d.nm)')
								record['pdi'] = parseFloat(getcol row, 'PdI')
								stat_sizes = true
								stat_numbers = true
								stat_intensities = true
								stat_volumes = true
								record['sizes'] = []
								record['numbers'] = []
								record['intensities'] = []
								record['volumes'] = []
								record['']
								for i in [1...SIZE_DISTRIBUTION_MAX+1]
									if stat_sizes
										if idf('Sizes['+i+'] (d.nm)') isnt -1
											record.sizes.push parseFloat(getcol row, 'Sizes['+i+'] (d.nm)')
										else
											stat_sizes = false
									if stat_numbers
										if idf('Numbers['+i+'] (Percent)') isnt -1
											record.numbers.push parseFloat(getcol row, 'Numbers['+i+'] (Percent)')
										else
											stat_numbers = false
									if stat_intensities
										if idf('Intensities['+i+'] (Percent)') isnt -1
											record.intensities.push parseFloat(getcol row, 'Intensities['+i+'] (Percent)')
										else
											stat_intensities = false
									if stat_volumes
										if idf('Volumes['+i+'] (Percent)') isnt -1
											record.volumes.push parseFloat(getcol row, 'Volumes['+i+'] (Percent)')
										else
											stat_volumes = false
								for key in ['sizes', 'numbers', 'intensities', 'volumes']
									if record[key].length is 0
										record[key] = null

							when 'zeta'
								record['zetaPotential'] = parseFloat(getcol row, 'Zeta Potential (mV)')
								record['mobility'] = parseFloat(getcol row, 'Mobility (�mcm/Vs)')
								record['conductivityt'] = parseFloat(getcol row, 'Conductivity (mS/cm)')
								# very dirty since the zetasizer soft cannot export correct format
								record['intensities'] = []
								record['zetaPotentials'] = []
								for i in [1...ZETA_DISTRIBUTION_MAX+1]
									record.intensities.push parseFloat row[16+i]
									record.zetaPotentials.push parseInt row[16+ZETA_DISTRIBUTION_MAX+i]
						for key in record
							delete record[key] if record[key] is null
						zs_records.push record
					cb()

exportData = (data, mode, range, cb) ->

	err = []
	files = []
	if not data
		err.push 'No data provided'
		cb err, files
		return false
	if not mode of supportModes
		err.push 'Mode ' + mode + ' is not supported'
		cb err, files
		return false
	if not range || not Array.isArray(range)
		err.push 'Illegal range provided.'
		cb err, files
		return false

	write_queue = {}
	write_queue_hashs = []

	isValidOpe = (row, ope) ->
		return false unless row
		unless ope of supportOpes
			console.error 'Unsupport OPE '+ope+ ' for Measurement ' + row.name
			err.push 'Unsupport OPE '+ope+ ' for Measurement ' + row.name
			return false
		ope = supportOpes[ope]
		try
			if row.type is ope.type and ope.requireField of row
				return true
			else
				return false
		catch error
			console.error error
			err.push error
			return false

	sanitizeFilename = (s, length=null) ->
		# remove undesired characters
		s = s.replace(/[^a-zA-Z0-9\-\s]/g,'').toLowerCase()
		# replace " " to "-"
		s = s.trim().replace(/\s+/g, " ").trim().replace(/\s/g, '-')
		if length
			s = s.substring(0, length).replace(/\-$/, '')
		return s

	fileName = (row, ope) ->
		return null unless isValidOpe row, ope
		filename = ''
		d = new Date()
		nowDate = '['+d.getFullYear()+'-'+(d.getMonth()+1)+'-'+d.getDate()+']'
		try
			type = row.type
			ope = supportOpes[ope]
			switch mode
				when 'merged'
					filename += type
				when 'separate'
					filename += '[' + row.ID + ']' + ope.sname + '-' + sanitizeFilename row.name
				when 'permeasurement'
					filename += '[' + row.ID + ']' + type + '-' + sanitizeFilename row.name
			filename = nowDate + filename + '.csv'
			return filename

		catch e
			err.push e
			return null


	fileHash = (row, ope) ->
		sha = crypto.createHash('sha1')
		fn = fileName row, ope
		return null unless fn
		sha.update fn
		return sha.digest('hex')
		
	getRow = (ID) ->
		for row in data
			if row.ID is ID
				return row
		console.error "ITEM " + ID + " does not exists."
		err.push "ITEM " + ID + " does not exists."
		return null
	
	writeToFile = (hash) ->
		write_queue_hashs.push hash

	removeHashFromWriteQueue = (hash) ->
		index = write_queue_hashs.indexOf hash
		write_queue_hashs.splice index, 1

	_writeToFile = (hash, _callback) ->
		my_err = ''
		unless hash of write_queue
			console.error "HASH["+hash+"] is not valid."
			my_err = "HASH["+hash+"] is not valid."
			# removeHashFromWriteQueue hash
			_callback my_err
			return false
		unless write_queue[hash].ready
			console.error "Data not ready. (Measurement " + write_queue[hash].name + ", Original Command: " + write_queue[hash].orig_cmd + ", Current OPEs: " + write_queue[hash].opes.join(", ") + "."
			my_err = "Data not ready. (Measurement " + write_queue[hash].name + ", Original Command: " + write_queue[hash].orig_cmd + ", Current OPEs: " + write_queue[hash].opes.join(", ") + "."
			# removeHashFromWriteQueue hash
			_callback my_err
			return false
		filename = path.resolve outputPath, write_queue[hash].filename
		fs.exists filename, (exists) ->
			if exists
				console.error "File " + filename + " already exists. Abort exporting."
				my_err = "File " + filename + " already exists. Abort exporting."
				# removeHashFromWriteQueue hash
				_callback my_err
			else
				content = ''
				content += write_queue[hash].table.header.join(",") + '\n'
				max_row_no = 0
				for col in write_queue[hash].table.cols
					max_row_no = col.length if max_row_no < col.length

				cols_no = write_queue[hash].table.cols.length
				for i in [0...max_row_no]
					row = []
					for j in [0...cols_no]
						try
							row.push write_queue[hash].table.cols[j][i]
						catch e
							row.push null
					content += row.join(',') + '\n'
				fs.writeFile filename, content, (err) ->
					# removeHashFromWriteQueue hash
					if err
						console.error "Export file " + filename + " failed. Reason: " + err
						my_err = "Export file " + filename + " failed. Reason: " + err
						_callback my_err
						return false;
					else
						files.push filename
						console.log "Export file " + filename + ' successfully.'
						_callback null


	processCMD = (cmd, callback) ->
		[cmd,ID,opes] = cmd.match /(\d+)(\w+)/
		ID = parseInt ID
		opes = opes.split ''
		row = getRow ID
		funcProcCMD = (paras, _callback) ->
			[_cmd, ope, _row] = paras
			f_hash = fileHash _row, ope
			unless f_hash
				return false
			unless f_hash of write_queue
				write_queue[f_hash] = {
					name: _row.name
					opes: []
					orig_cmd: _cmd
					filename: fileName _row, ope
					table: {
						header: []
						cols: []
					}
					ready: false
				}

				switch _row.type
					when 'size'
						write_queue[f_hash].table.header.push 'Particle Size (nm)'
						write_queue[f_hash].table.cols.push _row.sizes

			_ope = supportOpes[ope]
			write_queue[f_hash].opes.push _ope.name
			
			if ope is 'z'
				write_queue[f_hash].table.header.push (if mode is 'merged' then "["+_row.name+"]" else '') + 'Zeta Potential (mV)'
				write_queue[f_hash].table.cols.push _row.zetaPotentials

			write_queue[f_hash].table.header.push (if mode is 'merged' then "["+_row.name+"]" else '') + _ope.table_header
			write_queue[f_hash].table.cols.push _row[_ope.requireField]
			
			if mode is 'separate'
				write_queue[f_hash].ready = true
				writeToFile f_hash

			_callback null

		paras = []
		for _o in opes
			paras.push [ID, _o, row]

		async.each paras, funcProcCMD, (e) ->
			if mode is 'permeasurement'
				f_hash = fileHash row, opes[0]
				write_queue[f_hash].ready = true
				writeToFile f_hash

			callback e

	async.each range, processCMD, (e) ->
		if mode is 'merged'
			for f_hash of write_queue
				write_queue[f_hash].ready = true
				writeToFile f_hash
		if e
			err.push e

		async.each write_queue_hashs, _writeToFile, (e) ->
			if e
				err.push e

			cb err, files





exports.parseData = parseData
exports.exportData = exportData
exports.supportModes = supportModes
exports.outputPath = outputPath

# test = ->
# 	file = ['test', 'zeta-AOx1_2.csv']
# 	parseData file, (r) ->
# 		console.log  JSON.stringify(r)

# test()