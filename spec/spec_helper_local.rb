def tmpfile(name, dir = nil)
  dir ||= Dir.tmpdir
  path = Puppet::FileSystem.expand_path(make_tmpname(name, nil).encode(Encoding::UTF_8), dir)
  record_tmp(File.expand_path(path))

  path
end

# Copied from ruby 2.4 source
def make_tmpname((prefix, suffix), n)
  prefix = (String.try_convert(prefix) or
            raise ArgumentError, "unexpected prefix: #{prefix.inspect}")
  suffix &&= (String.try_convert(suffix) or
              raise ArgumentError, "unexpected suffix: #{suffix.inspect}")
  t = Time.now.strftime("%Y%m%d")
  path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}".dup
  path << "-#{n}" if n
  path << suffix if suffix
  path
end

def record_tmp(tmp)
  # ...record it for cleanup,
  $global_tempfiles ||= []
  $global_tempfiles << tmp
end

def make_absolute(path)
  path = File.expand_path(path)
  path[0] = 'c' if Puppet.features.microsoft_windows?
  path
end
