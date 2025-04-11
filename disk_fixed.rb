#
# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    multipath_slaves = []
    multipath_enabled = false

    # Parse SAN disks from multipath if available
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        next unless line =~ /^(\w+)\s+\(.*\)/
        mpath_name = Regexp.last_match(1)
        size_line = multipath_output[index + 1]

        multipath_enabled = true

        if size_line =~ /size=(\d+\.?\d*)T/
          mpath_size_tb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_tb * 1024
          disks[mpath_name]['type'] = 'SAN'
        elsif size_line =~ /size=(\d+\.?\d*)G/
          mpath_size_gb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_gb
          disks[mpath_name]['type'] = 'SAN'
        end
      end

      # Only gather slaves if multipath is truly present
      if multipath_enabled
        multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }.uniq
      end
    rescue
      # Ignore error if multipath is not available
    end

    # Collect local disks
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)

      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/ # Filter for valid disks (sd*, nvme*)

      # Skip if disk is part of multipath
      if multipath_enabled && multipath_slaves.include?(disk)
        next
      end

      # Skip WWID check for local disks or multipath disks only
      if multipath_enabled && File.exist?("#{device}/device/wwid") && !multipath_slaves.include?(disk)
        next
      end

      # Get disk size using lsblk
      so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
      disk_line = so.find { |line| line.strip.split[2] == 'disk' }

      unless disk_line
        next
      end

      disk_parts = disk_line.strip.split
      disk_size = disk_parts[1].to_i / gb

      # Get vendor info (handle gracefully if not available)
      vendor = if File.exist?("#{device}/device/vendor")
                 File.open("#{device}/device/vendor") { |f| f.read_nonblock(1024).strip }
               else
                 'Unknown'
               end

      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    # Get WWN info
    Dir['/sys/class/fc_host/*'].each do |fc_host|
      %w(port_name).each do |port|
        if File.exist?("#{fc_host}/#{port}")
          File.open("#{fc_host}/#{port}") do |f|
            diskinfo['NodeWWN' + File.basename(fc_host)] = f.read_nonblock(1024).strip
          end
        end
      end
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
