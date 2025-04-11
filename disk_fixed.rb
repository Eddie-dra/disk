Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    Ohai::Log.debug('Starting DiskInfoPlugin')

    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    # Step 1: Collect multipath devices
    multipath_devices = []
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        if line =~ /^(\w+)\s+\(.*\)/  # Identify multipath device names
          mpath_name = Regexp.last_match(1)
          multipath_devices << mpath_name
        end
      end
      Ohai::Log.debug("Multipath devices detected: #{multipath_devices}")
    rescue
      Ohai::Log.debug('Multipath is not available on this server.')
    end

    # Step 2: Collect local disks, excluding multipath devices
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)
      Ohai::Log.debug("Inspecting device: #{disk}")

      # Skip if device is part of multipath
      if multipath_devices.include?(disk)
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath")
        next
      end

      # Only process valid disk types (sd* or nvme*)
      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/ 

      so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
      disk_line = so.find { |line| line.strip.split[2] == 'disk' }

      unless disk_line
        Ohai::Log.debug("No valid 'disk' line found for #{disk}")
        next
      end

      disk_parts = disk_line.strip.split
      disk_size = disk_parts[1].to_i / gb

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

    # Step 3: Add multipath devices to the list (but not the slaves)
    multipath_devices.each do |mpath_name|
      disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
      disks[mpath_name]['type'] = 'Multipath'
      disks[mpath_name]['size_gb'] = 'Multipath Device'  # Placeholder for multipath size
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
