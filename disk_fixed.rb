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

    # Collect local disk information for both SCSI and NVMe devices
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)
      Ohai::Log.debug("Inspecting device: #{disk}")

      if disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/
        so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines

        # Get disk vendor
        vendor = if File.exist?("#{device}/device/vendor")
                   File.open("#{device}/device/vendor") { |f| f.read_nonblock(1024).strip }
                 else
                   'Unknown'
                 end
        Ohai::Log.debug("Vendor for #{disk}: #{vendor}")

        if vendor && %w[DELL HP VMware ATA SEAGATE SAMSUNG INTEL Unknown].include?(vendor)
          # Find the correct disk line in lsblk output
          disk_line = so.find { |line| line.strip.split[2] == 'disk' }

          if disk_line
            disk_parts = disk_line.strip.split
            disk_size = disk_parts[1].to_i / gb
            disks[disk] = Mash.new unless disks.key?(disk)
            disks[disk]['type'] = 'Local'
            disks[disk]['size_gb'] = disk_size
            Ohai::Log.debug("Local disk added: #{disk}, Size: #{disk_size} GB")
          else
            Ohai::Log.debug("No valid 'disk' entry found in lsblk output for #{disk}")
          end
        end
      else
        Ohai::Log.debug("Device #{disk} does not match expected patterns for SCSI or NVMe.")
      end
    end

    # Only try to parse SAN disks if multipath is available
    begin
      multipath_output = shell_out('multipath -ll').stdout.lines

      multipath_output.each_with_index do |line, index|
        # Match lines containing mpath names and sizes
        next unless line =~ /^(\w+)\s+\(.*\)/

        mpath_name = Regexp.last_match(1)
        size_line = multipath_output[index + 1] # The size is on the next line

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
      end
    rescue
      Ohai::Log.debug('Multipath is not available on this server.')
    end

    # Log parsed disks for verification
    Ohai::Log.debug("Final parsed disks: #{disks}")

    # Get WWN details
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
# rubocop:enable Style/Next
