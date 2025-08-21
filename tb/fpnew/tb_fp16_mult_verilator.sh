script_dir=$(dirname "$(readlink -f "$0")")
warning_disable='-Wno-style -Wno-PINCONNECTEMPTY -Wno-TIMESCALEMOD -Wno-ASCRANGE -Wno-WIDTHEXPAND -Wno-PINMISSING -Wno-WIDTHTRUNC -Wno-UNSIGNED -Wno-UNOPTFLAT -Wno-BLKANDNBLK'
module_name=fp16_mult
tb_name="tb_${module_name}"
#echo $script_dir
verilator --binary -j 0 $warning_disable -I$script_dir/../../src/common_cells/include $script_dir/../../src/fpnew_pkg.sv $script_dir/../../src/common_cells/src/cf_math_pkg.sv $script_dir/../../src/common_cells/src/lzc.sv $script_dir/../../src/common_cells/src/rr_arb_tree.sv $script_dir/../../src/*.sv $script_dir/../../src/wrappers/"${module_name}".sv $script_dir/${tb_name}.sv --top-module ${tb_name} --trace && $script_dir/obj_dir/V"${tb_name}" > $script_dir/"${tb_name}"_output.txt