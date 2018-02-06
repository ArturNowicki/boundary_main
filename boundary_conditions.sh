#!/bin/bash
# Created by Artur Nowicki on 06.02.2018.
ok_status=0
err_missing_program_input=100
err_f_open=101
err_f_read=102
err_f_write=103
err_f_close=104
err_memory_alloc=105

kmt_file='../../data/grids/2km/kmt_2km.ieeer8'
angle_file1='../../data/grids/2km/anglet_2km.ieeer8'
thickness_file='../../data/grids/2km/thickness_2km_600x640.txt'

in_model_nc_prefix='hydro.pop.h.'
x_in=600
y_in=640
z_in=21

nc_in_dir='../../data/boundary_conditions/tmp_in_data/'
bin_tmp_dir='../../data/boundary_conditions/tmp_bin_data/'
bin_spread_dir='../../data/boundary_conditions/spread_data/'
bin_out_dir='../../data/boundary_conditions/out_data/'
parameters_list=( 'TEMP' 'SALT' 'UVEL' 'VVEL' 'SSH')
params_to_avg_in=( 'UVEL' 'VVEL')
params_to_avg_out=( 'SU' 'SV')

if [[ $1 == 'compile' ]]; then
	echo "Compile netcdf_to_bin.f90."
	gfortran ../common_code/messages.f90 ../common_code/error_codes.f90 -I/opt/local/include ../netcdf_to_binary/netcdf_to_bin.f90 -o netcdf_to_bin -L/opt/local/lib -lnetcdff -lnetcdf
	if [[ $? -ne 0 ]]; then
		exit
	fi
	echo "Compile average_over_depth.f90."
	gfortran ../average_over_depth/average_over_depth.f90 -o average_over_depth
	if [[ $? -ne 0 ]]; then
		exit
	fi
	echo "Compile rotate_vector_matrix."
	gfortran ../rotate_vector/rotate_vector_matrix.f90 -o rotate_vector_matrix
	if [[ $? -ne 0 ]]; then
		exit
	fi
	echo "Compile poisson_solver.f90."
	gfortran ../poisson_solver/poisson_solver.f90 -o poisson_solver
	if [[ $? -ne 0 ]]; then
		exit
	fi
else
	if [[ ! -f netcdf_to_bin || ! -f average_over_depth || ! -f rotate_vector_matrix  || ! -f poisson_solver ]]; then
		echo "Compile all needed modules first!"
		exit
	fi
	echo "Converting to binary files"
	for in_fpath in ${nc_in_dir}*'.nc'; do
		in_file=${in_fpath/${nc_in_dir}}
		date_time=${in_file/${in_model_nc_prefix}}
		date_time=${date_time/'.nc'}
		echo $date_time
		for parameter_name in "${parameters_list[@]}"
			do
			echo ${parameter_name}
			# ./netcdf_to_bin ${in_fpath} ${parameter_name} ${date_time} ${bin_tmp_dir}
		done
	done
	echo "Calculate SU and SV"
	for ii in 0 1; do
		parameter_name=${params_to_avg_in[${ii}]}
		for in_f in ${bin_tmp_dir}*${parameter_name}*; do
			in_file=${in_f/${bin_tmp_dir}}
			IFS='_' read -r date_time rest_f_name <<< "$in_file"
			tmp_str=${date_time}'_'${params_to_avg_out[${ii}]}${rest_f_name:${#parameter_name}}
			out_file="${tmp_str/0021/0001}"
			echo "-------------------"
			echo ${in_file} ${out_file}
			# ./average_over_depth ${bin_tmp_dir} ${in_file} ${out_file} ${thickness_file} ${kmt_file}
		done
	done
	echo "Rotate SU and SV"
	for in_file1 in ${bin_tmp_dir}*${params_to_avg_out}*; do
		in_file2="${in_file1/${params_to_avg_out[0]}/${params_to_avg_out[1]}}"
		# ./rotate_vector_matrix ${in_file1} ${in_file2} ${in_file1} ${in_file2} ${angle_file1}
	done
	for var_name in ${params_to_avg_in[@]}; do
		rm ${bin_tmp_dir}*$var_name*
	done
	echo "Poisson solver"
	for in_file in ${bin_tmp_dir}*; do
		out_file=${bin_spread_dir}${in_file/${bin_tmp_dir}}
		echo ${out_file}
		z_dim_str=${out_file:(-16):4}
		let z_dim=10#${z_dim_str}
		./poisson_solver ${in_file} ${out_file} ${x_in} ${y_in} ${z_dim}
	done
fi