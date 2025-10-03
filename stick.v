module main

import os
import flag
import net.http
import json
import time
import sync

struct Config {
mut:
	root string
	bin_dir string
	repos []string
}

struct PackageInfo {
	name string
	depends []string
	makedepends []string
	version string
	conflicts []string
	provides []string
}

struct DownloadJob {
	pkg string
	url string
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('stick')
	fp.skip_executable()
	remaining := fp.finalize() or { return }
	if remaining.len == 0 {
		println('Usage: stick <cmd> [package]\nCommands: install remove search list upgrade reinstall')
		return
	}
	mut cfg := load_config()
	cmd := remaining[0]
	match cmd {
		'install' {
			if remaining.len < 2 { println('Usage: stick install <package> [package2] [package3]...'); return }
			mut failed := []string{}
			for i in 1..remaining.len {
				pkg := remaining[i]
				println('\n[${i}/${remaining.len - 1}] Processing ${pkg}...')
				if is_installed(pkg, cfg) {
					println('${pkg} already installed. Skipping.')
					continue
				}
				install_with_deps(pkg, cfg)
				if !is_installed(pkg, cfg) {
					failed << pkg
				}
			}
			if failed.len > 0 {
				println('\nFailed to install: ${failed.join(", ")}')
			}
		}
		'remove' {
			if remaining.len < 2 { println('Usage: stick remove <package> [package2] [package3]...'); return }
			for i in 1..remaining.len {
				pkg := remaining[i]
				println('\n[${i}/${remaining.len - 1}] Removing ${pkg}...')
				remove(pkg, cfg)
			}
		}
		'search' {
			if remaining.len < 2 { println('Usage: stick search <package>'); return }
			search(remaining[1])
		}
		'list' { list_installed(cfg) }
		'upgrade' { upgrade_all(cfg) }
		'reinstall' {
			if remaining.len < 2 { println('Usage: stick reinstall <package>'); return }
			reinstall(remaining[1], cfg)
		}
		else { println('Unknown command: ${cmd}') }
	}
}

fn load_config() Config {
	mut cfg := Config{
		root: os.join_path(os.home_dir(), '.stick')
		bin_dir: os.join_path(os.home_dir(), '.stick', 'bin')
		repos: ['https://aur.archlinux.org']
	}
	conf_file := os.join_path(cfg.root, 'stick.conf')
	if !os.exists(conf_file) {
		os.mkdir_all(cfg.root) or {}
		os.write_file(conf_file, 'root="${cfg.root}"\nrepos=["https://aur.archlinux.org"]') or {}
	}
	os.mkdir_all(os.join_path(cfg.root, 'pkgs')) or {}
	os.mkdir_all(os.join_path(cfg.root, 'cache')) or {}
	os.mkdir_all(cfg.bin_dir) or {}
	add_to_path(cfg.bin_dir)
	return cfg
}

fn add_to_path(bin_dir string) {
	shell_rc := if shell := os.getenv('SHELL') {
		if shell.contains('zsh') { os.join_path(os.home_dir(), '.zshrc') }
		else { os.join_path(os.home_dir(), '.bashrc') }
	} else { os.join_path(os.home_dir(), '.bashrc') }
	if os.exists(shell_rc) {
		content := os.read_file(shell_rc) or { return }
		path_line := 'export PATH="${bin_dir}:$$PATH"'
		if !content.contains(path_line) {
			os.write_file(shell_rc, content + '\n${path_line}\n') or {}
		}
	}
}

fn get_package_info(pkg string) ?PackageInfo {
	url := 'https://aur.archlinux.org/rpc/?v=5&type=info&arg=${pkg}'
	resp := http.get(url) or { return error('Failed to fetch') }
	if resp.status_code != 200 { return error('HTTP ${resp.status_code}') }
	data := json.decode(map[string]json.Any, resp.body) or { return error('Parse failed') }
	if results := data['results'] {
		results_array := results.arr()
		if results_array.len == 0 { return error('Not found in AUR') }
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
		mut conflicts := []string{}
		if conflict_field := pkg_data['Conflicts'] {
			for c in conflict_field.arr() {
				conflicts << c.str()
			}
		}
		mut provides := []string{}
		if provides_field := pkg_data['Provides'] {
			for p in provides_field.arr() {
				provides << p.str()
			}
		}
		version := if v := pkg_data['Version'] { v.str() } else { 'unknown' }
		return PackageInfo{ name: pkg, depends: depends, makedepends: makedepends, version: version, conflicts: conflicts, provides: provides }
	}
	return error('No results')
}

fn verify_package_signature(pkg string, build_dir string) bool {
	pkgbuild := os.join_path(build_dir, 'PKGBUILD')
	if !os.exists(pkgbuild) { return false }
	content := os.read_file(pkgbuild) or { return false }
	if content.contains('sha256sums') || content.contains('sha512sums') {
		println('Verifying checksums for ${pkg}...')
		rc := os.system('sh -c "cd \\"${build_dir}\\" && makepkg --verifysource"')
		if rc != 0 {
			eprintln('Checksum verification failed for ${pkg}')
			return false
		}
		println('Checksums verified for ${pkg}')
		return true
	}
	println('Warning: No checksums found for ${pkg}')
	return true
}

fn check_conflicts(pkg string, cfg Config) []string {
	info := get_package_info(pkg) or { return [] }
	mut conflicting := []string{}
	for conflict in info.conflicts {
		if is_installed(conflict, cfg) {
			conflicting << conflict
		}
	}
	return conflicting
}

fn resolve_conflicts(pkg string, cfg Config) bool {
	conflicts := check_conflicts(pkg, cfg)
	if conflicts.len > 0 {
		println('\nConflict detected! ${pkg} conflicts with:')
		for c in conflicts { println('  - ${c}') }
		println('\nAutomatically removing conflicting packages...')
		for c in conflicts {
			println('Removing ${c}...')
			remove(c, cfg)
		}
		return true
	}
	return false
}

fn is_system_package(pkg string) bool {
	return os.system('pacman -Qi "${pkg}" >/dev/null 2>&1') == 0
}

fn install_system_package(pkg string) bool {
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
	info := get_package_info(pkg) or { return error('Failed: ${err}') }
	mut aur_deps := []string{}
	mut system_deps := []string{}
	for dep in info.depends { if dep != '' && !is_installed(dep, cfg) {
		if is_system_package(dep) || check_system_repos(dep) { system_deps << dep }
		else if check_aur(dep) { aur_deps << dep }
	}}
	for dep in info.makedepends { if dep != '' && !is_installed(dep, cfg) {
		if is_system_package(dep) || check_system_repos(dep) { system_deps << dep }
		else if check_aur(dep) { aur_deps << dep }
	}}
	return aur_deps, system_deps
}

fn download_package_parallel(pkg string) ?string {
	now := time.now().unix_time().str()
	tmp := os.join_path(os.temp_dir(), '${pkg}_${now}')
	os.mkdir_all(tmp) or { return error('Temp dir failed') }
	url := 'https://aur.archlinux.org/cgit/aur.git/snapshot/${pkg}.tar.gz'
	resp := http.get(url) or { return error('Download failed') }
	if resp.status_code != 200 { return error('HTTP ${resp.status_code}') }
	archive := os.join_path(tmp, '${pkg}.tar.gz')
	os.write_file(archive, resp.body) or { return error('Save failed') }
	if os.system('tar -xzf "${archive}" -C "${tmp}"') != 0 { return error('Extract failed') }
	return os.join_path(tmp, pkg)
}

fn install_with_deps(pkg string, cfg Config) {
	if is_installed(pkg, cfg) { println('${pkg} already installed.'); return }
	resolve_conflicts(pkg, cfg)
	println('Resolving deps for ${pkg}...')
	aur_deps, system_deps := resolve_dependencies(pkg, cfg) or { eprintln('Dep resolve failed: ${err}'); return }
	if system_deps.len > 0 {
		println('\nSystem deps:')
		for dep in system_deps { println('  - ${dep}') }
		mut wg := sync.new_waitgroup()
		for dep in system_deps {
			wg.add(1)
			go fn [dep, wg] () {
				if !install_system_package(dep) { eprintln('Failed: ${dep}') }
				wg.done()
			}()
		}
		wg.wait()
	}
	if aur_deps.len > 0 {
		println('\nAUR deps:')
		for dep in aur_deps { println('  - ${dep}') }
		for dep in aur_deps { install_with_deps(dep, cfg) }
	}
	println('\nInstalling ${pkg}...')
	install(pkg, cfg)
}

fn install(pkg string, cfg Config) {
	if is_installed(pkg, cfg) { return }
	println('Downloading ${pkg}...')
	build_dir := download_package_parallel(pkg) or { eprintln('${err}'); return }
	if !os.exists(os.join_path(build_dir, 'PKGBUILD')) { eprintln('No PKGBUILD'); return }
	if !verify_package_signature(pkg, build_dir) {
		eprintln('Package signature verification failed. Aborting.')
		return
	}
	println('Building ${pkg}...')
	pkg_install_dir := os.join_path(cfg.root, 'pkgs', pkg, 'root')
	os.mkdir_all(pkg_install_dir) or {}
	if os.system('sh -c "cd \\"${build_dir}\\" && makepkg --install --noconfirm"') != 0 {
		eprintln('Build failed'); return
	}
	link_binaries(pkg, cfg)
	pkg_dir := os.join_path(cfg.root, 'pkgs', pkg)
	info := get_package_info(pkg) or { PackageInfo{ name: pkg, depends: [], makedepends: [], version: 'unknown', conflicts: [], provides: [] }}
	os.write_file(os.join_path(pkg_dir, 'info.json'), json.encode(info)) or {}
	println('${pkg} installed successfully.')
}

fn link_binaries(pkg string, cfg Config) {
	bin_paths := ['/usr/bin', '/usr/local/bin']
	for bin_path in bin_paths {
		if !os.exists(bin_path) { continue }
		files := os.ls(bin_path) or { continue }
		for file in files {
			src := os.join_path(bin_path, file)
			if os.is_executable(src) {
				dst := os.join_path(cfg.bin_dir, file)
				os.symlink(src, dst) or { continue }
			}
		}
	}
}

fn is_installed(pkg string, cfg Config) bool {
	pkg_path := os.join_path(cfg.root, 'pkgs', pkg)
	return os.exists(pkg_path) && os.is_dir(pkg_path)
}

fn remove(pkg string, cfg Config) {
	if !is_installed(pkg, cfg) { println('${pkg} not installed.'); return }
	pkg_dir := os.join_path(cfg.root, 'pkgs', pkg)
	info_file := os.join_path(pkg_dir, 'info.json')
	if os.exists(info_file) {
		content := os.read_file(info_file) or { '' }
		if content != '' {
			os.system('sudo pacman -R --noconfirm ${pkg}')
		}
	}
	os.rmdir_all(pkg_dir) or {}
	println('${pkg} removed.')
}

fn reinstall(pkg string, cfg Config) {
	println('Reinstalling ${pkg}...')
	remove(pkg, cfg)
	install_with_deps(pkg, cfg)
}

fn upgrade_all(cfg Config) {
	pkgs_dir := os.join_path(cfg.root, 'pkgs')
	if !os.exists(pkgs_dir) { println('No packages.'); return }
	pkgs := os.ls(pkgs_dir) or { println('No packages.'); return }
	if pkgs.len == 0 { println('No packages.'); return }
	println('Upgrading ${pkgs.len} package(s)...')
	for pkg in pkgs {
		info_file := os.join_path(pkgs_dir, pkg, 'info.json')
		if !os.exists(info_file) { continue }
		content := os.read_file(info_file) or { continue }
		old_info := json.decode(PackageInfo, content) or { continue }
		new_info := get_package_info(pkg) or { continue }
		if old_info.version != new_info.version {
			println('\nUpgrading ${pkg}: ${old_info.version} -> ${new_info.version}')
			reinstall(pkg, cfg)
		} else { println('${pkg} is up to date (${old_info.version})') }
	}
	println('\nUpgrade complete.')
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
	if !os.exists(pkgs_dir) { println('No packages.'); return }
	pkgs := os.ls(pkgs_dir) or { println('No packages.'); return }
	if pkgs.len == 0 { println('No packages.'); return }
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
