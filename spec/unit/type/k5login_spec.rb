require 'spec_helper'
require 'fileutils'
require 'puppet/type'

describe Puppet::Type.type(:k5login), unless: Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let(:path) { tmpfile('k5login') }

  context 'the type class' do
    subject(:k5login_type) { described_class }

    it { is_expected.to be_validattr :ensure }
    it { is_expected.to be_validattr :path }
    it { is_expected.to be_validattr :principals }
    it { is_expected.to be_validattr :mode }
    it { is_expected.to be_validattr :selrange }
    it { is_expected.to be_validattr :selrole }
    it { is_expected.to be_validattr :seltype }
    it { is_expected.to be_validattr :seluser }
  end
end
