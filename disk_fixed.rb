# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    gb = 1_073_741_824

    # Collect local disks using lsblk or lshw
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Skip any device that is a multipath slave (dm-* devices)
      next if disk =~ /^dm-\d+/

      # Use lsblk to get the size of the disk
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
        vendor = 'Unknown'
      end

      # Add disk information to the hash
      disks[disk] = Mash.new
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
    end

    # Output the final disk information
    diskinfo = Mash.new
    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
