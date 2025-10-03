module main
import os
import json

struct PackageInfo {
	name string
	version string
}

fn main() {
	cyan := '\033[0;36m'
	green := '\033[0;32m'
	yellow := '\033[1;33m'
	blue := '\033[0;34m'
	red := '\033[0;31m'
	bold := '\033[1m'
	reset := '\033[0m'
	
	stick_dir := os.join_path(os.home_dir(), '.stick')
	pkgs_dir := os.join_path(stick_dir, 'pkgs')
	
	hostname := os.execute('hostname').output.trim_space()
	user := os.getenv('USER')
	
	kernel := os.execute('uname -r').output.trim_space()
	uptime := get_uptime()
	shell := os.execute('basename $$SHELL').output.trim_space()
	
	de := get_de()
	wm := get_wm()
	
	mut pkg_count := 0
	mut stick_pkgs := []PackageInfo{}
	
	if os.exists(pkgs_dir) {
		pkgs := os.ls(pkgs_dir) or { [] }
		pkg_count = pkgs.len
		for pkg in pkgs {
			info_file := os.join_path(pkgs_dir, pkg, 'info.json')
			if os.exists(info_file) {
				content := os.read_file(info_file) or { continue }
				info := json.decode(PackageInfo, content) or { 
					stick_pkgs << PackageInfo{name: pkg, version: 'unknown'}
					continue 
				}
				stick_pkgs << info
			} else {
				stick_pkgs << PackageInfo{name: pkg, version: 'unknown'}
			}
		}
	}
	
	pacman_count := os.execute('pacman -Q | wc -l').output.trim_space()
	
	art := [
		'${cyan}    _____ __  _      __  ',
		'${cyan}   / ___// /_(_)____/ /__',
		'${cyan}   \\__ \\/ __/ / ___/ //_/',
		'${cyan}  ___/ / /_/ / /__/ ,<   ',
		'${cyan} /____/\\__/_/\\___/_/|_|  ',
		'${cyan}                         '
	]
	
	info := [
		'${bold}${user}${reset}@${bold}${hostname}${reset}',
		'${red}OS${reset}: Arch Linux',
		'${green}Kernel${reset}: ${kernel}',
		'${yellow}Uptime${reset}: ${uptime}',
		'${blue}Shell${reset}: ${shell}',
		'${cyan}DE${reset}: ${de}',
		'${cyan}WM${reset}: ${wm}',
		'${red}Packages${reset}: ${pacman_count} (pacman)',
		'${green}Stick Packages${reset}: ${pkg_count}',
	]
	
	for i in 0..art.len {
		if i < info.len {
			println('${art[i]}   ${info[i]}')
		} else {
			println(art[i])
		}
	}
	
	if pkg_count > 0 {
		println('\n${bold}${green}Stick Installed Packages:${reset}')
		for pkg in stick_pkgs {
			println('  ${cyan}${pkg.name}${reset} ${yellow}(${pkg.version})${reset}')
		}
	}
	
	println('\n${cyan}████${green}████${yellow}████${blue}████${red}████${cyan}████${reset}')
}

fn get_uptime() string {
	output := os.execute('uptime -p').output.trim_space()
	return output.replace('up ', '')
}

fn get_de() string {
	de := os.getenv('XDG_CURRENT_DESKTOP')
	if de != '' { return de }
	de2 := os.getenv('DESKTOP_SESSION')
	if de2 != '' { return de2 }
	return 'Unknown'
}

fn get_wm() string {
	wm := os.execute('wmctrl -m 2>/dev/null | grep "Name:" | cut -d: -f2').output.trim_space()
	if wm != '' { return wm }
	wm2 := os.getenv('XDG_SESSION_TYPE')
	if wm2 != '' { return wm2 }
	return 'Unknown'
    }
