Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []
    multipath_slaves = []

    # Step 1: Collect all multipath devices using multipath -ll
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each_with_index do |line, index|
        if line =~ /^(\w+)\s+\(.*\)/  # Multipath device found
          mpath_name = Regexp.last_match(1)
          multipath_devices << mpath_name
          # Collect slaves for each multipath device
          slaves_line = multipath_output[index + 1]
          if slaves_line
            slaves_line.scan(/(\S+)\s+\d+/) do |match|
              multipath_slaves << match[0]
            end
          end
        end
      end
    rescue => e
      Ohai::Log.debug("Multipath error: #{e.message}")
    end

    # Step 2: Collect all disks (sd*, nvme*, etc.)
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Skip dm devices (multipath devices themselves)
      next if disk =~ /^dm-/

      # Step 3: Skip disks that are part of a multipath device
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath.")
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

    # Step 4: Add multipath devices (mpath*) to the hash
    multipath_devices.each do |mpath|
      disks[mpath] = Mash.new unless disks.key?(mpath)
      disks[mpath]['type'] = 'Multipath'

      # Get the size of the multipath device
      mpath_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{mpath}").stdout.strip
        out.to_i / 1_073_741_824  # Convert bytes to GB
      rescue
        0
      end
      disks[mpath]['size_gb'] = mpath_size
    end

    disk_information({ 'disks' => disks })
  end
end
