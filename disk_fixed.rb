Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []

    # Collect all multipath devices using multipath -ll
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each_with_index do |line, index|
        if line =~ /^(\w+)\s+\(.*\)/  # Multipath device found
          mpath_name = Regexp.last_match(1)
          multipath_devices << mpath_name
        end
      end
    rescue => e
      Ohai::Log.debug("Multipath error: #{e.message}")
    end

    # Collect all disks (sd*, nvme*, etc.)
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)
      # Skip devices that are part of multipath (dm devices)
      next if disk =~ /^dm-/

      # Skip if the disk is part of a multipath device
      if multipath_devices.any? { |mpath| File.exist?("/sys/block/#{disk}/slaves/#{mpath}") }
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath")
        next
      end

      # Get disk size
      disk_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        out.to_i / 1_073_741_824  # Convert bytes to GB
      rescue
        0
      end

      # Add disk to the hash
      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    # Add multipath devices to the hash
    multipath_devices.each do |mpath|
      disks[mpath] = Mash.new unless disks.key?(mpath)
      disks[mpath]['type'] = 'Multipath'
      disks[mpath]['size_gb'] = "Multipath device"  # Or size from multipath if available
    end

    disk_information({ 'disks' => disks })
  end
end
