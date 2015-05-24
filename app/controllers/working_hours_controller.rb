class WorkingHoursController < ApplicationController
  unloadable

  before_filter :require_login
  accept_api_auth :index

  def index
    # filter
    filter_params = params[:filter] || {}

    start_date = Date.new(Time.now.year, 1, 1)
    end_date = Date.today

    @user = User.current

    snapshot = WorkingHoursSnapshot.find_current(@user, start_date, end_date)
    # set default date filter to params or last snapshot or begin of year
    @begindate_filter = filter_params[:begindate] || (snapshot.date unless snapshot.blank?) || start_date
    @enddate_filter = filter_params[:enddate] || end_date

    # apply filter
    @working_hours = TimeEntry
    unless params[:users] == 'all' && @user.admin?
      @working_hours = @working_hours.where(:user_id => @user.id)
    end
    @working_hours = @working_hours.where(:spent_on => @begindate_filter..@enddate_filter)
    @working_hours = @working_hours.where(:project_id => filter_params[:project_id]) unless filter_params[:project_id].blank?
    @working_hours = @working_hours.where(:issue_id => filter_params[:issue_id]) unless filter_params[:issue_id].blank?

    # statistics
    begindate = @begindate_filter.to_date
    enddate = @enddate_filter.to_date
    @actual_hours = WorkingHours.total_hours(begindate, enddate, @user)
    @target_hours = WorkingHours.target_hours(begindate, enddate, @user)
    @diff_hours = WorkingHours.diff_hours(begindate, enddate, @user)
    @vacation_days_used = WorkingHours.vacation_days_used(begindate, enddate, @user)

    respond_to do |format|
      format.html {
        # filter form
        @project_filter_collection = @user.projects.order(:name)
        @project_filter = filter_params[:project_id].to_s.to_i

        @issue_filter_collection = []
        unless filter_params[:project_id].blank?
          project = @user.projects.find(filter_params[:project_id])
          @issue_filter_collection = WorkingHours.task_issues(project)
          @issue_filter = filter_params[:issue_id].to_s.to_i
        end

        #@minutes_total = @working_hours.inject(0) { |sum, w| sum + w.minutes }

        # pagination
        @working_hour_count = @working_hours.count
        @working_hour_pages = Paginator.new(@working_hour_count, per_page_option, params['page'])
        @working_hours = @working_hours.order("#{TimeEntry.table_name}.spent_on DESC").limit(@working_hour_pages.per_page).offset(@working_hour_pages.offset)
      }
    end
  end

  private

  MINGAP = 60

  # def working_hours_calculations
  #   case params['subform']
  #     when 'Timestamps'
  #       if params['running'] && params[:working_hours][:ending].empty?
  #         @working_hours.ending = nil
  #       end
  #       unless @working_hours.starting.blank?
  #         if @working_hours.starting.hour < WorkingHours::WORKDAY_CHANGE_HOUR
  #           @working_hours.workday = @working_hours.starting.to_date - 1
  #         else
  #           @working_hours.workday = @working_hours.starting.to_date
  #         end
  #       end
  #     when 'Duration'
  #       unless @working_hours.workday.blank?
  #         @working_hours.starting = Time.local(@working_hours.workday.year, @working_hours.workday.month, @working_hours.workday.day)
  #         @working_hours.ending = @working_hours.starting + params['duration'].to_f.hours
  #       end
  #   end
  # end

end
