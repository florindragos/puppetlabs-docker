bundle exec rake 'waffle:provision[vmpooler, ubuntu-1604-x86_64]'
bundle exec rake waffle:install_agent
bundle exec rake waffle:install_module
bundle exec rake waffle:acceptance:parallel
bundle exec rake waffle:tear_down