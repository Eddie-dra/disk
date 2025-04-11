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

    # Collect local disks (sda, sdb, etc.)
    Dir['/sys/block/{sd*,nvme*}'].each do |device|
      disk = File.basename(device)

      next unless disk =~ /^sd[a-z]+$/ || disk =~ /^nvme\d+n\d+$/ # Filter for valid disks (sd*, nvme*)

      # Get disk size using lsblk
      so = shell_out("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT -n -r /dev/#{disk}").stdout.lines
      disk_line = so.find { |line| line.strip.split[2] == 'disk' }

      unless disk_line
        next
      end

      disk_parts = disk_line.strip.split
      disk_size = disk_parts[1].to_i / gb

      # Get vendor info (handle gracefully if not available)
      vendor = if File.exist?("#{device}/device/vendor")
                 File.open("#{device}/device/vendor") { |f| f.read_nonblock(1024).strip }
               else
                 'Unknown'
               end

      disks[disk] = Mash.new unless disks.key?(disk)
      disks[disk]['type'] = 'Local'
      disks[disk]['size_gb'] = disk_size
    end

    diskinfo['disks'] = disks
    disk_information diskinfo
  end
end
