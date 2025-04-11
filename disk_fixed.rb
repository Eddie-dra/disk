#
# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    Ohai::Log.debug('Starting DiskInfoPlugin')

    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    multipath_slaves = []

    # Parse SAN disks from multipath if available
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        next unless line =~ /^(\w+)\s+\(.*\)/
        mpath_name = Regexp.last_match(1)
        size_line = multipath_output[index + 1]

        if size_line =~ /size=(\d+\.?\d*)T/
          mpath_size_tb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_tb * 1024
          disks[mpath_name]['type'] = 'SAN'
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_tb * 1024} GB")
        elsif size_line =~ /size=(\d+\.?\d*)G/
          mpath_size_gb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_gb
          disks[mpath_name]['type'] = 'SAN'
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_gb} GB")
        end
      end

      multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }.uniq
      Ohai::Log.debug("Multipath slave devices detected: #{multipath_slaves}")
    rescue => e
      Ohai::Log.debug("Multipath not available or failed: #{e}")
    end

    # Collect local disks
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)
      Ohai::Log.debug("Inspecting device: #{disk}")

      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/

      # Skip if disk is a multipath slave
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath")
        next
      end

      disk_size = nil

      # First try parsing lsblk
      begin
        so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
        disk_line = so.find do |line|
          name, size, type, *_ = line.strip.split
          type == 'disk' && name == disk
        end
        if disk_line
          disk_parts = disk_line.strip.split
          disk_size = disk_parts[1].to_i / gb
        end
      rescue => e
        Ohai::Log.debug("lsblk failed for #{disk}: #{e}")
      end

      # Fallback to /sys/block/{disk}/size if lsblk didn't return anything
      if disk_size.nil?
        begin
          sectors = File.read("/sys/block/#{disk}/size").strip.to_i
          sector_size = File.read("/sys/block/#{disk}/queue/hw_sector_size").strip.to_i
          disk_size = (sectors * sector_size) / gb
          Ohai::Log.debug("Fallback size for #{disk}: #{disk_size} GB")
        rescue => e
          Ohai::Log.debug("Could not read size from sysfs for #{disk}: #{e}")
          next
        end
      end

      vendor = if File.exist?("#{device}/device/vendor")
                 File.open("#{device}/device/vendor") { |f| f.read_nonblock(1024).strip }
               else
                 'Unknown'
               end
      Ohai::Log.debug("Vendor for #{disk}: #{vendor}")

      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      Ohai::Log.debug("Local disk added: #{disk}, Size: #{disk_size} GB")
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
# rubocop:enable Style/Next
