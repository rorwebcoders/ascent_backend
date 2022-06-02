module StatusHelper
	def getTimeDifferenceColor(job)
		begin
		t = TimeDifference.between(Time.parse(job.updated_referer.to_s),Time.parse(DateTime.now.to_s))
		if t.in_hours > 24.00
			"#F5B7B1" #red
		else
			"#ABEBC6"
		end
		rescue
		    "white"
		end
	end
end
