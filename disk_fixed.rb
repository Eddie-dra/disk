Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []

    # Step 1: Collect multipath devices (not the slaves)
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each_with_index do |line, index|
        if line =~ /(\w+)\s+\(.*\)/  # Found a multipath device
          mpath_name = Regexp.last_match(1)

          # Add multipath device to the multipath_devices list
          multipath_devices << mpath_name
        end
      end
    rescue => e
      Ohai::Log.debug("Error with multipath: #{e.message}")
    end

    # Step 2: Collect all disks, excluding any that are part of a multipath device
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Skip if the disk is part of a multipath device (i.e., if it appears in the multipath_devices list)
      next if multipath_devices.any? { |mpath| File.exist?("/sys/block/dm-*/slaves/#{disk}") }

      # Get the size of the disk
      disk_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        out.to_i / 1_073_741_824  # Convert bytes to GB
      rescue
        0
      end

      # Add the disk to the disks hash
      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    # Step 3: Add multipath devices themselves (not their slaves)
    multipath_devices.each do |mpath_name|
      # Add multipath device to the disks hash
      disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
      disks[mpath_name]['type'] = 'Multipath'
      disks[mpath_name]['size_gb'] = 'Multipath Device'  # Placeholder size for multipath
    end

    # Return the disk information
    disk_information({ 'disks' => disks })
  end
end
