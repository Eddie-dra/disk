Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_slaves = []

    # Step 1: Collect multipath slaves
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each_with_index do |line, index|
        if line =~ /(\w+)\s+\(.*\)/  # Found a multipath device
          mpath_name = Regexp.last_match(1)
          
          # Find and collect slaves
          slaves_line = multipath_output[index + 1]
          if slaves_line
            slaves_line.scan(/(\S+)\s+\d+/) do |match|
              multipath_slaves << match[0]  # Collect the slave device names
            end
          end
        end
      end
    rescue => e
      Ohai::Log.debug("Error with multipath: #{e.message}")
    end

    # Step 2: Collect all disks, excluding the multipath slave devices
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Skip if disk is a multipath slave
      next if multipath_slaves.include?(disk)

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
    multipath_output.each do |line|
      if line =~ /(\w+)\s+\(.*\)/  # Identify multipath device name
        mpath_name = Regexp.last_match(1)
        
        # Add multipath device to the disks hash (not the slaves)
        disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
        disks[mpath_name]['type'] = 'Multipath'
        disks[mpath_name]['size_gb'] = 'Multipath Device'  # Placeholder size for multipath
      end
    end

    # Return the disk information
    disk_information({ 'disks' => disks })
  end
end
