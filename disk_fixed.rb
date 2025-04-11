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

    # Get list of all available block devices
    block_devices = Dir.glob('/sys/block/*').map { |d| File.basename(d) }

    Ohai::Log.debug("Found block devices: #{block_devices.inspect}")

    # Get multipath slaves if multipath is present
    multipath_slaves = []
    begin
      if File.exist?('/etc/multipath.conf') || shell_out('which multipath').exitstatus == 0
        multipath_output = shell_out('multipath -ll').stdout
        multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }
        Ohai::Log.debug("Multipath slaves found: #{multipath_slaves.inspect}")
      end
    rescue => e
      Ohai::Log.debug("Multipath check failed: #{e.message}")
    end

    # Process each block device
    block_devices.each do |disk|
      next unless disk =~ /^(sd|hd|vd|xvd|nvme|dm-)/  # Skip loop, ram, etc.

      Ohai::Log.debug("Processing disk: #{disk}")

      # Skip if this is a multipath slave
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk} - part of multipath")
        next
      end

      # Get disk size
      begin
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

        # Determine disk type
        type = if disk.start_with?('dm-')
                 'LVM'
               elsif multipath_slaves.include?(disk)
                 'SAN'
               else
                 'Local'
               end

        disks[disk] = {
          'size_gb' => size_gb,
          'vendor' => vendor,
          'type' => type
        }

        Ohai::Log.debug("Added disk #{disk}: #{disks[disk].inspect}")
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
