Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    multipath_devices = []

    # Step 1: Gather all disks
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)

      # Add the disk to the disks hash
      disk_size = begin
        out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        out.to_i / 1_073_741_824  # Convert bytes to GB
      rescue
        0
      end

      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    # Step 2: Run multipath -ll to identify multipath devices
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines
      multipath_output.each do |line|
        if line =~ /(\w+)\s+\(.*\)/  # Found a multipath device
          mpath_name = Regexp.last_match(1)
          multipath_devices << mpath_name
        end
      end
    rescue => e
      Ohai::Log.debug("Error with multipath: #{e.message}")
    end

    # Step 3: Exclude the disks that are part of multipath
    multipath_devices.each do |mpath_device|
      # Remove multipath devices from the list of disks
      disks.delete(mpath_device)
    end

    # Return the disk information
    disk_information({ 'disks' => disks })
  end
end
