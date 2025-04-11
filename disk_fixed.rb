#
# Copyright:: 2016, Danske Bank A/S
#
# This plugin collects disk volume information for Linux hosts
#

Ohai.plugin(:Diskinformation) do
  provides 'disk_information'
  collect_data(:linux, :redhat) do
    disks = Mash.new
    diskinfo = Mash.new
    gb = 1_073_741_824

    # Collect local disks (sd*, nvme*, etc.)
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)
      
      # Skip if disk has WWID (indicating it's part of multipath or SAN)
      if File.exist?("#{device}/device/wwid")
        next
      end

      # Collect disk size using lsblk
      so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
      disk_line = so.find { |line| line.strip.split[2] == 'disk' }

      # Skip if we don't find a valid 'disk' line
      unless disk_line
        next
      end

      # Parse disk info
      disk_parts = disk_line.strip.split
      disk_size = disk_parts[1].to_i / gb

      # Collect vendor info
      vendor = if File.exist?("#{device}/device/vendor")
                 File.read("#{device}/device/vendor").strip
               else
                 'Unknown'
               end

      # Add the disk information to the result hash
      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
      disks[disk]['vendor'] = vendor
    end

    # Output the collected disk information
    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
