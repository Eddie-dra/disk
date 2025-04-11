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
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_tb * 1024} GB")
        elsif size_line =~ /size=(\d+\.?\d*)G/
          mpath_size_gb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_gb
          disks[mpath_name]['type'] = 'SAN'
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_gb} GB")
        end
      end

      # Only gather slaves if multipath is truly present
      if multipath_enabled
        multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }.uniq
        Ohai::Log.debug("Multipath slave devices detected: #{multipath_slaves}")
      end
    rescue
      Ohai::Log.debug('Multipath is not available on this server.')
    end

    # Collect local disks
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)
      Ohai::Log.debug("Checking disk: #{disk}")

      # Skip if disk is part of multipath
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk}: part of multipath")
        next
      end

      # Only consider valid local disks (sda, sdb, etc.)
      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/

      # Get disk size from lsblk
      disk_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        out.to_i / gb
      rescue
        0
      end

      # Fallback to sysfs if lsblk fails
      if disk_size == 0
        begin
          sectors = File.read("/sys/block/#{disk}/size").to_i
          sector_size = File.read("/sys/block/#{disk}/queue/hw_sector_size").to_i
          disk_size = (sectors * sector_size) / gb
        rescue
          Ohai::Log.debug("Failed to calculate size for #{disk}")
          next
        end
      end

      # Get vendor info (handle gracefully if not available)
      vendor = 'Unknown'
      begin
        vendor_path = "#{device_path}/device/vendor"
        vendor = File.read(vendor_path).strip if File.exist?(vendor_path)
      rescue
        Ohai::Log.debug("Vendor info missing or unreadable for #{disk}")
      end

      # Add disk information to the hash
      disks[disk] = Mash.new
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
      Ohai::Log.debug("Local disk added: #{disk}, Size: #{disk_size} GB, Vendor: #{vendor}")
    end

    # Output disk information
    diskinfo = Mash.new
    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
