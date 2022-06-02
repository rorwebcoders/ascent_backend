class CreateJobStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :job_statuses do |t|
      t.string :job_name
      t.datetime :updated_referer
      t.timestamps
    end
  end
end
