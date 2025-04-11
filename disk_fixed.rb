Ohai.plugin(:Diskinformation) do
  provides 'disk_information'

  collect_data(:linux, :redhat) do
    disks = Mash.new
    gb = 1_073_741_824  # 1 GB in bytes

    # Initialize multipath slaves
    multipath_slaves = []

    # Check if multipath devices are available
    begin
      multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }.uniq
    rescue => e
      Ohai::Log.debug("Error reading multipath slaves: #{e}")
    end

    # Collect local disks (sd*, nvme*)
    Dir['/sys/block/{sd*,nvme*}'].each do |device_path|
      disk = File.basename(device_path)

      # Skip disk if it's part of a multipath device
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk}: part of multipath")
        next
      end

      # Only consider valid local disks (sd*, nvme*)
      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/  # Valid disk names

      # Get disk size using lsblk
      disk_size = begin
        out = shell_out("lsblk -b -o NAME,SIZE -n /dev/#{disk}").stdout.strip
        size_in_bytes = out.split[1].to_i
        size_in_gb = size_in_bytes / gb
        size_in_gb
      rescue
        0  # Default to 0 if lsblk fails
      end

      # Skip disk if we can't get a valid size
      next if disk_size == 0

      # Get vendor info (handle gracefully if not available)
      vendor = 'Unknown'
      vendor_path = "/sys/block/#{disk}/device/vendor"
      vendor = File.read(vendor_path).strip if File.exist?(vendor_path)

      # Add disk information to the hash
      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
    end

    # Output disk information
    diskinfo = Mash.new
    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
