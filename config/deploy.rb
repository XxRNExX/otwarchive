# takes care of the bundle install tasks
require 'bundler/capistrano'

# deploy to different environments with tags
set :default_stage, "staging"
require 'capistrano/gitflow_version'

# user settings
set :user, "www-data"
set :auth_methods, "publickey"
#ssh_options[:verbose] = :debug
ssh_options[:auth_methods] = %w(publickey)
set :use_sudo, false

# basic settings
set :application, "otwarchive"
set :deploy_to, "/var/www/otwarchive"
set :keep_releases, 4

set :mail_to, "otw-coders@transformativeworks.org otw-testers@transformativeworks.org"

# git settings
set :scm, :git
set :repository,  "git://github.com/otwcode/otwarchive.git"
set :deploy_via, :remote_cache

# overwrite default capistrano deploy tasks
namespace :deploy do
  task :start, :roles => :app do
    run "/static/bin/unicorns_start.sh"
  end
  task :stop, :roles => :app do
    run "/static/bin/unicorns_stop.sh"
  end
  task :restart, :roles => :app do
    run "/static/bin/unicorns_reload.sh"
  end
  namespace :web do
    desc "Present a maintenance page to visitors."
    task :disable, :roles => :web do
      run "mv #{deploy_to}/current/public/nomaintenance.html #{deploy_to}/current/public/maintenance.html 2>/dev/null || true"
    end
    desc "Makes the current release web-accessible."
    task :enable, :roles => :web do
      run "mv #{deploy_to}/current/public/maintenance.html #{deploy_to}/current/public/nomaintenance.html 2>/dev/null"
    end
    desc "Makes the new release web-accessible."
    task :enable_new, :roles => :web do
      run "mv #{release_path}/public/maintenance.html #{release_path}/public/nomaintenance.html 2>/dev/null"
    end
  end
end

# our tasks which are not environment specific
namespace :extras do
  task :update_revision do
    run "/static/bin/fix_revision.sh"
  end
  task :cache_stylesheet, {:roles => :web} do
    run "cd #{release_path}/public/stylesheets/; cat system-messages.css site-chrome.css forms.css live_validation.css auto_complete.css > cached_for_screen.css"
  end
  task :run_after_tasks, {:roles => :backend} do
    run "cd #{release_path}; rake After RAILS_ENV=production"
  end
  task :restart_delayed_jobs, {:roles => :backend} do
    run "/static/bin/dj_restart.sh"
  end
  task :restart_sphinx, {:roles => :search} do
    run "/static/bin/ts_restart.sh"
  end
  task :reindex_sphinx, {:roles => :search} do
    run "/static/bin/ts_reindex.sh"
  end
  desc "rebuild sphinx"
  task :rebuild_sphinx, {:roles => :search} do
    run "/static/bin/ts_rebuild.sh"
  end
  task :update_cron, {:roles => :backend} do
    run "whenever --update-crontab #{application}"
  end
end

after "deploy:update", "extras:cache_stylesheet"

before "deploy:migrate", "deploy:web:disable"
after "deploy:migrate", "extras:run_after_tasks"

before "deploy:symlink", "deploy:web:enable_new"
after "deploy:symlink", "extras:update_revision"

after "deploy:restart", "extras:update_cron"
after "deploy:restart", "extras:restart_delayed_jobs"
after "deploy:restart", "deploy:cleanup"
