#
# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux) do
    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    # Get list of all available block devices (excluding partitions)
    block_devices = Dir.glob('/sys/block/*').select do |d| 
      File.basename(d) =~ /^(sd|hd|vd|xvd|nvme|dm-)/ && 
      !File.exist?("#{d}/partition")  # Skip partitions
    end.map { |d| File.basename(d) }

    Ohai::Log.debug("Found block devices: #{block_devices.inspect}")

    # Get multipath information if available
    multipath_mapping = {}  # Maps dm-* to physical devices
    multipath_slaves = []
    
    begin
      if File.exist?('/etc/multipath.conf') || shell_out('which multipath').exitstatus == 0
        # Build mapping of dm-* devices to their physical devices
        Dir.glob('/sys/block/dm-*/slaves/*').each do |slave|
          slave_name = File.basename(slave)
          dm_device = File.basename(File.dirname(File.dirname(slave)))
          multipath_slaves << slave_name
          multipath_mapping[dm_device] ||= []
          multipath_mapping[dm_device] << slave_name
        end
        
        # Also get friendly names from multipath -ll
        shell_out('multipath -ll').stdout.each_line do |line|
          if line =~ /^(\w+)\s+\(([^)]+)\)/
            dm_name = $1
            wwid = $2
            if multipath_mapping[dm_name]
              multipath_mapping[dm_name] << "mpath-#{wwid}"  # Add friendly name
            end
          end
        end

        Ohai::Log.debug("Multipath mapping: #{multipath_mapping.inspect}")
      end
    rescue => e
      Ohai::Log.debug("Multipath check failed: #{e.message}")
    end

    # Process each block device
    block_devices.each do |disk|
      # Skip if this is a partition (shouldn't happen due to earlier filter, but just in case)
      next if disk =~ /\d+$/ || File.exist?("/sys/block/#{disk}/partition")

      # Skip if this is a multipath slave (we'll get it through the multipath device)
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk} - part of multipath")
        next
      end

      Ohai::Log.debug("Processing disk: #{disk}")

      begin
        # Get disk size
        size_file = "/sys/block/#{disk}/size"
        if File.exist?(size_file)
          sectors = File.read(size_file).to_i
          sector_size = File.read("/sys/block/#{disk}/queue/hw_sector_size").to_i rescue 512
          size_bytes = sectors * sector_size
          size_gb = size_bytes / gb
        else
          # Fallback to lsblk if sysfs info not available
          lsblk_output = shell_out("lsblk -b -n -d -o SIZE /dev/#{disk}").stdout.strip
          size_gb = lsblk_output.to_i / gb
        end

        # Get disk vendor
        vendor = if File.exist?("/sys/block/#{disk}/device/vendor")
                   File.read("/sys/block/#{disk}/device/vendor").strip
                 else
                   'Unknown'
                 end

        # Determine display name and type
        if disk.start_with?('dm-')
          if multipath_mapping.key?(disk)
            # This is a multipath device - use the first physical device name or friendly name
            display_name = multipath_mapping[disk].find { |x| x.start_with?('mpath-') } || 
                           multipath_mapping[disk].first
            type = 'SAN (Multipath)'
          else
            # Other device-mapper device (LVM)
            display_name = disk
            type = 'LVM'
          end
        else
          display_name = disk
          type = 'Local'
        end

        # Only add if we haven't seen this disk already
        unless disks.key?(display_name)
          disks[display_name] = {
            'size_gb' => size_gb,
            'vendor' => vendor,
            'type' => type,
            'physical_device' => disk.start_with?('dm-') ? multipath_mapping[disk] : nil
          }
          Ohai::Log.debug("Added disk #{display_name}: #{disks[display_name].inspect}")
        end
      rescue => e
        Ohai::Log.debug("Failed to process disk #{disk}: #{e.message}")
      end
    end

    # Add WWN info if available
    Dir.glob('/sys/class/fc_host/*').each do |fc_host|
      port_name = "#{fc_host}/port_name"
      if File.exist?(port_name)
        diskinfo['NodeWWN' + File.basename(fc_host)] = File.read(port_name).strip
      end
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
