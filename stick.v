// UNSTABLE AND UNTESTED
// Only use for testing purposes

module main

import os
import flag
import net.http
import json
import time

struct Config {
mut:
	root string
	repos []string
}

struct PackageInfo {
	name string
	depends []string
	makedepends []string
	version string
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('stick')
	fp.skip_executable()
	remaining := fp.finalize() or { return }
	if remaining.len == 0 {
		println('Usage: stick <cmd> [package]\nCommands: install remove search list')
		return
	}
	mut cfg := load_config()
	cmd := remaining[0]
	match cmd {
		'install' {
			if remaining.len < 2 { println('Usage: stick install <package>'); return }
			install_with_deps(remaining[1], cfg)
		}
		'remove' {
			if remaining.len < 2 { println('Usage: stick remove <package>'); return }
			remove(remaining[1], cfg)
		}
		'search' {
			if remaining.len < 2 { println('Usage: stick search <package>'); return }
			search(remaining[1])
		}
		'list' { list_installed(cfg) }
		else { println('Unknown command: ${cmd}') }
	}
}

fn load_config() Config {
	mut cfg := Config{
		root: os.join_path(os.home_dir(), '.stick')
		repos: ['https://aur.archlinux.org']
	}
	conf_file := os.join_path(cfg.root, 'stick.conf')
	if !os.exists(conf_file) {
		os.mkdir_all(cfg.root) or {}
		os.write_file(conf_file, 'root="${cfg.root}"\nrepos=["https://aur.archlinux.org"]') or {}
	}
	os.mkdir_all(os.join_path(cfg.root, 'pkgs')) or {}
	os.mkdir_all(os.join_path(cfg.root, 'cache')) or {}
	return cfg
}

fn get_package_info(pkg string) ?PackageInfo {
	url := 'https://aur.archlinux.org/rpc/?v=5&type=info&arg=${pkg}'
	resp := http.get(url) or { return error('Failed to fetch') }
	if resp.status_code != 200 { return error('HTTP ${resp.status_code}') }
	data := json.decode(map[string]json.Any, resp.body) or { return error('Parse failed') }
	if results := data['results'] {
		results_array := results.arr()
		if results_array.len == 0 { return error('Not found') }
		pkg_data := results_array[0].as_map()
		mut depends := []string{}
		if dep_field := pkg_data['Depends'] {
			for d in dep_field.arr() {
				clean_dep := d.str().split_any('<>=')[0].trim_space()
				depends << clean_dep
			}
		}
		mut makedepends := []string{}
		if makedep_field := pkg_data['MakeDepends'] {
			for d in makedep_field.arr() {
				clean_dep := d.str().split_any('<>=')[0].trim_space()
				makedepends << clean_dep
			}
		}
		version := if v := pkg_data['Version'] { v.str() } else { 'unknown' }
		return PackageInfo{
			name: pkg
			depends: depends
			makedepends: makedepends
			version: version
		}
	}
	return error('No results')
}

fn is_system_package(pkg string) bool {
	return os.system('pacman -Qi "${pkg}" >/dev/null 2>&1') == 0
}

fn install_system_package(pkg string) bool {
	println('Installing system dependency: ${pkg}')
	return os.system('sudo pacman -S --noconfirm --needed "${pkg}"') == 0
}

fn check_system_repos(pkg string) bool {
	return os.system('pacman -Si "${pkg}" >/dev/null 2>&1') == 0
}

fn check_aur(pkg string) bool {
	url := 'https://aur.archlinux.org/rpc/?v=5&type=info&arg=${pkg}'
	resp := http.get(url) or { return false }
	if resp.status_code != 200 { return false }
	data := json.decode(map[string]json.Any, resp.body) or { return false }
	if results := data['results'] { return results.arr().len > 0 }
	return false
}

fn resolve_dependencies(pkg string, cfg Config) ?([]string, []string) {
	info := get_package_info(pkg) or { return error('Failed to get info: ${err}') }
	mut aur_deps := []string{}
	mut system_deps := []string{}
	mut all_deps := []string{}
	all_deps << info.depends
	all_deps << info.makedepends
	for dep in all_deps {
		if dep == '' || is_installed(dep, cfg) { continue }
		if is_system_package(dep) || check_system_repos(dep) {
			system_deps << dep
		} else if check_aur(dep) {
			aur_deps << dep
		}
	}
	return aur_deps, system_deps
}

fn install_with_deps(pkg string, cfg Config) {
	if is_installed(pkg, cfg) { println('${pkg} already installed.'); return }
	println('Resolving dependencies for ${pkg}...')
	aur_deps, system_deps := resolve_dependencies(pkg, cfg) or {
		eprintln('Failed to resolve deps: ${err}')
		return
	}
	if system_deps.len > 0 {
		println('\nSystem dependencies:')
		for dep in system_deps { println('  - ${dep}') }
		for dep in system_deps {
			if !install_system_package(dep) { eprintln('Failed: ${dep}') }
		}
	}
	if aur_deps.len > 0 {
		println('\nAUR dependencies:')
		for dep in aur_deps { println('  - ${dep}') }
		for dep in aur_deps {
			println('Installing AUR dep: ${dep}')
			install_with_deps(dep, cfg)
		}
	}
	println('\nInstalling ${pkg}...')
	install(pkg, cfg)
}

fn install(pkg string, cfg Config) {
	if is_installed(pkg, cfg) { return }
	now := time.now().unix_time().str()
	tmp := os.join_path(os.temp_dir(), '${pkg}_${now}')
	os.mkdir_all(tmp) or { eprintln('Failed temp dir'); return }
	println('Downloading ${pkg}...')
	url := 'https://aur.archlinux.org/cgit/aur.git/snapshot/${pkg}.tar.gz'
	resp := http.get(url) or { eprintln('Download failed'); return }
	if resp.status_code != 200 { eprintln('HTTP ${resp.status_code}'); return }
	archive := os.join_path(tmp, '${pkg}.tar.gz')
	os.write_file(archive, resp.body) or { eprintln('Save failed'); return }
	if os.system('tar -xzf "${archive}" -C "${tmp}"') != 0 { eprintln('Extract failed'); return }
	build_dir := os.join_path(tmp, pkg)
	if !os.exists(os.join_path(build_dir, 'PKGBUILD')) { eprintln('No PKGBUILD'); return }
	println('Building ${pkg}...')
	if os.system('sh -c "cd \\"${build_dir}\\" && makepkg -si --noconfirm"') != 0 {
		eprintln('Build failed')
		return
	}
	pkg_dir := os.join_path(cfg.root, 'pkgs', pkg)
	os.mkdir_all(pkg_dir) or {}
	info := get_package_info(pkg) or {
		PackageInfo{ name: pkg, depends: [], makedepends: [], version: 'unknown' }
	}
	os.write_file(os.join_path(pkg_dir, 'info.json'), json.encode(info)) or {}
	println('${pkg} installed successfully.')
}

fn is_installed(pkg string, cfg Config) bool {
	pkg_path := os.join_path(cfg.root, 'pkgs', pkg)
	return os.exists(pkg_path) && os.is_dir(pkg_path)
}

fn remove(pkg string, cfg Config) {
	if !is_installed(pkg, cfg) { println('${pkg} not installed.'); return }
	os.rmdir_all(os.join_path(cfg.root, 'pkgs', pkg)) or { eprintln('Remove failed'); return }
	println('${pkg} removed.')
}

fn search(pkg string) {
	url := 'https://aur.archlinux.org/rpc/?v=5&type=search&arg=${pkg}'
	resp := http.get(url) or { eprintln('Search failed'); return }
	if resp.status_code != 200 { eprintln('HTTP ${resp.status_code}'); return }
	data := json.decode(map[string]json.Any, resp.body) or { eprintln('Parse failed'); return }
	if results := data['results'] {
		results_array := results.arr()
		if results_array.len == 0 { println('No results'); return }
		for r in results_array {
			r_map := r.as_map()
			if name := r_map['Name'] {
				name_str := name.str()
				desc := r_map['Description'] or { json.Any('') }
				desc_str := desc.str()
				if desc_str != '' { println('${name_str} - ${desc_str}') } else { println('${name_str}') }
			}
		}
	} else { println('No results') }
}

fn list_installed(cfg Config) {
	pkgs_dir := os.join_path(cfg.root, 'pkgs')
	if !os.exists(pkgs_dir) { println('No packages installed.'); return }
	pkgs := os.ls(pkgs_dir) or { println('No packages installed.'); return }
	if pkgs.len == 0 { println('No packages installed.'); return }
	println('Installed packages:')
	for p in pkgs {
		info_file := os.join_path(pkgs_dir, p, 'info.json')
		if os.exists(info_file) {
			content := os.read_file(info_file) or { '' }
			if content != '' {
				info := json.decode(PackageInfo, content) or { println('  ${p}'); continue }
				println('  ${p} (${info.version})')
				continue
			}
		}
		println('  ${p}')
	}
}
