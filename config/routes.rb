Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get 'status/job_process_daily_status' => 'status#job_process_daily_status'
end
