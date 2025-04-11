Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []

    # Step 1: Collect all multipath devices using multipath -ll
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

    # Step 2: Collect all disks (sd*, nvme*, etc.)
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)
      # Skip dm devices (multipath devices)
      next if disk =~ /^dm-/

      # Step 3: Skip disks that are part of a multipath device
      is_slave = multipath_devices.any? { |mpath| File.exist?("/sys/block/#{disk}/slaves/#{mpath}") }
      
      if is_slave
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath device.")
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

    # Step 4: Add multipath devices (dm-*) to the hash
    multipath_devices.each do |mpath|
      # Skip if it's already added as a slave disk
      next if disks.key?(mpath)

      disks[mpath] = Mash.new unless disks.key?(mpath)
      disks[mpath]['type'] = 'Multipath'
      disks[mpath]['size_gb'] = "Multipath device"  # Or actual multipath size if available
    end

    disk_information({ 'disks' => disks })
  end
end
