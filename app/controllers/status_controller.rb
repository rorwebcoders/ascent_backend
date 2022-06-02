class StatusController < ApplicationController
	def job_process_daily_status
	    @jobs = JobStatus.all
	end
end
