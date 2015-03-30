class WorkingHours
  unloadable

  COMMON_TASKS_USER = 'admin'
  WORKDAY_CHANGE_HOUR = 5

  def self.workday_hours
    Setting.plugin_redmine_working_hours[:workday_hours].to_f
  end

  # total time

  def self.total_hours(start_date, end_date, user)
    hours = 1

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      hours = snapshot.total
    end

    entries = TimeEntry.where(:user_id => user.id, :spent_on => start_date..end_date)
    working_hours = entries.sum(&:hours)
  end

  def self.total_hours_month(month, year=Time.now.year, user=User.current)
    start_date = Date.new(year, month, 1)
    end_date = last_day_of_month(month, year)
    total_hours(start_date, end_date, user)
  end

  # target time

  def self.target_hours(start_date, end_date, user)
    hours = 0

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      hours = snapshot.target
    end

    t = start_date
    num_days = (end_date - start_date + 1).to_int
    num_days.times do
      if t.wday != 0 and t.wday != 6
        # not a weekend
        unless t.holiday?(:de)
          # not a holiday
          hours += workday_hours
        end
      end
      t += 1
    end

    hours *= user_pensum(user)
    hours
  end

  def self.target_hours_month(month, year=Time.now.year, user=User.current)
    start_date = Date.new(year, month, 1)
    end_date = last_day_of_month(month, year)
    target_hours(start_date, end_date, user)
  end

  # difference to target time

  def self.diff_hours(start_date, end_date, user=User.current)
    total_hours(start_date, end_date, user) - target_hours(start_date, end_date, user)
  end

  # difference to target time since beginning of year
  def self.diff_hours_until_day(end_date, user=User.current)
    start_date = Date.new(end_date.year, 1, 1)
    diff_hours(start_date, end_date, user)
  end

  # vacation days

  def self.vacation_issue
    Issue.find_by_id(Setting.plugin_redmine_working_hours[:vacation_issue_id])
  end

  def self.vacation_days_available(user=User.current)
    user_vacation_days = 0
    custom_field = CustomField.find_by_name('working_hours_vacation_days')
    if custom_field.nil?
      cv = CustomValue.where(:custom_field_id => custom_field.id).where(:customized_id => user.id).first
      unless cv.nil?
        user_vacation_days = cv.value.to_i
      end
    else
      user_vacation_days = Setting.plugin_redmine_working_hours[:default_vacation_days].to_i
    end

    start_date = Date.new(Time.now.year, 1, 1)
    end_date = Date.today
    days_used = 0.0

    snapshot = WorkingHoursSnapshot.find_current(user, start_date, end_date)
    unless snapshot.nil?
      start_date = snapshot.date
      days_used = snapshot.vacation_days
    end

    unless vacation_issue.nil?
      working_hours = TimeEntry.where(:user_id => user.id, :issue_id => vacation_issue.id, :spent_on => start_date..end_date)
      working_hours.each do |wh|
        if wh.spent_on.wday != 0 and wh.spent_on.wday != 6
          unless wh.spent_on.holiday?(:de)
            #not a weekend and not a holiday
            if wh.hours > workday_hours/2.0
              days_used += 1.0
            else
              days_used += 0.5
            end
          end
        end
      end
    end

    user_vacation_days - days_used
  end

  # helpers

  def self.last_day_of_month(month, year=Time.now.year)
    if month == 12
      Date.new(year, 12, 31)
    else
      Date.new(year, (month + 1), 1) - 1.day
    end
  end

  def self.user_pensum(user)
    pensum = 1.0
    custom_field = CustomField.find_by_name('working_hours_pensum')
    unless custom_field.nil?
      cv = CustomValue.where(:custom_field_id => custom_field.id).where(:customized_id => user.id).first
      unless cv.nil? || cv.value.to_f <= 0
        pensum = cv.value.to_f
      end
    end
    pensum
  end

end
