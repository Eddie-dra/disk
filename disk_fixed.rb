Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_slaves = []

    # Step 1: Identify and collect multipath slave devices
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each_with_index do |line, index|
        if line =~ /(\w+)\s+\(.*\)/  # Multipath device found
          mpath_name = Regexp.last_match(1)
          # Collect slaves for each multipath device
          slaves_line = multipath_output[index + 1]
          if slaves_line
            slaves_line.scan(/(\S+)\s+\d+/) do |match|
              multipath_slaves << match[0]  # Record the slave devices
            end
          end
        end
      end
    rescue => e
      Ohai::Log.debug("Error with multipath: #{e.message}")
    end

    # Step 2: Collect all disks and exclude the multipath slaves
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)
      # Skip multipath slave devices
      next if multipath_slaves.include?(disk)

      # Get the size of the disk in GB
      disk_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        out.to_i / 1_073_741_824  # Convert bytes to GB
      rescue
        0
      end

      # Add the disk to the final list
      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    # Step 3: Include multipath devices themselves (not their slaves)
    multipath_output.each do |line|
      if line =~ /(\w+)\s+\(.*\)/  # Identifying multipath devices
        mpath_name = Regexp.last_match(1)
        disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
        disks[mpath_name]['type'] = 'Multipath'
        disks[mpath_name]['size_gb'] = 'Multipath Device'  # Placeholder for size
      end
    end

    # Return the final disk information
    disk_information({ 'disks' => disks })
  end
end
