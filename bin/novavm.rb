#!/usr/bin/env ruby
# frozen_string_literal: true
require 'json'
require 'optparse'
require 'fileutils'
require 'open3'
require 'etc'
require 'time'

module NovaVM
  ROOT = File.expand_path('~/NovaVM/VMs')
  module_function

  def fail!(message)
    warn "NovaVM: #{message}"
    exit 1
  end

  def host_memory_mib
    out, status = Open3.capture2('/usr/sbin/sysctl', '-n', 'hw.memsize')
    fail!('Cannot detect host RAM.') unless status.success?
    out.to_i / (1024 * 1024)
  rescue Errno::ENOENT
    fail!('sysctl not found.')
  end

  def vm_dir(name)
    fail!('Name may contain only letters, digits, dash and underscore.') unless name.match?(/\A[a-zA-Z0-9_-]{1,48}\z/)
    File.join(ROOT, name)
  end

  def parse_size(value)
    m = /\A(\d+)([GM])\z/i.match(value)
    fail!('Disk size must look like 64G or 512M.') unless m
    bytes = m[1].to_i * (m[2].upcase == 'G' ? 1024**3 : 1024**2)
    fail!('Disk size must be between 1 GiB and 16 TiB.') unless bytes.between?(1024**3, 16 * 1024**4)
    bytes
  end

  def create(args)
    opts = { ram: 4096, cpu: 2, disk: '64G' }
    OptionParser.new do |p|
      p.banner = 'Usage: novavm.rb create NAME [--ram MIB] [--cpu COUNT] [--disk 64G]'
      p.on('--ram MIB', Integer) { |v| opts[:ram] = v }
      p.on('--cpu COUNT', Integer) { |v| opts[:cpu] = v }
      p.on('--disk SIZE') { |v| opts[:disk] = v }
    end.parse!(args)
    name = args.shift or fail!('Missing VM name.')
    host = host_memory_mib
    fail!("CPU count must be 1..#{Etc.nprocessors}.") unless opts[:cpu].between?(1, Etc.nprocessors)
    max_ram = [(host * 0.8).floor, 512].max
    fail!("RAM must be 1..#{max_ram} MiB (80% of detected host RAM).") unless opts[:ram].between?(1, max_ram)
    dir = vm_dir(name)
    fail!("VM already exists: #{dir}") if File.exist?(dir)
    FileUtils.mkdir_p(dir, mode: 0o700)
    begin
      bytes = parse_size(opts[:disk])
      File.open(File.join(dir, 'disk.raw'), 'wb', 0o600) { |f| f.truncate(bytes) }
      config = {
        name: name, created_at: Time.now.utc.iso8601, architecture: 'x86_64',
        ram_mib: opts[:ram], vcpus: opts[:cpu], disk: 'disk.raw',
        disk_bytes: bytes, firmware: 'not implemented', tpm: 'not implemented',
        iso: nil, status: 'created'
      }
      File.write(File.join(dir, 'config.json'), JSON.pretty_generate(config) + "\n", mode: 'w', perm: 0o600)
      puts "Created VM '#{name}' at #{dir}"
      puts "Persistent sparse disk created (logical size #{opts[:disk]})."
      puts 'This prototype cannot boot an ISO yet; UEFI and TPM are not implemented.'
    rescue StandardError
      FileUtils.rm_rf(dir)
      raise
    end
  end

  def status(args)
    name = args.shift or fail!('Usage: status NAME')
    path = File.join(vm_dir(name), 'config.json')
    fail!("No such VM: #{name}") unless File.file?(path)
    puts JSON.pretty_generate(JSON.parse(File.read(path)))
  end

  def disk_info(args)
    name = args.shift or fail!('Usage: disk-info NAME')
    path = File.join(vm_dir(name), 'disk.raw')
    fail!("No disk found for #{name}") unless File.file?(path)
    st = File.stat(path)
    puts "Path: #{path}"
    puts "Logical size: #{st.size} bytes (#{(st.size.to_f / 1024**3).round(2)} GiB)"
    puts "Allocated blocks: #{st.blocks * 512} bytes (filesystem-reported)"
  end

  def init_project(args)
    root = File.expand_path(args.shift || Dir.pwd)
    fail!("Directory does not exist: #{root}") unless File.directory?(root)

    dir = File.join(root, "novavm")
    config_path = File.join(dir, "novavm.json")
    fail!("Configuration already exists: #{config_path}") if File.exist?(config_path)

    config = {
      name: File.basename(root),
      version: "2.0.0",
      architecture: "x86_64",
      iso: nil,
      ram_mib: 4096,
      vcpus: 2,
      disk: "64G",
      firmware: "not implemented",
      tpm: "not implemented"
    }

    FileUtils.mkdir_p(dir)
    File.write(config_path, JSON.pretty_generate(config) + "\n")
    puts "Created NovaVM project configuration: #{config_path}"
    puts "Note: this prototype cannot boot ISO images yet."
  end

  def hypervisor_check
    out, status = Open3.capture2('/usr/sbin/sysctl', '-n', 'kern.hv_support')
    puts "kern.hv_support: #{out.strip}"
    puts(status.success? && out.strip == '1' ? 'Hypervisor support reported available.' : 'Hypervisor support unavailable.')
  end
end

case ARGV.shift
when 'create' then NovaVM.create(ARGV)
when 'status' then NovaVM.status(ARGV)
when 'disk-info' then NovaVM.disk_info(ARGV)
when 'hypervisor-check' then NovaVM.hypervisor_check
when 'init' then NovaVM.init_project(ARGV)
else
  puts 'NovaVM — experimental x86_64 VM prototype'
  puts 'Commands: create, status, disk-info, hypervisor-check, init'
  puts 'Example: ruby bin/novavm.rb create Windows11 --ram 8192 --cpu 4 --disk 64G'
end
