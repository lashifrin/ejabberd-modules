-record(pg_auth_request,{
			auth_method,
			salt
		}).
		
-record(pg_error,{
			msg
		}).
		
-record(pg_parameter_status,
		{name,
		value
		}).
		
		
-record(pg_backend_key_data,{
			id,
			secret
			}).
			
			
-record(pg_notice_response,{
	notice
	}).


-record(pg_ready_for_query,{
		status
	}).
	
-record(pg_data_row,{
	row
	}).
	
-record(pg_command_complete,{}).
-record(pg_bind_complete,{}).
-record(pg_parse_complete,{}).
-record(pg_row_description,{
		cols %[#pg_col_description{}]
		}).
-record(pg_empty_response,{}).
-record(pg_nodata,{}).
	
	
-record(pg_col_description,{
		name,  %field name
		table, %in witch table is defined (if applicable)
		col_number, %the attribute number of the column in its table (if applicable)
		type,   %field data type
		size,   %size (negative value means variable-length)
		type_modifier,
		format_code
	}).
	
-record(pg_parameters_descriptions, {
        parameters_types
        }).
