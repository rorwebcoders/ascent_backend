# -*- encoding : utf-8 -*-
require 'logger'
require 'action_mailer'

ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address              => "smtp.gmail.com",
  :port                 => 587,
  :domain               => "gmail.com",
  :user_name            => "ascentnoreplymailer@gmail.com",
  :password             => "ddzpftmwzygawrxj",
  :authentication       => "plain",
  :enable_starttls_auto => true
}
ActionMailer::Base.view_paths= File.dirname(__FILE__)

class IngramMicroMailer < ActionMailer::Base

  def alert_data_email
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error in Ingram - Ascent file."
    ) do |format|
      format.html
    end
  end

  def no_data_alert_mail
    puts "Sending Alert Email.."
    $logger.info "Sending Alert Email.."
    # @q = q
    # @n = n
    # @p = p
    mail(
      :to      => $site_details['email_to'],
      :from    => $site_details['email_from'],
      :subject => "Alert - Error Occured in Ingram - Ascent script."
    ) do |format|
      format.html
    end
  end
end

class IngramMicroDataBuilderAgent
  attr_accessor :options, :errors

  def initialize(options)
    @options = options
    @options
    create_log_file
    establish_db_connection
  end

  def create_log_file
    Dir.mkdir("#{File.dirname(__FILE__)}/logs") unless File.directory?("#{File.dirname(__FILE__)}/logs")
    $logger = Logger.new("#{File.dirname(__FILE__)}/logs/ingram_micro_data_builder_agent.log", 'weekly')
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
        Dir.mkdir("#{File.dirname(__FILE__)}/ingram_micro_data") unless File.directory?("#{File.dirname(__FILE__)}/ingram_micro_data")
        if @options[:env] != "development"
          begin
            Dir.foreach("#{File.dirname(__FILE__)}/ingram_micro_data") do |f|
              fn = File.join("#{File.dirname(__FILE__)}/ingram_micro_data", f)
              File.delete(fn) if f != '.' && f != '..'
            end
          rescue
          end
          begin
            Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
              ftp.passive = true
              $logger.info " Files Started Transfer from server to folder"
              ftp.chdir("#{$site_details['server_input_path']}")
              files = ftp.nlst('*.csv')
              files.each do |file|
                puts file
                if file.to_s.starts_with?($site_details['ingram_micro_input_file_name'])
                  ftp.getbinaryfile(file, "#{Rails.root}/agents/ingram_micro/ingram_micro_data/"+file,1024)
                end
              end
              sleep 5
              $logger.info "Files ended Transfer"
              puts "Files ended Transfer"
              ftp.close
            end
          rescue Exception => e
            $logger.error "Error Occured in FTP connection- #{e.message}"
            $logger.error e.backtrace
          end
        end

        Headless.ly do
        all_files =  Dir["#{File.dirname(__FILE__)}/ingram_micro_data/**/*.csv"]
        all_files.each do |input_file_path_and_name|
          begin
            if input_file_path_and_name.to_s.split("/").last.starts_with?($site_details['ingram_micro_input_file_name'])
              if File.exists?(input_file_path_and_name)
                if(File.size(input_file_path_and_name)>0)
                  IngramMicroDetail.destroy_all rescue ""
                  # Selenium::WebDriver::Firefox::Service.driver_path = "/usr/local/bin/geckodriver"
                  browser = Watir::Browser.new :firefox
                  browser.window.maximize
                  browser.goto "https://nz.ingrammicro.com/Site/Login"
                  browser.text_field(:id=>"okta-signin-username").set($site_details["ingram_micro_username"])
                  browser.text_field(:id=>"okta-signin-password").set($site_details["ingram_micro_password"])
                  browser.button(:id=>"okta-signin-submit").fire_event :click
                  sleep 5
                  handler  = File.open(input_file_path_and_name)
                  csv_string = handler.read.encode!("UTF-8", invalid: :replace).gsub("\r","")
                  CSV.parse(csv_string, :headers => :first_row, liberal_parsing: true, col_sep: ",").each_with_index do |line,index|
                    puts product_code = line[0]
                    $logger.info "Processing #{product_code}"
                    url = "https://nz.ingrammicro.com/site/productdetail?id=#{product_code}"
                    exist_data = IngramMicroDetail.where(:url => url)
                    if exist_data.count == 0
                      begin
                        browser.goto "#{url}"
                        sleep 2
                        doc = Nokogiri::HTML.parse(browser.html)
                        title = doc.css("div.clsProductFullDesc").text.gsub("Less","").strip() rescue ""
                        if title.to_s != ''
                          vendor_code = doc.css("div.Top-Sku-VPN-UPC").text.split("VPN:").last.strip().split("SKU:").first.strip() rescue ""
                          description = doc.css("div#collapseZero").text.strip rescue ""
                          description_html = doc.css("div#collapseZero").to_s rescue ""
                          specs = doc.css("div#collapseOne").text rescue ""
                          specs_html = doc.css("div#collapseOne").to_s rescue ""
                          temp_1 = doc.css("div#slide0 img")
                          temp_image = []
                          temp_1.each do |t_1|
                            temp_image << t_1.attr("src").gsub("/300/","/500/") rescue ""
                          end
                          temp_image = temp_image.uniq.join(", ")
                          IngramMicroDetail.create(:url => url, :ref_id => product_code,:vendor_code => vendor_code, :title => title, :specs_html => specs_html, :specs => specs, :description_html => description_html, :description => description, :image => temp_image)
                          $logger.info "Inserted #{product_code}"
                        end
                      rescue
                        begin
                          IngramMicroDetail.create(:url => url, :ref_id => product_code)
                          $logger.info "Inserted #{product_code}"
                        rescue
                        end
                      end
                    end
                  end
                  write_data_to_file(input_file_path_and_name)
                end
              end
            end
          rescue
            puts  "Some problem in #{input_file_path_and_name} process Please Check"
            $logger.info  "Some problem in #{input_file_path_and_name} process Please Check"
          end
        end
        end #headless end
      end
    rescue Exception => e
      $logger.error "Error Occured - #{e.message}"
      $logger.error e.backtrace
      sleep 10
      send_email= IngramMicroMailer.no_data_alert_mail()
      send_email.deliver
    ensure
      $logger.close
      #~ #Our program will automatically will close the DB connection. But even making sure for the safety purpose.
      ActiveRecord::Base.clear_active_connections!
    end
  end

  def write_data_to_file(input_file_path_and_name)
    #create excel version of product details
    Dir.mkdir("#{File.dirname(__FILE__)}/ingram_micro_data") unless File.directory?("#{File.dirname(__FILE__)}/ingram_micro_data")
    puts output_file_path_and_name = input_file_path_and_name.to_s.gsub("_input_","_output_")
    csv = CSV.open(output_file_path_and_name, "wb")
    csv << ["ref","Detail URL","vendor_code","title","description_html","description","specs_html","specs","image"]
    $logger.info "-added headers--"
    allprods = IngramMicroDetail.all
    if allprods.length > 0
      allprods.each_with_index do |p_id,counter_row|
        begin
          product_code = p_id['ref_id'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          url = p_id['url'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          vendor_code = p_id['vendor_code'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          brand = p_id['brand'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          title = p_id['title'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description_html = p_id['description_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          description = p_id['description'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs_html = p_id['specs_html'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          specs = p_id['specs'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          temp_image = p_id['image'].to_s.gsub("\r"," ").gsub("\n"," ").gsub("  "," ").strip() rescue ""
          csv <<  [product_code ,url ,vendor_code ,title ,description_html ,description,specs_html,specs,temp_image]
        rescue
        end
      end
      csv.close
      $logger.info "-xlsx--created locally--"
      upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    else
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        input_file_name = input_file_path_and_name.to_s.split("/").last
        ftp.rename($site_details['server_input_path']+input_file_name, $site_details['server_archive_path']+"#{input_file_name.gsub('.csv', '_review.csv')}")
      end
      puts "Data is not captured"
      csv.close
      # Write a code to send alert email to me and you
      send_email= IngramMicroMailer.alert_data_email()
      send_email.deliver
    end
  end
  
  def upload_file_to_ftp(input_file_path_and_name,output_file_path_and_name)
    begin
      Net::FTP.open($site_details["server_domain_name"], $site_details["server_username"], $site_details["server_password"]) do |ftp|
        ftp.passive = true
        input_file_name = input_file_path_and_name.to_s.split("/").last
        output_filename = output_file_path_and_name.to_s.split("/").last
        remotefile_output_path = $site_details['server_output_path']+output_filename
        ftp.putbinaryfile(output_file_path_and_name, remotefile_output_path, 1024)
        $logger.info "Local Files Transfer"
        files = ftp.list
        $logger.info "Local Files Transferred to FTP - #{files}"
        #Moved input and output ftp files to archive  path
        ftp.rename($site_details['server_input_path']+input_file_name, $site_details['server_archive_path']+input_file_name)
        #Moved input and output ftp files to archive  path
        ftp.close
        # Delete the INPUT file form, Local ingram_micro_data
        File.delete(input_file_path_and_name) rescue ""  #deleting  input file from local after sending to FTP
        File.delete(output_file_path_and_name) rescue "" #deleting  output file from local after sending to FTP
        begin
          job_status = JobStatus.find_or_initialize_by(job_name: $site_details['ingram_micro_details']['company_name'])
          job_status.updated_referer = DateTime.now
          job_status.save
        rescue Exception => e
          $logger.error "Error Occured in job status #{e.message}"
          $logger.error e.backtrace
        end
      end
    rescue Exception => e
      $logger.error "Error Occured in uploading file #{e.message}"
      $logger.error e.backtrace
    end
  end
end #class

require 'rubygems'
require 'optparse'
options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: ruby ingram_micro_data_agent.rb [options]"

  # Define the options, and what they do
  options[:action] = 'start'
  opts.on( '-a', '--action ACTION', 'It can be start, stop, restart' ) do |action|
    options[:action] = action
  end

  options[:env] = 'development'
  opts.on( '-e', '--env ENVIRONMENT', 'Run the new ingram_micro agent for building the projects' ) do |env|
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
newprojects_agent = IngramMicroDataBuilderAgent.new(options)
newprojects_agent.start_processing
