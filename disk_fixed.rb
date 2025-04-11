#
# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'

  collect_data(:linux, :redhat) do
    Ohai::Log.debug('Starting DiskInfoPlugin')

    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    multipath_slaves = []

    # --- Step 1: Parse multipath SAN disks ---
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        next unless line =~ /^(\w+)\s+\(.*\)/
        mpath_name = Regexp.last_match(1)
        size_line = multipath_output[index + 1]

        if size_line =~ /size=(\d+\.?\d*)T/
          size = Regexp.last_match(1).to_f * 1024
        elsif size_line =~ /size=(\d+\.?\d*)G/
          size = Regexp.last_match(1).to_f
        else
          next
        end

        disks[mpath_name] = Mash.new
        disks[mpath_name]['type'] = 'SAN'
        disks[mpath_name]['size_gb'] = size
        Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{size} GB")
      end

      # Get list of multipath slave devices (e.g., sda, sdb, etc.)
      multipath_slaves = Dir.glob('/sys/block/dm-*/slaves/*').map { |p| File.basename(p) }.uniq
      Ohai::Log.debug("Multipath slave devices: #{multipath_slaves}")
    rescue => e
      Ohai::Log.debug("Multipath not available or failed: #{e}")
    end

    # --- Step 2: Detect all local disks (sd*, nvme*) ---
    Dir.glob('/sys/block/{sd*,nvme*}').each do |device_path|
      disk = File.basename(device_path)
      Ohai::Log.debug("Checking disk: #{disk}")

      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/

      # Exclude if part of multipath
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk}: part of multipath")
        next
      end

      # Use lsblk to determine if it's a disk and get size
      begin
        lsblk_out = shell_out("lsblk -b -dn -o SIZE /dev/#{disk}").stdout.strip
        disk_size = lsblk_out.to_i / gb
      rescue => e
        Ohai::Log.debug("lsblk failed for #{disk}: #{e}")
        disk_size = nil
      end

      # Fallback to sysfs if needed
      if disk_size.nil? || disk_size == 0
        begin
          sectors = File.read("/sys/block/#{disk}/size").to_i
          sector_size = File.read("/sys/block/#{disk}/queue/hw_sector_size").to_i
          disk_size = (sectors * sector_size) / gb
        rescue => e
          Ohai::Log.debug("sysfs read failed for #{disk}: #{e}")
          next
        end
      end

      # Get vendor if available
      vendor = if File.exist?("#{device_path}/device/vendor")
                 File.read("#{device_path}/device/vendor").strip
               else
                 'Unknown'
               end

      disks[disk] = Mash.new
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
      Ohai::Log.debug("Local disk added: #{disk}, Size: #{disk_size} GB")
    end

    # --- Step 3: FibreChannel WWNs ---
    Dir.glob('/sys/class/fc_host/*').each do |fc_host|
      %w(port_name).each do |port|
        path = File.join(fc_host, port)
        if File.exist?(path)
          diskinfo["NodeWWN#{File.basename(fc_host)}"] = File.read(path).strip
        end
      end
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end

# rubocop:enable Style/Next
