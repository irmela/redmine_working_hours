Redmine::Plugin.register :redmine_working_hours do
  name 'Redmine Working Hours plugin'
  author 'Pirmin Kalberer, Mathias Walker, Irmela Göhl'
  description 'A plugin for integration of working time in Redmine'
  version '1.0'
  url 'https://github.com/irmela/redmine_working_hours'

  menu :account_menu, :working_hours,
    {:controller => 'working_hours', :action => 'index'},
    :caption => :working_hours,
    :before => :logout,
    :if => Proc.new { User.current.logged? }

  settings :default => {:workday_hours => 8.0, :vacation_issue_id => nil}, :partial => 'settings/working_hours_settings'
end
