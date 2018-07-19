require 'spec_helper'
require 'fileutils'
require 'puppet/type'
require 'puppet/provider'

describe Puppet::Type.type(:k5login).provider(:k5login), unless: Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let(:path) { tmpfile('k5login') }

  def resource(attrs = {})
    attrs = {
      ensure: 'present',
      path: path,
      principals: 'fred@EXAMPLE.COM',
      seluser: 'user_u',
      selrole: 'role_r',
      seltype: 'type_t',
      selrange: 's0',
    }.merge(attrs)

    content = attrs.delete(:content)
    if content
      File.open(path, 'w') { |f| f.print(content) }
    end

    resource = Puppet::Type.type(:k5login).new(attrs)
    resource
  end

  before :each do
    FileUtils.touch(path)
  end

  context 'when the file is missing' do
    it 'initiallies be absent' do
      File.delete(path)
      expect(resource.retrieve[:ensure]).to eq(:absent)
    end

    it 'creates the file when synced' do
      expect(resource.retrieve[:ensure]).to eq(:present)
      expect(Puppet::FileSystem).to be_exist(path)
    end
  end

  context 'when the file is present' do
    context 'retrieved initial state' do
      subject(:k5login) { resource.retrieve }

      it 'retrieves its properties correctly with zero principals' do
        expect(k5login[:ensure]).to eq(:present)
        expect(k5login[:principals]).to eq([])
        # We don't really care what the mode is, just that it got it
        expect(k5login[:mode]).not_to be_nil
      end

      context 'with one principal' do
        subject(:one_principal) { resource(content: "daniel@EXAMPLE.COM\n").retrieve }

        it 'retrieves its principals correctly' do
          expect(one_principal[:principals]).to eq(['daniel@EXAMPLE.COM'])
        end
      end

      [:seluser, :selrole, :seltype, :selrange].each do |param|
        property = Puppet::Type.type(:k5login).attrclass(param)
        context param.to_s do
          let(:sel_param) { property.new resource: resource }

          context 'with selinux' do
            it 'returns correct values based on SELinux state' do
              allow(sel_param).to receive(:debug)
              expectedresult = case param
                               when :seluser then 'user_u'
                               when :selrole then 'object_r'
                               when :seltype then 'krb5_home_t'
                               when :selrange then 's0'
                               end
              expect(sel_param.default).to eq(expectedresult)
            end
          end

          context 'without selinux' do
            it 'does not try to determine the initial state' do
              allow(Puppet::Type::K5login::ProviderK5login).to receive(:selinux_support?).and_return false

              expect(k5login[:selrole]).to be_nil
            end

            it 'does nothing for safe_insync? if no SELinux support' do
              sel_param.should = 'newcontext'
              expect(sel_param).to receive(:selinux_support?).and_return false
              expect(sel_param.safe_insync?('oldcontext')).to eq(true)
            end
          end
        end
      end

      context 'with two principals' do
        subject(:two_principals) do
          content = ['daniel@EXAMPLE.COM', 'george@EXAMPLE.COM'].join("\n")
          resource(content: content).retrieve
        end

        it 'retrieves its principals correctly' do
          expect(two_principals[:principals]).to eq(['daniel@EXAMPLE.COM', 'george@EXAMPLE.COM'])
        end
      end
    end

    it 'removes the file ensure is absent' do
      resource(ensure: 'absent').property(:ensure).sync
      expect(Puppet::FileSystem).not_to be_exist(path)
    end

    it 'writes one principal to the file' do
      expect(File.read(path)).to eq('')
      resource(principals: ['daniel@EXAMPLE.COM']).property(:principals).sync
      expect(File.read(path)).to eq("daniel@EXAMPLE.COM\n")
    end

    it 'writes multiple principals to the file' do
      content = ['daniel@EXAMPLE.COM', 'george@EXAMPLE.COM']

      expect(File.read(path)).to eq('')
      resource(principals: content).property(:principals).sync
      expect(File.read(path)).to eq(content.join("\n") + "\n")
    end

    describe 'when setting the mode' do
      # The defined input type is "mode, as an octal string"
      ['400', '600', '700', '644', '664'].each do |mode|
        it "should update the mode to #{mode}" do
          resource(mode: mode).property(:mode).sync

          expect((Puppet::FileSystem.stat(path).mode & 0o7777).to_s(8)).to eq(mode)
        end
      end
    end

    context '#stat' do
      let(:file) { Puppet::Type.type(:k5login).new(path: path) }

      it 'returns nil if the file does not exist' do
        file[:path] = make_absolute('/foo/bar/baz/non-existent')

        expect(file.stat).to be_nil
      end

      it "returns nil if the file cannot be stat'ed" do
        dir = tmpfile('link_test_dir')
        child = File.join(dir, 'some_file')

        # Note: we aren't creating the file for this test. If the user is
        # running these tests as root, they will be able to access the
        # directory. In that case, this test will still succeed, not because
        # we cannot stat the file, but because the file does not exist.
        Dir.mkdir(dir)
        begin
          File.chmod(0, dir)

          file[:path] = child

          expect(file.stat).to be_nil
        ensure
          # chmod it back so we can clean it up
          File.chmod(0o777, dir)
        end
      end

      it 'returns nil if parts of path are not directories' do
        regular_file = tmpfile('ENOTDIR_test')
        FileUtils.touch(regular_file)
        impossible_child = File.join(regular_file, 'some_file')

        file[:path] = impossible_child
        expect(file.stat).to be_nil
      end

      it 'returns the stat instance' do
        expect(file.stat).to be_a(File::Stat)
      end

      it 'caches the stat instance' do
        expect(file.stat.object_id).to eql(file.stat.object_id)
      end
    end
  end
end
