Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    Ohai::Log.debug('Starting DiskInfoPlugin')

    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    multipath_slaves = []
    multipath_enabled = false

    # Parse SAN disks from multipath if available
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        next unless line =~ /^(\w+)\s+\(.*\)/ # Match multipath device names
        mpath_name = Regexp.last_match(1)
        size_line = multipath_output[index + 1]

        multipath_enabled = true

        # Handle multipath device size
        if size_line =~ /size=(\d+\.?\d*)T/
          mpath_size_tb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_tb * 1024
          disks[mpath_name]['type'] = 'SAN'
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_tb * 1024} GB")
        elsif size_line =~ /size=(\d+\.?\d*)G/
          mpath_size_gb = Regexp.last_match(1).to_f
          disks[mpath_name] = Mash.new unless disks.key?(mpath_name)
          disks[mpath_name]['size_gb'] = mpath_size_gb
          disks[mpath_name]['type'] = 'SAN'
          Ohai::Log.debug("SAN disk added: #{mpath_name}, Size: #{mpath_size_gb} GB")
        end

        # Collect the multipath slave devices
        if size_line && size_line =~ /size=(\d+\.?\d*)G/
          # Collect the slave device names listed under multipath
          slaves_line = multipath_output[index + 2] # slaves are listed in the next line
          if slaves_line
            slaves_line.scan(/(\S+)\s+\d+/) do |match|
              multipath_slaves << match[0]  # Collect slave devices (like sdc, sdd, etc.)
            end
          end
        end
      end

      # Only gather slaves if multipath is truly present
      if multipath_enabled
        Ohai::Log.debug("Multipath slave devices detected: #{multipath_slaves}")
      end
    rescue
      Ohai::Log.debug('Multipath is not available on this server.')
    end

    # Collect local disks
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)
      Ohai::Log.debug("Inspecting device: #{disk}")

      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/

      # Skip if disk is a multipath slave (based on multipath -ll)
      if multipath_slaves.include?(disk)
        Ohai::Log.debug("Skipping #{disk} because it's part of multipath")
        next
      end

      so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
      disk_line = so.find { |line| line.strip.split[2] == 'disk' }

      unless disk_line
        Ohai::Log.debug("No valid 'disk' line found for #{disk}")
        next
      end

      disk_parts = disk_line.strip.split
      disk_size = disk_parts[1].to_i / gb

      vendor = if File.exist?("#{device}/device/vendor")
                 File.open("#{device}/device/vendor") { |f| f.read_nonblock(1024).strip }
               else
                 'Unknown'
               end
      Ohai::Log.debug("Vendor for #{disk}: #{vendor}")

      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      Ohai::Log.debug("Local disk added: #{disk}, Size: #{disk_size} GB")
    end

    # Get WWN info (optional part)
    Dir['/sys/class/fc_host/*'].each do |fc_host|
      %w(port_name).each do |port|
        if File.exist?("#{fc_host}/#{port}")
          File.open("#{fc_host}/#{port}") do |f|
            diskinfo['NodeWWN' + File.basename(fc_host)] = f.read_nonblock(1024).strip
          end
        end
      end
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
