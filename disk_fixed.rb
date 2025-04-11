Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []
    local_disks = Mash.new

    # Step 1: Collect all block devices (both disks and multipath)
    Dir['/sys/block/{sd*,nvme*,dm-*}'].each do |device|
      disk = File.basename(device)

      # Skip multipath devices (dm-*), we will handle them separately later
      if disk =~ /^dm-/
        multipath_devices << disk
        next
      end

      # Check if this disk is part of a multipath device (as a slave)
      is_multipath_slave = false
      Dir.glob("/sys/block/#{disk}/slaves/*").each do |slave|
        if multipath_devices.include?(File.basename(slave))
          is_multipath_slave = true
          break
        end
      end

      # If this is a multipath slave, skip it
      next if is_multipath_slave

      # Get the disk size using lsblk
      disk_size = 0
      begin
        disk_size = shell_out("lsblk -b -o SIZE -n -r /dev/#{disk}").stdout.strip.to_i / (1024 * 1024 * 1024)
      rescue
        Ohai::Log.debug("Failed to get size for disk #{disk}")
      end

      # If we failed to get the size from lsblk, try sysfs
      if disk_size == 0
        begin
          size = File.read("/sys/block/#{disk}/size").to_i
          sector_size = File.read("/sys/block/#{disk}/queue/hw_sector_size").to_i
          disk_size = (size * sector_size) / (1024 * 1024 * 1024)
        rescue
          Ohai::Log.debug("Failed to calculate size for #{disk} from sysfs")
        end
      end

      # Add valid disks to local_disks
      if disk_size > 0
        local_disks[disk] = Mash.new
        local_disks[disk]['type'] = 'Local'
        local_disks[disk]['size_gb'] = disk_size
      end
    end

    # Step 2: Handle multipath devices (dm-*), add them as separate entries
    multipath_devices.each do |mpath_device|
      disk_size = 0
      begin
        disk_size = shell_out("lsblk -b -o SIZE -n -r /dev/#{mpath_device}").stdout.strip.to_i / (1024 * 1024 * 1024)
      rescue
        Ohai::Log.debug("Failed to get size for multipath device #{mpath_device}")
      end

      if disk_size > 0
        disks[mpath_device] = Mash.new
        disks[mpath_device]['type'] = 'Multipath'
        disks[mpath_device]['size_gb'] = disk_size
      end
    end

    # Step 3: Combine local disks and multipath disks
    diskinfo = Mash.new
    diskinfo['disks'] = local_disks.merge(disks)

    # Step 4: Return the final list
    disk_information diskinfo
  end
end
