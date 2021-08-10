#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions file and the bash utility functions.
#
#-----------------------------------------------------------------------
#
. ${GLOBAL_VAR_DEFNS_FP}
. $USHDIR/source_util_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
scrfunc_fn=$( basename "${scrfunc_fp}" )
scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Print message indicating entry into script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Entering script:  \"${scrfunc_fn}\"
In directory:     \"${scrfunc_dir}\"

This is the ex-script for the task that runs the post-processor (UPP) on
the output files corresponding to a specified forecast hour.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( \
"cdate" \
"run_dir" \
"postprd_dir" \
"comout" \
"fhr_dir" \
"fhr" \
"tmmark" \
)
process_args valid_args "$@"
#
#-----------------------------------------------------------------------
#
# For debugging purposes, print out values of arguments passed to this
# script.  Note that these will be printed out only if VERBOSE is set to
# TRUE.
#
#-----------------------------------------------------------------------
#
print_input_args valid_args
#
#-----------------------------------------------------------------------
#
# Load modules.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

  "WCOSS_CRAY")

# Specify computational resources.
    export NODES=2
    export ntasks=48
    export ptile=24
    export threads=1
    export MP_LABELIO=yes
    export OMP_NUM_THREADS=$threads

    APRUN="aprun -j 1 -n${ntasks} -N${ptile} -d${threads} -cc depth"
    ;;

  "WCOSS_DELL_P3")

# Specify computational resources.
    export NODES=2
    export ntasks=48
    export ptile=24
    export threads=1
    export MP_LABELIO=yes
    export OMP_NUM_THREADS=$threads

    APRUN="mpirun"
    ;;

  "HERA")
    APRUN="srun"
    ;;

  "ORION")
    ulimit -s unlimited
    ulimit -a
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=1024M
    APRUN="srun"
    ;;

  "JET")
    APRUN="srun"
    ;;

  "ODIN")
    APRUN="srun -n 1"
    ;;

  "CHEYENNE")
    module list
    nprocs=$(( NNODES_RUN_POST*PPN_RUN_POST ))
    APRUN="mpirun -np $nprocs"
    ;;

  "STAMPEDE")
    nprocs=$(( NNODES_RUN_POST*PPN_RUN_POST ))
    APRUN="ibrun -n $nprocs"
    ;;

  *)
    print_err_msg_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN = \"$APRUN\""
    ;;

esac
#
#-----------------------------------------------------------------------
#
# Remove any files from previous runs and stage necessary files in fhr_dir.
#
#-----------------------------------------------------------------------
#
rm_vrfy -f fort.*
cp_vrfy ${EMC_POST_DIR}/parm/nam_micro_lookup.dat ./eta_micro_lookup.dat
ln_vrfy -snf ${FIX_CRTM}/*bin ./
if [ ${USE_CUSTOM_POST_CONFIG_FILE} = "TRUE" ]; then
  post_config_fp="${CUSTOM_POST_CONFIG_FP}"
  post_params_fp="${CUSTOM_POST_PARAMS_FP}"
  print_info_msg "
====================================================================
Copying the user-defined post flat file specified by CUSTOM_POST_CONFIG_FP
to the post forecast hour directory (fhr_dir):
  CUSTOM_POST_CONFIG_FP = \"${CUSTOM_POST_CONFIG_FP}\"
  CUSTOM_POST_PARAMS_FP = \"${CUSTOM_POST_PARAMS_FP}\"
  fhr_dir = \"${fhr_dir}\"
===================================================================="
else
  post_config_fp="${EMC_POST_DIR}/parm/postxconfig-NT-fv3lam.txt"
  post_params_fp="${EMC_POST_DIR}/parm/params_grib2_tbl_new"
  print_info_msg "
====================================================================
Copying the default post flat file specified by post_config_fp to the post
forecast hour directory (fhr_dir):
  post_config_fp = \"${post_config_fp}\"
  post_params_fp = \"${post_params_fp}\"
  fhr_dir = \"${fhr_dir}\"
===================================================================="
fi
cp_vrfy ${post_config_fp} ./postxconfig-NT.txt
cp_vrfy ${post_params_fp} ./params_grib2_tbl_new
cp_vrfy ${EXECDIR}/upp.x .
if [ -f ${FFG_DIR}/latest.FFG ] && [ ${NET} = "RRFS_CONUS" ]; then
  cp_vrfy ${FFG_DIR}/latest.FFG .
  grid_specs_rrfs="lambert:-97.5:38.500000 237.826355:1746:3000 21.885885:1014:3000"
  wgrib2 latest.FFG -match "0-12 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_12h.grib2
  wgrib2 latest.FFG -match "0-6 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_06h.grib2
  wgrib2 latest.FFG -match "0-3 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_03h.grib2
  wgrib2 latest.FFG -match "0-1 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_01h.grib2
elif [ -f ${FFG_DIR}/latest.FFG ] && [ ${NET} = "RRFS_NA_3km" ]; then
  cp_vrfy ${FFG_DIR}/latest.FFG .
  grid_specs_rrfs="rot-ll:248.000000:-42.000000:0.000000 309.000000:4081:0.025000 -33.0000000:2641:0.025000"
  wgrib2 latest.FFG -match "0-12 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_12h.grib2
  wgrib2 latest.FFG -match "0-6 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_06h.grib2
  wgrib2 latest.FFG -match "0-3 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_03h.grib2
  wgrib2 latest.FFG -match "0-1 hour" -end -new_grid_interpolation bilinear -new_grid_winds grid -new_grid ${grid_specs_rrfs} ffg_01h.grib2
fi
#
#-----------------------------------------------------------------------
#
# Get the cycle date and hour (in formats of yyyymmdd and hh, respectively)
# from cdate.
#
#-----------------------------------------------------------------------
#
yyyymmdd=${cdate:0:8}
hh=${cdate:8:2}
cyc=$hh
#
#-----------------------------------------------------------------------
#
# Create a text file (itag) containing arguments to pass to the post-
# processing executable.
#
#-----------------------------------------------------------------------
#
dyn_file="${run_dir}/dynf${fhr}.nc"
phy_file="${run_dir}/phyf${fhr}.nc"

post_time=$( date --utc --date "${yyyymmdd} ${hh} UTC + ${fhr} hours" "+%Y%m%d%H" )
post_yyyy=${post_time:0:4}
post_mm=${post_time:4:2}
post_dd=${post_time:6:2}
post_hh=${post_time:8:2}

cat > itag <<EOF
${dyn_file}
netcdf
grib2
${post_yyyy}-${post_mm}-${post_dd}_${post_hh}:00:00
${POST_FULL_MODEL_NAME}
${phy_file}

 &NAMPGB
 KPO=47,PO=1000.,975.,950.,925.,900.,875.,850.,825.,800.,775.,750.,725.,700.,675.,650.,625.,600.,575.,550.,525.,500.,475.,450.,425.,400.,375.,350.,325.,300.,275.,250.,225.,200.,175.,150.,125.,100.,70.,50.,30.,20.,10.,7.,5.,3.,2.,1.,
 /
EOF
#
#-----------------------------------------------------------------------
#
# Copy the UPP executable to fhr_dir and run the post-processor.
#
#-----------------------------------------------------------------------
#
print_info_msg "$VERBOSE" "
Starting post-processing for fhr = $fhr hr..."

${APRUN} ./upp.x < itag || print_err_msg_exit "\
Call to executable to run post for forecast hour $fhr returned with non-
zero exit code."
#
#-----------------------------------------------------------------------
#
# Move (and rename) the output files from the work directory to their
# final location (postprd_dir).  Then delete the work directory.
#
#-----------------------------------------------------------------------
#
#
#-----------------------------------------------------------------------
#
# A separate ${post_fhr} forecast hour variable is required for the post
# files, since they may or may not be three digits long, depending on the
# length of the forecast.
#
#-----------------------------------------------------------------------
#
len_fhr=${#fhr}
if [ ${len_fhr} -eq 2 ]; then
  post_fhr=${fhr}
elif [ ${len_fhr} -eq 3 ]; then
  if [ "${fhr:0:1}" = "0" ]; then
    post_fhr="${fhr:1}"
  fi
else
  print_err_msg_exit "\
The \${fhr} variable contains too few or too many characters:
  fhr = \"$fhr\""
fi


bgdawp=${postprd_dir}/${NET}.t${cyc}z.bgdawpf${fhr}.${tmmark}.grib2
bgrd3d=${postprd_dir}/${NET}.t${cyc}z.bgrd3df${fhr}.${tmmark}.grib2
bgsfc=${postprd_dir}/${NET}.t${cyc}z.bgsfcf${fhr}.${tmmark}.grib2
mv_vrfy BGDAWP.GrbF${post_fhr} ${bgdawp}
mv_vrfy BGRD3D.GrbF${post_fhr} ${bgrd3d}
# small subset of surface fields for testbed and internal use
#wgrib2 -match "APCP|parmcat=16 parm=196|PRATE" ${bgrd3d} -grib ${bgsfc}

#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
Post-processing for forecast hour $fhr completed successfully.

Exiting script:  \"${scrfunc_fn}\"
In directory:    \"${scrfunc_dir}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1

