# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    gb = 1_073_741_824

    multipath_slaves = []
    multipath_enabled = false

    # Parse SAN disks from multipath if available
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        next unless line =~ /^(\w+)\s+\(.*\)/  # Find multipath devices
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
      # No multipath, proceed with local disk collection
    end

    # Collect local disks (sd*, nvme* etc.)
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Skip if disk is part of multipath (only dm devices, not regular devices like sda, sdb)
      if multipath_slaves.include?(disk) || disk =~ /^dm-\d+/
        next
      end

      # Only consider valid local disks (sd*, nvme*)
      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/

      # Get disk size using lsblk
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
          next
        end
      end

      # Get vendor info (handle gracefully if not available)
      vendor = 'Unknown'
      begin
        vendor_path = "#{device_path}/device/vendor"
        vendor = File.read(vendor_path).strip if File.exist?(vendor_path)
      rescue
        # Vendor info not available
      end

      # Add disk information to the hash
      disks[disk] = Mash.new
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
    end

    # Output disk information
    diskinfo = Mash.new
    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
