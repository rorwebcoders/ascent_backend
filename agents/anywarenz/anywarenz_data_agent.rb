# -*- encoding : utf-8 -*-
require 'logger'
require 'action_mailer'

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => "gmail.com",
  :user_name            => "",
  :password             => "",
  :authentication       => "plain",
  :enable_starttls_auto => true
}
ActionMailer::Base.view_paths= File.dirname(__FILE__)

class AnywarenzMailer < ActionMailer::Base

  def alert_data_email(q,e,n,p)
    puts "Sending Alert Email for #{p} email.."
    $logger.info "Sending Alert Email for #{p} email.."
    @q = q
    @n = n
    @p = p
    mail(
      :to      => [e],
      :from    => "",
      :subject => "Alert - #{p} has the quantity of #{q}"
    ) do |format|
      format.html
    end
  end
end

class AnywarenzDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/anywarenz_data_builder_agent.log", 'weekly')
    #~ $logger.level = Logger::DEBUG
    $logger.formatter = Logger::Formatter.new
  end

  def establish_db_connection
    # connect to the MySQL server
    get_db_connection(@options[:env])
  end

  def start_processing
    begin
      if $db_connection_established
        Dir.mkdir("#{File.dirname(__FILE__)}/anywarenz_data") unless File.directory?("#{File.dirname(__FILE__)}/anywarenz_data")
        # begin
        #   Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        #     ftp.passive = true
        #     $logger.info " Files Started Transfer from server to folder"
        #     ftp.getbinaryfile("#{$site_details["anywarenz_input_ftp_file_name"]}", "#{Rails.root}/agents/anywarenz/anywarenz_data/#{$site_details["anywarenz_input_ftp_file_name"]}",1024)
        #     $logger.info "Files ended Transfer"
        #     puts "Files ended Transfer"
        #     $logger.info "Files Deleted in server"
        #     puts "Files Deleted in server"
        #     files = ftp.list
        #     puts files
        #     ftp.close
        #   end
        # rescue
        # end

        @vendor_file="#{File.dirname(__FILE__)}/anywarenz_data/#{$site_details["anywarenz_input_ftp_file_name"]}"
        if File.exists?(@vendor_file)
          if(File.size(@vendor_file)>0)
            workbook = Roo::CSV.new(@vendor_file, csv_options: {encoding: 'iso-8859-1:utf-8'})
            workbook.default_sheet = workbook.sheets.first

            ((workbook.first_row + 1)..workbook.last_row).each do |row|
              # byebug
              product_code = workbook.row(row)[0]
              puts url = "https://www.anywarenz.co.nz/products/#{product_code}"
              doc = Nokogiri::HTML(open(url))
              puts title = doc.css("h1.product-meta__title.heading.h1").text.strip() rescue ""
              puts sku = doc.css("span.product-meta__sku-number").text.strip() rescue ""
              puts brand = doc.css("a.product-meta__vendor.link.link--accented")[0].text.strip() rescue ""
                description = doc.css("div.rte.text--pull")[0].text.strip() rescue ""
                description_html = doc.css("div.rte.text--pull").to_s.strip() rescue ""
                temp_image = []

               temp_1 = doc.css("div.product-gallery__thumbnail-list a")

              temp_1.each do |t_1|
                 temp_image << t_1["href"].gsub("_1024x","_500x").gsub("//cdn","http://cdn") rescue ""
              end

              puts temp_image = temp_image.join(", ")
              if(sku !=  "" && product_code.to_s == sku.to_s)
                exist_data = AnywarenzDetail.where(:url => url)
                if exist_data.count == 0
                  AnywarenzDetail.create(:product_code => product_code, :url => url, :sku => sku, :brand => brand, :title => title, :description_html => description_html, :description => description, :temp_image => temp_image)
                end
              end
            end
            write_data_to_file()
          end
        end
      end
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/anywarenz_data") unless File.directory?("#{File.dirname(__FILE__)}/anywarenz_data")
    # time = DateTime.now.getutc.strftime("%d_%m_%Y_%H_%M_%S") rescue ""
    file_name = "#{$site_details["anywarenz_output_file_name"]}"
    csv = CSV.open(Rails.root.join("#{File.dirname(__FILE__)}", 'anywarenz_data/',file_name), "wb")
    csv << ["ref","Detail URL","Sku","brand","title","description_html","description","image"]
    $logger.info "-added headers--"
    allprods = AnywarenzDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          product_code = p_id['product_code']
          url = p_id['url']
          sku = p_id['sku']
          brand = p_id['brand']
          title = p_id['title']
          description_html = p_id['description_html']
          description = p_id['description']
          temp_image = p_id['temp_image']
          csv <<  [product_code ,url ,sku ,brand ,title ,description_html ,description ,temp_image]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      # upload_file_to_ftp(file_name)
    else
      puts "Data is not captured"
      csv.close
    end
  end
  def upload_file_to_ftp(file_name)
    #upload file to ftp
    begin
      Net::FTP.open($site_details['ftp_details']['ftp_domain'], $site_details['ftp_details']['ftp_username'], $site_details['ftp_details']['ftp_password']) do |ftp|
        ftp.passive = true
        localfile = "#{File.dirname(__FILE__)}/anywarenz_data/#{file_name}"
        remotefile = "#{$site_details['ftp_details']['ftp_folder_path']}/#{file_name}"
        ftp.putbinaryfile(localfile, remotefile, 1024)
        $logger.info "Local Files Transfer"
        puts files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        ftp.close
        #once we uploaded file, we need to delete them
        File.delete("#{File.dirname(__FILE__)}/anywarenz_data/#{file_name}")
        begin
          koalo_job = JobStatus.find_or_initialize_by(job_name: $site_details['anywarenz_details']['company_name'])
          koalo_job.updated_referer = DateTime.now
          koalo_job.save
        rescue Exception => e
          $logger.error "Error Occured in job status #{e.message}"
          $logger.error e.backtrace
        end
        AnywarenzProductDetail.destroy_all rescue ""
      end
    rescue
    end
  end
end #class

require 'rubygems'
require 'optparse'
options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: ruby anywarenz_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new anywarenz agent for building the projects' ) do |env|
    options[:env] = env
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'To get the list of available options' ) do
    puts opts
    exit
  end
end
optparse.parse!
puts @options = options
require File.expand_path('../load_configurations', __FILE__)
newprojects_agent = AnywarenzDataBuilderAgent.new(options)
newprojects_agent.start_processing
