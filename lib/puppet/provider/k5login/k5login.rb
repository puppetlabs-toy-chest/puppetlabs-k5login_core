Puppet::Type.type(:k5login).provide(:k5login) do
  desc "The k5login provider is the only provider for the k5login
    type."

  include Puppet::Util::SELinux

  # Does this file exist?
  def exists?
    Puppet::FileSystem.exist?(@resource[:name])
  end

  # create the file
  def create
    write(@resource.should(:principals))
    should_mode = @resource.should(:mode)
    self.mode = should_mode unless mode == should_mode
  end

  # remove the file
  def destroy
    Puppet::FileSystem.unlink(@resource[:name])
  end

  # Return the principals
  def principals
    if Puppet::FileSystem.exist?(@resource[:name])
      File.readlines(@resource[:name]).map { |line| line.chomp }
    else
      :absent
    end
  end

  # Write the principals out to the k5login file
  def principals=(value)
    write(value)
  end

  # Return the mode as an octal string, not as an integer
  def mode
    '%o' % (Puppet::FileSystem.stat(@resource[:name]).mode & 0o07777)
  end

  # Set the file mode, converting from a string to an integer.
  def mode=(value)
    File.chmod(Integer("0#{value}"), @resource[:name])
  end

  private

  def write(value)
    Puppet::Util.replace_file(@resource[:name], 0o644) do |f|
      f.puts value
    end
  end
end
