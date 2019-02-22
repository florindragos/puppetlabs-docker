require 'spec_helper_acceptance'

broken = false

if os[:family] == 'windows'
  puts "Not implemented on Windows"
  broken = true
elsif os[:family] == 'RedHat'
  docker_args = "repo_opt => '--enablerepo=localmirror-extras'" 
end

describe 'docker network', :win_broken => broken do
  command = 'docker'

  before(:all) do
    install_code = "class { 'docker': #{docker_args}}"
    apply_manifest(install_code, :catch_failures=>true)
  end

  # describe command("#{command} network --help") do
  #   its(:exit_status) { should eq 0 }
  # end

  it 'Checking exit code and stdout' do
    results = run_shell("#{command} network --help")
    expect(results.first['result']['exit_code']).to eq 0
  end

  context 'with a local bridge network described in Puppet' do
    before(:all) do
      @name = 'test-network'
      @pp = <<-code
        docker_network { '#{@name}':
          ensure => present,
        }
      code
      apply_manifest(@pp, :catch_failures=>true)
    end

    it 'should be idempotent' do
      apply_manifest(@pp, :catch_changes=>true)
    end

    it 'should have created a network' do
      run_shell("#{command} network inspect #{@name}", :expect_failures => false)
    end

    after(:all) do
      command("#{command} network rm #{@name}")
    end
  end
end
